import Foundation

@MainActor
final class TwitchAPI {
    let auth: TwitchAuth
    private let http: TwitchHTTP
    init(auth: TwitchAuth, http: TwitchHTTP? = nil) { self.auth = auth; self.http = http ?? TwitchHTTP() }

    func streams(category: String? = nil, cursor: String? = nil) async throws -> HelixPage<TwitchStream> {
        var query = [URLQueryItem(name: "first", value: "30")]
        if let category { query.append(URLQueryItem(name: "game_id", value: category)) }
        if let cursor { query.append(URLQueryItem(name: "after", value: cursor)) }
        return try await request(path: "streams", query: query)
    }

    func followedStreams(cursor: String? = nil) async throws -> HelixPage<TwitchStream> {
        guard let id = auth.account?.id else { throw TwitchError.signInRequired }
        var query = [URLQueryItem(name: "user_id", value: id), URLQueryItem(name: "first", value: "30")]
        if let cursor { query.append(URLQueryItem(name: "after", value: cursor)) }
        return try await request(path: "streams/followed", query: query)
    }

    func categories(query: String? = nil, cursor: String? = nil) async throws -> HelixPage<TwitchCategory> {
        var fields = [URLQueryItem(name: "first", value: "24")]
        if let query, !query.isEmpty { fields.append(URLQueryItem(name: "query", value: query)) }
        if let cursor { fields.append(URLQueryItem(name: "after", value: cursor)) }
        return try await request(path: query?.isEmpty == false ? "search/categories" : "games/top", query: fields)
    }

    func searchChannels(query: String, cursor: String? = nil) async throws -> HelixPage<TwitchChannel> {
        var fields = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "first", value: "30")]
        if let cursor { fields.append(URLQueryItem(name: "after", value: cursor)) }
        return try await request(path: "search/channels", query: fields)
    }

    func user(login: String) async throws -> TwitchUser? {
        let page: HelixPage<TwitchUser> = try await request(path: "users", query: [URLQueryItem(name: "login", value: login)])
        return page.data.first
    }

    func currentStream(login: String) async throws -> TwitchStream? {
        let page: HelixPage<TwitchStream> = try await request(path: "streams", query: [URLQueryItem(name: "user_login", value: login)])
        return page.data.first
    }

    func sendChat(broadcasterId: String, message: String, replyTo: String? = nil) async throws -> ChatSendOutcome {
        guard let userId = auth.account?.id else { throw TwitchError.signInRequired }
        var body = ["broadcaster_id": broadcasterId, "sender_id": userId, "message": message]
        if let replyTo { body["reply_parent_message_id"] = replyTo }
        let page: HelixPage<ChatSendOutcome> = try await request(path: "chat/messages", method: "POST", body: JSONEncoder().encode(body))
        guard let result = page.data.first else { throw TwitchError.invalidResponse }
        return result
    }

    func subscribe(type: String, version: String = "1", broadcasterId: String, sessionId: String) async throws {
        guard let userId = auth.account?.id else { throw TwitchError.signInRequired }
        struct Subscription: Encodable {
            let type: String
            let version: String
            let condition: [String: String]
            let transport: [String: String]
        }
        let data = try JSONEncoder().encode(Subscription(type: type, version: version,
            condition: ["broadcaster_user_id": broadcasterId, "user_id": userId],
            transport: ["method": "websocket", "session_id": sessionId]))
        let _: HelixPage<SubscriptionReceipt> = try await request(path: "eventsub/subscriptions", method: "POST", body: data)
    }

    private struct SubscriptionReceipt: Decodable { let id: String }
    private struct EmptyResponse: Decodable { }

    private func request<T: Decodable>(path: String, method: String = "GET", query: [URLQueryItem] = [], body: Data? = nil, retryUnauthorized: Bool = true) async throws -> T {
        let ticket = auth.sessionId
        let token = try await auth.accessToken()
        var url = URLComponents(string: "https://api.twitch.tv/helix/\(path)")!
        if !query.isEmpty { url.queryItems = query }
        var request = URLRequest(url: url.url!)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.clientId, forHTTPHeaderField: "Client-Id")
        if let body { request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        var response = try await http.perform(request)
        if response.1.statusCode == 401 && retryUnauthorized {
            let fresh = try await auth.accessToken(forceRefresh: true)
            guard auth.sessionId == ticket else { throw CancellationError() }
            request.setValue("Bearer \(fresh)", forHTTPHeaderField: "Authorization")
            response = try await http.perform(request)
        }
        guard auth.sessionId == ticket else { throw CancellationError() }
        try TwitchHTTP.requireSuccess(response.1)
        if response.0.isEmpty, let value = EmptyResponse() as? T { return value }
        return try TwitchHTTP.decode(T.self, from: response.0)
    }
}
