import SwiftUI

@main
struct DuoTwitchApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            root
                .preferredColorScheme(.dark)
                .tint(AppTheme.accent)
                .sheet(isPresented: $model.accountPresented) { AccountView(app: model) }
                .onChange(of: model.auth.account) { _, _ in model.accountChanged() }
                .onChange(of: phase, initial: true) { _, value in
                    model.player.recordDiagnostic("app.scene", values: ["phase": .text(String(describing: value))])
                }
        }
    }

    @ViewBuilder private var root: some View {
        #if DEBUG
        if PlayerConfiguration.current.probeEnabled {
            PlayerProbeView(session: model.player)
        } else if let login = UserDefaults.standard.string(forKey: "DuoTwitchWatchChannel"),
                  let valid = PlaybackSession.validChannel(login) {
            // DEBUG-only entry to the real watch surface, without a fake
            // account, chat data, or any change to Release authorization.
            DebugWatchEntry(app: model, login: valid)
        } else {
            MainView(app: model)
        }
        #else
        MainView(app: model)
        #endif
    }
}

#if DEBUG
/// Video can be inspected signed out, but authenticated chat needs a real
/// broadcaster ID. Never substitute a login for Twitch's numeric identity.
struct DebugWatchEntry: View {
    @Bindable var app: AppModel
    let login: String
    @State private var user: TwitchUser?
    @State private var lookupFailed = false
    @State private var retry = 0

    private var channel: WatchedChannel {
        WatchedChannel(user: user ?? TwitchUser(id: "", login: login, displayName: login,
            description: "", profileImageUrl: "", offlineImageUrl: ""))
    }

    var body: some View {
        NavigationStack {
            WatchView(app: app, channel: channel)
                .overlay(alignment: .top) {
                    if lookupFailed {
                        Button("Couldn’t load channel identity. Retry") { retry += 1 }
                            .buttonStyle(.bordered).padding().background(.regularMaterial)
                    }
                }
        }
        .task(id: "\(app.auth.sessionId)|\(app.auth.account?.id ?? "")|\(login)|\(retry)") {
            user = nil
            lookupFailed = false
            guard app.auth.account != nil else { return }
            do {
                let resolved = try await app.api.user(login: login)
                guard !Task.isCancelled else { return }
                user = resolved
                lookupFailed = resolved == nil
            } catch is CancellationError { }
            catch { if !Task.isCancelled { lookupFailed = true } }
        }
    }
}
#endif
