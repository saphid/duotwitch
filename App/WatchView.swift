import SwiftUI

struct WatchView: View {
    @Bindable var app: AppModel
    let channel: WatchedChannel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var showDetails = false
    @State private var showLayout = false
    @State private var showChatConnectionNotice = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        let layoutCompact = sizeClass != .regular
        let layoutMode = mode
        let layoutDivision = fold.division
        ArrangementView {
            WatchVideoPanel(session: app.player, channel: channel)
        } secondary: {
            WatchPaneBounds {
                NativeChatView(session: app.chat, signedIn: app.auth.account != nil, composerVisible: mode != .video,
                    composerFocus: $composerFocused) { app.accountPresented = true }
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
            if composerFocused {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Hide keyboard", systemImage: "keyboard.chevron.compact.down") { composerFocused = false }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("hideChatKeyboard")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(app.player.isPlaying ? "Pause video" : "Play video", systemImage: app.player.isPlaying ? "pause.fill" : "play.fill") {
                        Task {
                            if app.player.isPlaying { await app.player.pause() }
                            else { await app.player.play() }
                        }
                    }.disabled(!app.player.isPlaying && !app.player.canPlay)
                    if app.player.failure != nil {
                        Button("Retry player", systemImage: "arrow.clockwise") { app.player.open(channel: channel.login, forceReload: true) }
                    }
                    Button("Channel details", systemImage: "info.circle") { showDetails = true }
                    Button("Account", systemImage: "person.crop.circle") { app.accountPresented = true }
                    if app.chat.gapNotice != nil {
                        Button("Chat connection notice", systemImage: "exclamationmark.bubble") { showChatConnectionNotice = true }
                    }
                    if app.auth.account != nil && app.chat.connection != .connected {
                        Button("Reconnect chat", systemImage: "arrow.clockwise") { app.chat.retry() }
                    }
                    Divider()
                    Button("Layout…", systemImage: "rectangle.split.2x1") { showLayout = true }
                    Divider()
                    Link("Open in Twitch", destination: URL(string: "https://www.twitch.tv/\(channel.login)")!)
                } label: { Label("Viewing options", systemImage: "ellipsis") }
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                .overlay(alignment: .topTrailing) {
                    if app.chat.gapNotice != nil {
                        Circle().fill(.orange).frame(width: 6, height: 6).padding(5)
                            .accessibilityHidden(true).allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(app.chat.gapNotice == nil ? "Viewing options" : "Viewing options, chat connection notice")
            }
        }
        .sheet(isPresented: $showDetails) { details }
        .sheet(isPresented: $showLayout) { layoutSettings }
        .alert("Chat connection", isPresented: $showChatConnectionNotice) {
            Button("OK") { app.chat.dismissGapNotice() }
        } message: {
            Text(app.chat.gapNotice ?? "")
        }
        .onAppear { app.watch(channel, appearance: appearance) }
        .onChange(of: channel.id) { _, _ in app.watch(channel, appearance: appearance) }
        .onChange(of: channel.login) { _, _ in app.watch(channel, appearance: appearance) }
        .onDisappear { app.leaveWatch(channel, appearance: appearance) }
    }
    private var chatIsBeside: Bool { chatSize.width < watchSize.width - 1 }

    private var layoutSettings: some View {
        NavigationStack {
            Form {
                if dynamicTypeSize.isAccessibilitySize {
                    Section("View") {
                        viewPicker.pickerStyle(.inline).labelsHidden()
                    }
                    Section("Chat position") {
                        chatPositionPicker.pickerStyle(.inline).labelsHidden()
                    }
                }
                Section {
                    if !dynamicTypeSize.isAccessibilitySize {
                        viewPicker
                        chatPositionPicker
                    }
                    if chatIsBeside && mode != .video {
                        Toggle("Chat on the left", isOn: $chatLeading)
                    }
                }
                Section {
                    Button("Reset split", systemImage: "arrow.counterclockwise") {
                        if mode == .slim { slimChatWidth = 160; slimChatHeight = 160 }
                        else { chatWidth = 240; chatHeight = 240 }
                    }.disabled(mode == .video || fold.division != nil)
                } footer: {
                    Text("Drag the handle between video and chat to resize.")
                }
            }
            .navigationTitle("Layout").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showLayout = false } } }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }

    private var viewPicker: some View {
        Picker("View", selection: $mode) {
            ForEach(WatchMode.allCases) { item in
                Text(item.rawValue).fixedSize(horizontal: false, vertical: true).tag(item)
            }
        }
    }

    private var chatPositionPicker: some View {
        Picker("Chat position", selection: $chatPlacement) {
            ForEach(WatchChatPlacement.allCases) { item in
                Text(item.rawValue).fixedSize(horizontal: false, vertical: true).tag(item)
            }
        }.disabled(mode == .video)
    }

    private var details: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(channel.name).font(.title.bold())
                    NavigationLink {
                        PlaybackDiagnosticsView(diagnostics: app.player.diagnostics)
                    } label: {
                        Label("Playback diagnostics", systemImage: "waveform.path.ecg")
                    }.frame(minHeight: 44)
                    Label(app.player.status, systemImage: "play.rectangle")
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

    private func resizeChat(_ side: Bool, _ delta: CGFloat) {
        // Consume every native pan delta even when events arrive before the
        // next layout pass. Clamp the saved extent to the available pane first,
        // so reversing at an edge never consumes accumulated overshoot.
        let limit = max(1, (side ? watchSize.width : watchSize.height) - 13)
        let current = CGFloat(mode == .slim ? (side ? slimChatWidth : slimChatHeight)
                                            : (side ? chatWidth : chatHeight))
        let next = min(limit, max(1, min(limit, max(1, current)) + delta))
        if mode == .slim {
            if side { slimChatWidth = Double(next) }
            else { slimChatHeight = Double(next) }
        } else {
            if side { chatWidth = Double(next) }
            else { chatHeight = Double(next) }
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

/// Keep the public embed's logical viewport stable: resizing it during rotation
/// can stop the remote player. Fit the complete player inside each native pane.
struct WatchVideoViewport {
    let size = CGSize(width: 1280, height: 720)
    let scale: CGFloat
    let visible: Bool

    init(available: CGSize) {
        visible = available.width.isFinite && available.height.isFinite
            && available.width > 0 && available.height > 0
        scale = visible ? min(available.width / size.width, available.height / size.height) : 0
    }
}

struct WatchVideoPanel: View {
    let session: PlaybackSession
    let channel: WatchedChannel

    var body: some View {
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
                await session.videoAreaChanged(fits: fits, channel: channel.login, settlingFor: .milliseconds(350))
            }
        }
        .frame(idealHeight: 300)
        .background(.black).clipped()
        .overlay(alignment: .topLeading) {
            if session.failure != nil {
                Text(session.status).font(.caption).padding(8)
                    .background(.regularMaterial, in: .rect(cornerRadius: 8))
                    .padding(8).allowsHitTesting(false)
            }
        }
    }

    private func placeholder(fits: Bool) -> some View {
        ContentUnavailableView {
            Label(session.isConfigured ? (fits ? "Opening Twitch" : "Video hidden") : "Video unavailable", systemImage: "play.rectangle")
        } description: {
            Text(session.isConfigured ? (fits && session.channel == channel.login ? session.status : "Resize the video pane to show it, or focus on video.") : "The video service is not configured in this build.")
        } actions: {
            Link("Watch in Twitch", destination: URL(string: "https://www.twitch.tv/\(channel.login)")!)
                .buttonStyle(.bordered)
        }
    }
}
