import SwiftUI

struct WatchView: View {
    @Bindable var app: AppModel
    let channel: WatchedChannel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("watchMode") private var mode: WatchMode = .balanced
    @AppStorage("chatLeading") private var chatLeading = false
    @State private var fold = FoldState()
    @State private var appearance = UUID()
    @State private var previousMode: WatchMode = .balanced

    var body: some View {
        let layoutCompact = sizeClass != .regular
        let layoutMode = mode
        let layoutDivision = fold.division
        ArrangementView {
            WatchVideoPanel(session: app.player, channel: channel, fullVideo: mode == .video) {
                if mode == .video { mode = previousMode }
                else { previousMode = mode; mode = .video }
            }
        } secondary: {
            NativeChatView(session: app.chat, signedIn: app.auth.account != nil, composerVisible: mode != .video) { app.accountPresented = true }
                .accessibilityHidden(mode == .video)
                .opacity(mode == .video ? 0 : 1)
                .allowsHitTesting(mode != .video)
        }
        .arrangementViewStyle(WatchArrangementStyle(compact: sizeClass != .regular,
            division: fold.division, mode: mode, chatLeading: chatLeading))
        .onGeometryChange(for: WatchLayoutSnapshot.self) { geometry in
            WatchLayoutSnapshot(size: geometry.size, compact: layoutCompact,
                                mode: layoutMode, division: layoutDivision)
        } action: { layout in
            app.player.recordDiagnostic("watch.layout", values: layout.diagnosticValues)
        }
        .background(FoldReader(state: fold))
        .background(AppTheme.background)
        .clipped()
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Viewing mode", selection: $mode) {
                        ForEach(WatchMode.allCases) { item in Label(item.rawValue, systemImage: item.symbol).tag(item) }
                    }
                    if sizeClass == .regular { Toggle("Chat on the left", isOn: $chatLeading) }
                    Divider()
                    Link("Open in Twitch", destination: URL(string: "https://www.twitch.tv/\(channel.login)")!)
                } label: { Label("Viewing options", systemImage: "rectangle.split.2x1") }
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            }
        }
        .onAppear { app.watch(channel, appearance: appearance) }
        .onChange(of: channel.id) { _, _ in app.watch(channel, appearance: appearance) }
        .onDisappear { app.leaveWatch(channel, appearance: appearance) }
    }
}

private struct WatchLayoutSnapshot: Equatable {
    let size: CGSize
    let compact: Bool
    let mode: WatchMode
    let division: CGRect?

    var diagnosticValues: [String: PlaybackDiagnosticValue] {
        let name: String
        switch mode { case .balanced: name = "balanced"; case .slim: name = "slim"; case .video: name = "video" }
        var values: [String: PlaybackDiagnosticValue] = [
            "viewingMode": .text(name), "compact": .flag(compact),
            "width": .number(Double(size.width)), "height": .number(Double(size.height)),
            "hasDivision": .flag(division != nil)
        ]
        if let division {
            values["divisionX"] = .number(Double(division.minX))
            values["divisionY"] = .number(Double(division.minY))
            values["divisionWidth"] = .number(Double(division.width))
            values["divisionHeight"] = .number(Double(division.height))
        }
        return values
    }
}

struct WatchVideoPanel: View {
    let session: PlaybackSession
    let channel: WatchedChannel
    var fullVideo = false
    var toggleFullVideo: (() -> Void)?
    @State private var playerFits = false
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let fits = geometry.size.width >= 400 && geometry.size.height >= 300
                Group {
                    if session.isConfigured && fits && session.hasCurrentPage && session.channel == channel.login {
                        PlayerHost(session: session)
                    } else {
                        placeholder(fits: fits, width: geometry.size.width)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { session.recordVideoGeometry($0) }
                .task(id: "\(fits)|\(channel.login)") {
                    playerFits = fits
                    await session.videoAreaChanged(fits: fits, channel: channel.login)
                }
            }
            // An unconstrained layout measurement reserves the supported video
            // height plus the transport's actual Dynamic Type height. A real
            // constrained allocation can still shrink and expose the fit gate.
            .frame(idealHeight: 300)
            // Primary controls stay mounted and never vanish under focus or a tap.
            transport
        }
        .background(.black)
        .sheet(isPresented: $showDetails) { details }
    }

    private var playbackHeadline: String {
        if !playerFits { return "More room needed" }
        if session.failure != nil { return "Player needs attention" }
        if session.isRequestingPlay { return "Starting video…" }
        if session.isPlaying { return "Playback active" }
        switch session.hostEvent {
        case "PAUSE": return "Paused"
        case "OFFLINE": return "Channel offline"
        case "ENDED": return "Broadcast ended"
        case "PLAYBACK_BLOCKED": return "Play in the Twitch player"
        default: return session.canPlay ? "Ready to watch" : "Opening channel…"
        }
    }

    private var transport: some View {
        HStack(spacing: 12) {
            if session.channel == channel.login {
                Button(session.isPlaying ? "Pause video" : "Play video", systemImage: session.isPlaying ? "pause.fill" : "play.fill") {
                    Task {
                        if session.isPlaying { await session.pause() }
                        else { await session.play() }
                    }
                }
                .labelStyle(.iconOnly).font(.title3)
                .frame(width: 48, height: 48)
                .background(AppTheme.accent.opacity(0.16), in: .circle)
                .disabled(!session.isPlaying && (!session.canPlay || !playerFits))
                VStack(alignment: .leading, spacing: 2) {
                    Text(playbackHeadline)
                        .font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(!playerFits ? "Focus on video for more space." : session.status).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).accessibilityIdentifier("playbackStatus")
                }.frame(maxWidth: .infinity, alignment: .leading)
                if session.failure != nil && playerFits {
                    Button("Retry player", systemImage: "arrow.clockwise") { session.open(channel: channel.login, forceReload: true) }
                        .labelStyle(.iconOnly).frame(width: 44, height: 48)
                }
            } else {
                Image(systemName: playerFits ? "play.rectangle" : "rectangle.expand.vertical")
                    .frame(width: 48, height: 48)
                Text(playerFits ? "Opening channel…" : "More room needed").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("About \(channel.name)", systemImage: "info.circle") { showDetails = true }
                .labelStyle(.iconOnly).frame(width: 44, height: 48)
            if let toggleFullVideo {
                Button(fullVideo ? "Show video and chat" : "Focus on video", systemImage: fullVideo ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right", action: toggleFullVideo)
                    .labelStyle(.iconOnly).frame(width: 44, height: 48)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(minHeight: 64)
        .background(AppTheme.surface)
    }

    private func placeholder(fits: Bool, width: CGFloat) -> some View {
        ContentUnavailableView {
            Label(session.isConfigured ? (fits ? "Opening Twitch" : "Video needs more room") : "Video unavailable", systemImage: "play.rectangle")
        } description: {
            Text(session.isConfigured ? (width < 400 ? "Rotate your phone to give video more room. You can also watch this channel in Twitch." : (fits && session.channel == channel.login ? session.status : "Switch to full video for more space, or watch this channel in Twitch.")) : "The video service is not configured in this build.")
        } actions: {
            if width >= 400, !fits, !fullVideo, let toggleFullVideo {
                Button("Focus on video", action: toggleFullVideo).buttonStyle(.borderedProminent)
            }
            Link("Watch in Twitch", destination: URL(string: "https://www.twitch.tv/\(channel.login)")!)
                .buttonStyle(.bordered)
        }
    }

    private var details: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(channel.name).font(.title.bold())
                    NavigationLink {
                        PlaybackDiagnosticsView(diagnostics: session.diagnostics)
                    } label: {
                        Label("Playback diagnostics", systemImage: "waveform.path.ecg")
                    }.frame(minHeight: 44)
                    Label(session.status, systemImage: "play.rectangle")
                        .foregroundStyle(.secondary)
                    if !channel.title.isEmpty { Text(channel.title).font(.title3) }
                    if !channel.category.isEmpty { Label(channel.category, systemImage: "square.grid.2x2").foregroundStyle(.secondary) }
                    if let viewers = channel.viewers { Label("\(viewers.formatted()) watching", systemImage: "person.2") }
                    Link("Open channel in Twitch", destination: URL(string: "https://www.twitch.tv/\(channel.login)")!)
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    Text("The Twitch video player may ask you to sign in separately for restricted or subscriber-only streams.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }.background(AppTheme.background)
                .navigationTitle("Channel").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showDetails = false } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}
