import SwiftUI

@main
struct DuoTwitchApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            root
                .preferredColorScheme(.dark)
                .tint(AppTheme.accent)
        }
    }

    @ViewBuilder private var root: some View {
        #if DEBUG
        if PlayerConfiguration.current.probeEnabled {
            PlayerProbeView(session: model.player)
        } else {
            MainView(app: model)
        }
        #else
        MainView(app: model)
        #endif
    }
}
