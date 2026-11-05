import Foundation

@MainActor
protocol ChatSocket: AnyObject {
    func resume()
    func cancel()
    func receiveData() async throws -> Data
}

@MainActor
final class URLSessionChatSocket: ChatSocket {
    private let task: URLSessionWebSocketTask
    init(url: URL) {
        task = URLSession.shared.webSocketTask(with: url)
        task.maximumMessageSize = 1_048_576
    }
    func resume() { task.resume() }
    func cancel() { task.cancel(with: .goingAway, reason: nil) }
    func receiveData() async throws -> Data {
        switch try await task.receive() {
        case .data(let data): return data
        case .string(let text): return Data(text.utf8)
        @unknown default: throw TwitchError.invalidResponse
        }
    }
}
