import Foundation

enum TwitchError: LocalizedError, Equatable {
    case notConfigured
    case signInRequired
    case invalidResponse
    case unauthorized
    case permissionDenied
    case rateLimited(until: Date)
    case serviceUnavailable
    case authorizationExpired
    case authorizationDeclined
    case missingScopes
    case keychain
    case messageNotSent(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Twitch sign-in is not configured in this build yet."
        case .signInRequired: "Sign in to Twitch to continue."
        case .invalidResponse: "Twitch returned an unexpected response. Please try again."
        case .unauthorized: "Your Twitch session has expired. Please sign in again."
        case .permissionDenied: "Twitch did not allow this action for your account."
        case .rateLimited: "Twitch is receiving too many requests. Please wait a moment."
        case .serviceUnavailable: "Twitch is unavailable right now. Please try again."
        case .authorizationExpired: "This sign-in code has expired. Start again for a new code."
        case .authorizationDeclined: "Twitch sign-in was cancelled or declined."
        case .missingScopes: "Please sign in again and allow the requested chat and following permissions."
        case .keychain: "Your saved sign-in could not be accessed securely on this iPhone."
        case .messageNotSent(let reason): reason
        }
    }
}

@MainActor
final class TwitchHTTP {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    static func form(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return fields.sorted { $0.key < $1.key }.map {
            $0.key.addingPercentEncoding(withAllowedCharacters: allowed)! + "=" +
            $0.value.addingPercentEncoding(withAllowedCharacters: allowed)!
        }.joined(separator: "&").data(using: .utf8)!
    }

    func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError where error.code == .cancelled && Task.isCancelled { throw CancellationError() }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw TwitchError.invalidResponse }
        return (data, response)
    }

    static func requireSuccess(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200..<300: return
        case 401: throw TwitchError.unauthorized
        case 403: throw TwitchError.permissionDenied
        case 429:
            let reset = response.value(forHTTPHeaderField: "Ratelimit-Reset").flatMap(Double.init)
            throw TwitchError.rateLimited(until: reset.map { Date(timeIntervalSince1970: $0) } ?? Date().addingTimeInterval(30))
        case 500...599: throw TwitchError.serviceUnavailable
        default: throw TwitchError.invalidResponse
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do { return try decoder.decode(type, from: data) }
        catch { throw TwitchError.invalidResponse }
    }
}
