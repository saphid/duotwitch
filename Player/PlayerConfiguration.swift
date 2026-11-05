import Foundation

struct PlayerConfiguration {
    let hostURL: URL?
    let probeEnabled: Bool

    static var current: PlayerConfiguration {
        let raw = Bundle.main.object(forInfoDictionaryKey: "TwitchPlayerHost") as? String ?? ""
        let host = URL(string: raw)
        let valid = host?.scheme == "https" && host?.host != nil && host?.user == nil && host?.password == nil
        #if DEBUG
        let probe = UserDefaults.standard.bool(forKey: "DuoTwitchProbe")
        #else
        let probe = false
        #endif
        return PlayerConfiguration(hostURL: valid ? host : nil, probeEnabled: probe)
    }
}
