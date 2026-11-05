import Foundation

struct EventSubFrame: Decodable {
    let metadata: Metadata
    let payload: Payload

    struct Metadata: Decodable {
        let messageId: String
        let messageType: String
        let subscriptionType: String?
    }
    struct Payload: Decodable {
        let session: Session?
        let subscription: Subscription?
    }
    struct Session: Decodable {
        let id: String
        let keepaliveTimeoutSeconds: Int?
        let reconnectUrl: String?
    }
    struct Subscription: Decodable { let type: String; let status: String? }

    static func eventData(from data: Data) throws -> Data {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["payload"] as? [String: Any],
              let event = payload["event"] as? [String: Any] else { throw TwitchError.invalidResponse }
        return try JSONSerialization.data(withJSONObject: event)
    }

    static func validReconnectURL(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "wss", url.host == "eventsub.wss.twitch.tv",
              url.path == "/ws", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, url.fragment == nil else { return nil }
        return url
    }
}
