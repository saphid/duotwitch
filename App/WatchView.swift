import SwiftUI

struct WatchView: View {
    @Bindable var app: AppModel
    let channel: WatchedChannel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("watchMode") private var mode: WatchMode = .balanced
    @AppStorage("chatLeading") private var chatLeading = false
    @AppStorage("watchChatPlacement") private var chatPlacement: WatchChatPlacement = .automatic
    @AppStorage("watchChatWidth") private var chatWidth = 240.0
    @AppStorage("watchChatHeight") private var chatHeight = 240.0
    @AppStorage("watchSlimChatWidth") private var slimChatWidth = 160.0
    @AppStorage("watchSlimChatHeight") private var slimChatHeight = 160.0
    @State private var chatSize = CGSize.zero
    @State private var watchSize = CGSize.zero
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
            WatchPaneBounds {
                NativeChatView(session: app.chat, signedIn: app.auth.account != nil, composerVisible: mode != .video) { app.accountPresented = true }
            }
                .onGeometryChange(for: CGSize.self) { $0.size } action: { chatSize = $0 }
                .accessibilityHidden(mode == .video)
                .opacity(mode == .video ? 0 : 1)
                .allowsHitTesting(mode != .video)
        }
        .arrangementViewStyle(WatchArrangementStyle(compact: sizeClass != .regular,
            division: fold.division, mode: mode, chatLeading: chatLeading,
            placement: chatPlacement, chatWidth: mode == .slim ? slimChatWidth : chatWidth,
            chatHeight: mode == .slim ? slimChatHeight : chatHeight, resize: resizeChat,
            chatSizeDescription: "\(Int(chatSize.width < watchSize.width - 1 ? chatSize.width : chatSize.height)) points"))
        .onGeometryChange(for: WatchLayoutSnapshot.self) { geometry in
            WatchLayoutSnapshot(size: geometry.size, compact: layoutCompact,
                                mode: layoutMode, division: layoutDivision)
        } action: { layout in
            watchSize = layout.size
            app.player.recordDiagnostic("watch.layout", values: layout.diagnosticValues)
        }
        .coordinateSpace(name: "watchPanes")
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
                    Picker("Chat position", selection: $chatPlacement) {
                        ForEach(WatchChatPlacement.allCases) { item in Text(item.rawValue).tag(item) }
                    }
                    Button(app.player.isPlaying ? "Pause video" : "Play video", systemImage: app.player.isPlaying ? "pause.fill" : "play.fill") {
                        Task {
                            if app.player.isPlaying { await app.player.pause() }
                            else { await app.player.play() }
                        }
                    }.disabled(!app.player.isPlaying && !app.player.canPlay)
                    Toggle("Chat on the left", isOn: $chatLeading)
                    ControlGroup("Chat size") {
                        Button("Smaller chat", systemImage: "minus") { resizeChat(chatSize.width < watchSize.width - 1, -32) }
                        Button("Larger chat", systemImage: "plus") { resizeChat(chatSize.width < watchSize.width - 1, 32) }
                    }.disabled(mode == .video || fold.division != nil)
                    Button("Reset split", systemImage: "arrow.counterclockwise") {
                        if mode == .slim { slimChatWidth = 160; slimChatHeight = 160 }
                        else { chatWidth = 240; chatHeight = 240 }
                    }
                    Divider()
                    Text("Drag the divider to resize chat. Position follows the fold when one is active.")
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
    private func resizeChat(_ side: Bool, _ delta: CGFloat) {
        // Start from the actual clamped allocation, so reversing a drag at a
        // limit responds immediately rather than consuming accumulated overshoot.
        if mode == .slim {
            if side { slimChatWidth = max(1, chatSize.width + delta) }
            else { slimChatHeight = max(1, chatSize.height + delta) }
        } else {
            if side { chatWidth = max(1, chatSize.width + delta) }
            else { chatHeight = max(1, chatSize.height + delta) }
        }
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

/// The public embed keeps its supported logical viewport while the native
/// presentation scales to any positive allocation. Cap extreme viewport aspect
/// ratios so a one-point pane cannot create an enormous WebKit backing view.
struct WatchVideoViewport {
    let size: CGSize
    let scale: CGFloat
    let visible: Bool

    init(available: CGSize) {
        visible = available.width.isFinite && available.height.isFinite
            && available.width > 0 && available.height > 0
        guard visible else { size = CGSize(width: 400, height: 300); scale = 0; return }
        if available.width >= 400 && available.height >= 300 {
            size = available; scale = 1
        } else {
            let aspect = min(4, max(0.25, available.width / available.height))
            let height = max(300, 400 / aspect)
            size = CGSize(width: max(400, height * aspect), height: height)
            scale = min(available.width / size.width, available.height / size.height)
        }
    }
}

/// Keep the player at the same structural location while controls move beside
/// it on short screens. Only the video presentation scales; native controls do not.
private struct WatchVideoPanelLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        let chrome = subviews.count == 2
            ? subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil)).height : 64
        return CGSize(width: width, height: proposal.height ?? 300 + chrome)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let measured = subviews[1].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        let chrome = measured.isFinite ? measured : 64
        let side = bounds.width >= 112 && bounds.height < 300 + chrome
        let video = CGRect(origin: bounds.origin, size: CGSize(
            width: side ? bounds.width - 64 : bounds.width,
            height: side ? bounds.height : max(0, bounds.height - min(chrome, max(0, bounds.height - 1)))))
        let controls = side
            ? CGRect(x: video.maxX, y: bounds.minY, width: 64, height: bounds.height)
            : CGRect(x: bounds.minX, y: video.maxY, width: bounds.width, height: min(chrome, bounds.height))
        for (index, rect) in [video, controls].enumerated() {
            subviews[index].place(at: rect.origin, anchor: .topLeading, proposal: ProposedViewSize(rect.size))
        }
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
        WatchVideoPanelLayout {
            GeometryReader { geometry in
                let viewport = WatchVideoViewport(available: geometry.size)
                let fits = viewport.visible
                ZStack(alignment: .topLeading) {
                    if session.isConfigured && session.hasCurrentPage && session.channel == channel.login {
                        // Keep one logical player/host while the visible video
                        // shrinks for a split adjustment, keyboard or rotation.
                        PlayerHost(session: session)
                            .frame(width: viewport.size.width, height: viewport.size.height)
                            .scaleEffect(viewport.scale)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .opacity(fits ? 1 : 0).accessibilityHidden(!fits).allowsHitTesting(fits)
                    }
                    if !fits || !session.isConfigured || !session.hasCurrentPage || session.channel != channel.login {
                        placeholder(fits: fits)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { session.recordVideoGeometry($0) }
                .task(id: "\(fits)|\(channel.login)") {
                    playerFits = fits
                    await session.videoAreaChanged(fits: fits, channel: channel.login, settlingFor: .milliseconds(350))
                }
            }
            // The ideal remains comfortable by default; constrained allocations
            // are presented at their requested size without stopping playback.
            .frame(idealHeight: 300)
            // Primary controls stay mounted and never vanish under focus or a tap.
            ViewThatFits(in: .horizontal) {
                transport
                transportRail
            }
        }
        .background(.black).clipped()
        .sheet(isPresented: $showDetails) { details }
    }

    private var playbackHeadline: String {
        if !playerFits { return "Video hidden" }
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
                playControl
                VStack(alignment: .leading, spacing: 2) {
                    Text(playbackHeadline)
                        .font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(!playerFits ? "Resize the video to show it." : session.status).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).accessibilityIdentifier("playbackStatus")
                }.frame(maxWidth: .infinity, alignment: .leading)
                if session.failure != nil && playerFits {
                    Button("Retry player", systemImage: "arrow.clockwise") { session.open(channel: channel.login, forceReload: true) }
                        .labelStyle(.iconOnly).frame(width: 44, height: 48)
                }
            } else {
                Image(systemName: playerFits ? "play.rectangle" : "rectangle.expand.vertical")
                    .frame(width: 48, height: 48)
                Text(playerFits ? "Opening channel…" : "Video hidden").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
            informationControl
            focusControl
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(minHeight: 64)
        .background(AppTheme.surface)
    }

    private var playControl: some View {
        Button(session.isPlaying ? "Pause video" : "Play video", systemImage: session.isPlaying ? "pause.fill" : "play.fill") {
            Task {
                if session.isPlaying { await session.pause() }
                else { await session.play() }
            }
        }
        .labelStyle(.iconOnly).font(.title3)
        .frame(width: 48, height: 48)
        .background(AppTheme.accent.opacity(0.16), in: .circle)
        .accessibilityValue("\(playbackHeadline). \(session.status)")
        .disabled(!session.isPlaying && (!session.canPlay || !playerFits))
    }

    private var informationControl: some View {
        Button("About \(channel.name)", systemImage: "info.circle") { showDetails = true }
            .labelStyle(.iconOnly).frame(width: 44, height: 48)
    }

    @ViewBuilder private var focusControl: some View {
        if let toggleFullVideo {
            Button(fullVideo ? "Show video and chat" : "Focus on video", systemImage: fullVideo ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right", action: toggleFullVideo)
                .labelStyle(.iconOnly).frame(width: 44, height: 48)
        }
    }

    private var transportRail: some View {
        ScrollView {
            VStack(spacing: 8) {
                if session.channel == channel.login {
                    playControl
                    if session.failure != nil && playerFits {
                        Button("Retry player", systemImage: "arrow.clockwise") { session.open(channel: channel.login, forceReload: true) }
                            .labelStyle(.iconOnly).frame(width: 44, height: 48)
                    }
                }
                informationControl
                focusControl
            }
            .padding(8).frame(width: 64)
        }.scrollIndicators(.hidden)
        .frame(width: 64).frame(maxHeight: .infinity, alignment: .top)
        .background(AppTheme.surface)
    }

    private func placeholder(fits: Bool) -> some View {
        ContentUnavailableView {
            Label(session.isConfigured ? (fits ? "Opening Twitch" : "Video hidden") : "Video unavailable", systemImage: "play.rectangle")
        } description: {
            Text(session.isConfigured ? (fits && session.channel == channel.login ? session.status : "Resize the video pane to show it, or focus on video.") : "The video service is not configured in this build.")
        } actions: {
            if !fits, !fullVideo, let toggleFullVideo {
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
