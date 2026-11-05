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
            NavigationStack {
                WatchView(app: model, channel: WatchedChannel(user: TwitchUser(
                    id: valid, login: valid, displayName: valid,
                    description: "", profileImageUrl: "", offlineImageUrl: "")))
            }
        } else {
            MainView(app: model)
        }
        #else
        MainView(app: model)
        #endif
    }
}
