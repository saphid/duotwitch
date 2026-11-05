import SwiftUI

struct WatchView: View {
    @Bindable var app: AppModel
    let channel: WatchedChannel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("watchMode") private var mode: WatchMode = .balanced
    @AppStorage("chatLeading") private var chatLeading = false
    @State private var fold = FoldState()
    @State private var appearance = UUID()

    var body: some View {
        ArrangementView {
            WatchVideoPanel(session: app.player, channel: channel)
        } secondary: {
            NativeChatView(session: app.chat, signedIn: app.auth.account != nil, composerVisible: mode != .video) { app.accountPresented = true }
                .accessibilityHidden(mode == .video)
                .opacity(mode == .video ? 0 : 1)
                .allowsHitTesting(mode != .video)
        }
        .arrangementViewStyle(WatchArrangementStyle(compact: sizeClass != .regular,
            division: fold.division, mode: mode, chatLeading: chatLeading))
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
                    Toggle("Chat on the left", isOn: $chatLeading)
                    Button("Chat with Picture in Picture", systemImage: "pip") { }.disabled(true)
                    Text("Picture in Picture support is still being verified.")
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

private struct WatchVideoPanel: View {
    let session: PlaybackSession
    let channel: WatchedChannel
    @State private var playerFits = false

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let fits = geometry.size.width >= 400 && geometry.size.height >= 300
                Group {
                    if session.isConfigured && fits && session.hasCurrentPage && session.channel == channel.login {
                        PlayerHost(session: session)
                    } else {
                        ContentUnavailableView {
                            Label(session.isConfigured ? (fits ? "Open this channel" : "Give video more room") : "Video isn’t connected yet", systemImage: "play.rectangle")
                        } description: {
                            Text(session.isConfigured ? (fits && session.channel == channel.login ? session.status : "Expand the video view or continue watching in Twitch.") : "The video service is not configured in this development build.")
                        } actions: {
                            Link("Watch in Twitch", destination: URL(string: "https://www.twitch.tv/\(channel.login)")!)
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .task(id: "\(fits)|\(channel.login)") {
                    playerFits = fits
                    await session.videoAreaChanged(fits: fits, channel: channel.login)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(channel.name).font(.headline)
                    if channel.isLive == true { Text("LIVE").font(.caption2.bold()).foregroundStyle(.red) }
                    Spacer(minLength: 0)
                    if let viewers = channel.viewers {
                        Label(viewers.formatted(.number.notation(.compactName)), systemImage: "person.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !channel.title.isEmpty { Text(channel.title).font(.subheadline).lineLimit(2) }
                if !channel.category.isEmpty { Text(channel.category).font(.caption).foregroundStyle(.secondary) }
                if session.isConfigured && session.channel == channel.login {
                    Text(session.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    if session.isPlaying {
                        Button("Pause video", systemImage: "pause.fill") { Task { await session.pause() } }
                            .buttonStyle(.bordered).frame(minHeight: 44)
                    }
                    if session.failure != nil && playerFits {
                        Button("Retry player", systemImage: "arrow.clockwise") { session.open(channel: channel.login, forceReload: true) }
                            .controlSize(.regular).buttonStyle(.bordered).frame(minHeight: 44)
                    }
                }
                if session.channel == channel.login, let warning = session.audioWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.surface)
        }.background(.black)
    }
}
