import XCTest
@testable import DuoTwitch

final class ChatBufferTests: XCTestCase {
    func testBusyChatIsBoundedAndDuplicateMessagesDoNotMoveTheReadingOrder() throws {
        var buffer = ChatBuffer(capacity: 3)
        for id in 0..<10 { buffer.append(try message(id: String(id))) }
        buffer.append(try message(id: "8"))
        XCTAssertEqual(buffer.messages.map(\.id), ["7", "8", "9"])
    }

    func testModerationRemovesPendingMessagesBeforeTheyReachTheUI() throws {
        var buffer = ChatBuffer()
        buffer.append(try message(id: "a", user: "one"))
        buffer.append(try message(id: "b", user: "two"))
        buffer.append(try message(id: "c", user: "one"))
        buffer.delete(id: "a")
        buffer.clear(userId: "one")
        XCTAssertEqual(buffer.messages.map(\.id), ["b"])
        buffer.clear()
        XCTAssertTrue(buffer.messages.isEmpty)
        buffer.append(try message(id: "d"))
        XCTAssertEqual(buffer.messages.map(\.id), ["d"])
    }

    func testReconnectURLCannotLeakUserSessionToAnotherHost() {
        XCTAssertNotNil(EventSubFrame.validReconnectURL("wss://eventsub.wss.twitch.tv/ws?session=reconnect"))
        for value in ["ws://eventsub.wss.twitch.tv/ws", "wss://eventsub.wss.twitch.tv.evil.test/ws", "wss://user@eventsub.wss.twitch.tv/ws", "wss://eventsub.wss.twitch.tv:8443/ws", "wss://eventsub.wss.twitch.tv/not-ws", "wss://eventsub.wss.twitch.tv/ws#fragment"] {
            XCTAssertNil(EventSubFrame.validReconnectURL(value), value)
        }
    }

    private func message(id: String, user: String = "viewer") throws -> ChatMessage {
        let object: [String: Any] = [
            "broadcaster_user_id": "channel", "chatter_user_id": user,
            "chatter_user_name": user, "chatter_user_login": user,
            "message_id": id, "message": ["text": "Hello", "fragments": [["type": "text", "text": "Hello"]]],
            "color": "#FFFFFF", "badges": []
        ]
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return ChatMessage(event: try decoder.decode(ChatEvent.self, from: JSONSerialization.data(withJSONObject: object)))
    }
}
