import XCTest
@testable import DuoTwitch

@MainActor
final class ChatSessionTests: XCTestCase {
    override func tearDown() { StubTwitchProtocol.install(nil); super.tearDown() }

    func testSuccessfulSendSurvivesBackgroundSuspension() async throws {
        let gate = DispatchSemaphore(value: 0)
        let socket = FakeChatSocket(welcome: true)
        let session = try await makeSession(sockets: [socket], sendGate: gate)
        defer { session.stop(clear: true) }
        session.draft = "A deliberate message"
        let send = Task { await session.sendDraft() }
        try await waitUntil { session.isSending }
        session.suspend()
        XCTAssertTrue(session.isSending, "A transport stop must not allow a second send")
        gate.signal()
        await send.value
        XCTAssertEqual(session.draft, "")
        XCTAssertFalse(session.isSending)
        XCTAssertNil(session.sendError)
    }

    func testDroppedSendRetainsDraftAndReasonAcrossReconnect() async throws {
        let gate = DispatchSemaphore(value: 0)
        let session = try await makeSession(sockets: [FakeChatSocket(welcome: true), FakeChatSocket(welcome: true)], sendGate: gate, isSent: false)
        defer { session.stop(clear: true) }
        session.draft = "Keep this draft"
        let send = Task { await session.sendDraft() }
        try await waitUntil { session.isSending }
        session.stop()
        session.retry()
        gate.signal()
        await send.value
        XCTAssertEqual(session.draft, "Keep this draft")
        XCTAssertEqual(session.sendError, "Held by AutoMod")
        XCTAssertFalse(session.isSending)
    }

    func testChannelChangeCannotEraseNewDraftWithOldAcknowledgement() async throws {
        let gate = DispatchSemaphore(value: 0)
        let session = try await makeSession(sockets: [FakeChatSocket(welcome: true), FakeChatSocket(welcome: true)], sendGate: gate)
        defer { session.stop(clear: true) }
        var completions: [(String, String, String?)] = []
        session.onSendResult = { _, channel, text, error in completions.append((channel, text, error)) }
        session.draft = "Old channel"
        let send = Task { await session.sendDraft() }
        try await waitUntil { session.isSending }
        session.start(broadcasterId: "other")
        session.draft = "New channel"
        gate.signal()
        await send.value
        XCTAssertEqual(session.draft, "New channel")
        XCTAssertNil(session.sendError)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.0, "channel")
        XCTAssertEqual(completions.first?.1, "Old channel")
        XCTAssertNil(completions.first?.2)
    }

    func testReturningToAChannelWhileItsSendIsPendingCannotResendTheDraft() async throws {
        let gate = DispatchSemaphore(value: 0)
        let session = try await makeSession(sockets: [FakeChatSocket(welcome: true), FakeChatSocket(welcome: true), FakeChatSocket(welcome: true)], sendGate: gate)
        defer { session.stop(clear: true) }
        session.draft = "Pending message"
        let send = Task { await session.sendDraft() }
        try await waitUntil { session.isSending }
        // AppModel clears the current chat before starting another channel.
        session.stop(clear: true)
        session.start(broadcasterId: "other")
        XCTAssertFalse(session.isSending)
        session.stop(clear: true)
        session.start(broadcasterId: "channel")
        XCTAssertTrue(session.isSending)
        gate.signal()
        await send.value
        XCTAssertFalse(session.isSending)
    }

    func testResumeWithoutSuspensionDoesNotInventAGap() async throws {
        let socket = FakeChatSocket(welcome: true)
        let session = try await makeSession(sockets: [socket])
        defer { session.stop(clear: true) }
        session.resume()
        XCTAssertNil(session.gapNotice)
        XCTAssertEqual(session.connection, .connected)
        XCTAssertFalse(socket.cancelled)
    }

    func testUncertainSendOutcomesKeepDraftAndWarnBeforeResending() async throws {
        for status in [502, 200] {
            let session = try await makeSession(sockets: [FakeChatSocket(welcome: true)], sendStatus: status)
            session.draft = "Could already be delivered"
            await session.sendDraft()
            XCTAssertEqual(session.draft, "Could already be delivered")
            XCTAssertTrue(session.sendError?.contains("Check chat before sending again") == true)
            session.stop(clear: true)
        }
    }

    func testStoppingDuringMigrationClosesBothSockets() async throws {
        let original = FakeChatSocket(welcome: true)
        let replacement = FakeChatSocket()
        let session = try await makeSession(sockets: [original, replacement])
        original.push(frame(type: "session_reconnect", payload: ["session": ["id": "old", "reconnect_url": "wss://eventsub.wss.twitch.tv/ws?reconnect=test"]]))
        try await waitUntil { replacement.resumed }
        session.stop(clear: true)
        XCTAssertTrue(original.cancelled)
        XCTAssertTrue(replacement.cancelled)
        XCTAssertEqual(session.connection, .signedOut)
    }

    func testMalformedNotificationDoesNotDisconnectOrPoisonDeduplication() async throws {
        let socket = FakeChatSocket(welcome: true)
        let session = try await makeSession(sockets: [socket])
        defer { session.stop(clear: true) }
        socket.push(frame(type: "notification", id: "event-one", subscription: "channel.chat.message", payload: ["event": ["bad": "payload"]]))
        let event: [String: Any] = ["broadcaster_user_id": "channel", "chatter_user_id": "viewer", "chatter_user_name": "Viewer", "chatter_user_login": "viewer", "message_id": "message-one", "message": ["text": "Hello", "fragments": [["type": "text", "text": "Hello"]]], "color": "#FFFFFF", "badges": []]
        let valid = frame(type: "notification", id: "event-one", subscription: "channel.chat.message", payload: ["event": event])
        socket.push(valid)
        socket.push(valid)
        try await waitUntil { session.messages.count == 1 }
        XCTAssertEqual(session.connection, .connected)
        XCTAssertEqual(session.messages.first?.id, "message-one")
        XCTAssertFalse(socket.cancelled)
    }

    func testRevocationStopsTheSocketWithoutReconnecting() async throws {
        let socket = FakeChatSocket(welcome: true)
        let session = try await makeSession(sockets: [socket])
        defer { session.stop(clear: true) }
        socket.push(frame(type: "revocation", payload: [:]))
        try await waitUntil { socket.cancelled }
        guard case .failed = session.connection else { return XCTFail("Revocation must be final") }
    }

    func testSuccessfulHandoffDrainsBothSocketsWithoutResubscribing() async throws {
        let original = FakeChatSocket(welcome: true)
        let replacement = FakeChatSocket(welcome: true)
        let subscriptions = RequestCounter()
        let session = try await makeSession(sockets: [original, replacement], subscriptions: subscriptions)
        defer { session.stop(clear: true) }
        original.push(frame(type: "session_reconnect", payload: ["session": ["id": "old", "reconnect_url": "wss://eventsub.wss.twitch.tv/ws?handoff=test"]]))
        try await waitUntil { replacement.resumed }
        try await Task.sleep(for: .milliseconds(30))
        original.push(chatNotification(id: "old-tail"))
        replacement.push(chatNotification(id: "new-head"))
        replacement.push(chatNotification(id: "old-tail"))
        try await waitUntil { session.messages.count == 2 }
        XCTAssertEqual(Set(session.messages.map(\.id)), ["old-tail", "new-head"])
        XCTAssertEqual(subscriptions.count, 4, "A reconnect URL transfers subscriptions")
        XCTAssertEqual(session.connection, .connected)
        session.stop()
        XCTAssertTrue(original.cancelled)
        XCTAssertTrue(replacement.cancelled)
    }

    func testWatchdogCancellationUsesRealTransportErrorAndReconnects() async throws {
        var clock = Date()
        let original = FakeChatSocket(welcome: true)
        let replacement = FakeChatSocket(welcome: true)
        let session = try await makeSession(sockets: [original, replacement], now: { clock })
        defer { session.stop(clear: true) }
        clock = clock.addingTimeInterval(30)
        try await waitUntil { original.cancelled && session.connection == .reconnecting }
        XCTAssertEqual(session.connection, .reconnecting)
        try await waitUntil(timeout: 5) { replacement.resumed && session.connection == .connected }
        XCTAssertNotNil(session.gapNotice)
    }

    func testMigrationTimeoutCancelsPendingSocketAndReconnects() async throws {
        let original = FakeChatSocket(welcome: true)
        let replacement = FakeChatSocket()
        let session = try await makeSession(sockets: [original, replacement], migrationTimeout: .milliseconds(30))
        defer { session.stop(clear: true) }
        original.push(frame(type: "session_reconnect", payload: ["session": ["id": "old", "reconnect_url": "wss://eventsub.wss.twitch.tv/ws?timeout=test"]]))
        // Cancelling the pending receive resumes its continuation; migration
        // cleanup runs on the next actor turn, after the fake marks cancelled.
        try await waitUntil { replacement.cancelled && original.cancelled && session.connection == .reconnecting }
        XCTAssertTrue(original.cancelled)
        XCTAssertEqual(session.connection, .reconnecting)
    }

    func testAppModelReconcilesConfirmedSendsAndDropsWithSavedChannelDrafts() {
        let player = PlaybackSession(loadRequest: { _, _ in }, activateAudio: {}, deactivateAudio: {}, pauseMedia: { _ in })
        let app = AppModel(player: player)
        let a = WatchedChannel(channel: TwitchChannel(id: "a", broadcasterLogin: "a", displayName: "A", gameName: "", title: "", thumbnailUrl: "", isLive: true))
        let b = WatchedChannel(channel: TwitchChannel(id: "b", broadcasterLogin: "b", displayName: "B", gameName: "", title: "", thumbnailUrl: "", isLive: true))
        app.watch(a)
        app.chat.draft = "Confirmed message"
        app.watch(b)
        app.chat.draft = "Rejected message"
        app.chat.onSendResult?(app.auth.sessionId, "a", "Confirmed message", nil)
        app.watch(a)
        XCTAssertEqual(app.chat.draft, "")
        app.chat.onSendResult?(app.auth.sessionId, "b", "Rejected message", "Held by AutoMod")
        let appearance = app.watch(b)
        XCTAssertEqual(app.chat.draft, "Rejected message")
        XCTAssertEqual(app.chat.sendError, "Held by AutoMod")
        app.leaveWatch(b, appearance: appearance)
        XCTAssertFalse(app.isWatching)
        app.watch(b)
        XCTAssertTrue(app.isWatching)
        XCTAssertEqual(app.chat.draft, "Rejected message")
    }

    private func makeSession(sockets: [FakeChatSocket], sendGate: DispatchSemaphore? = nil, isSent: Bool = true, subscriptions: RequestCounter? = nil, now: @escaping @MainActor () -> Date = { .now }, migrationTimeout: Duration = .seconds(25), sendStatus: Int? = nil) async throws -> ChatSession {
        StubTwitchProtocol.install { request in
            if request.url!.path.hasSuffix("/validate") {
                return (200, ["client_id": "test-client", "user_id": "viewer", "login": "viewer", "expires_in": 3600, "scopes": ["user:read:chat", "user:write:chat", "user:read:follows"]])
            }
            if request.url!.path.hasSuffix("/chat/messages") {
                if let sendGate, sendGate.wait(timeout: .now() + 4) == .timedOut { return (504, [:]) }
                if let sendStatus { return (sendStatus, [:]) }
                return (200, ["data": [["message_id": "sent", "is_sent": isSent, "drop_reason": ["code": "automod_held", "message": "Held by AutoMod"]]]])
            }
            subscriptions?.increment()
            return (202, ["data": [["id": "subscription"]]])
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubTwitchProtocol.self]
        let http = TwitchHTTP(session: URLSession(configuration: config))
        let store = MemoryCredentialStore()
        store.value = TwitchCredentials(clientId: "test-client", accessToken: "access", refreshToken: "refresh", expiresAt: .now.addingTimeInterval(3600), userId: "viewer", login: "viewer", scopes: TwitchAuth.requestedScopes)
        let auth = TwitchAuth(clientId: "test-client", store: store, http: http)
        await auth.restore()
        let api = TwitchAPI(auth: auth, http: http)
        var remaining = sockets
        let session = ChatSession(api: api, makeSocket: { _ in remaining.removeFirst() }, now: now, watchdogInterval: .milliseconds(20), migrationTimeout: migrationTimeout)
        session.start(broadcasterId: "channel")
        try await waitUntil { session.connection == .connected }
        return session
    }

    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { XCTFail("Condition did not become true"); throw TestTimeout.expired }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private enum TestTimeout: Error { case expired }

@MainActor
private final class FakeChatSocket: ChatSocket {
    var resumed = false
    var cancelled = false
    private var queue: [Data] = []
    private var receiver: CheckedContinuation<Data, Error>?
    init(welcome: Bool = false) {
        if welcome { queue.append(frame(type: "session_welcome", payload: ["session": ["id": "session", "keepalive_timeout_seconds": 10]])) }
    }
    func resume() { resumed = true }
    func cancel() { cancelled = true; receiver?.resume(throwing: URLError(.cancelled)); receiver = nil }
    func push(_ data: Data) {
        if let receiver { self.receiver = nil; receiver.resume(returning: data) }
        else { queue.append(data) }
    }
    func receiveData() async throws -> Data {
        if cancelled { throw URLError(.cancelled) }
        if !queue.isEmpty { return queue.removeFirst() }
        return try await withCheckedThrowingContinuation { receiver = $0 }
    }
}

private func frame(type: String, id: String = UUID().uuidString, subscription: String? = nil, payload: [String: Any]) -> Data {
    var metadata = ["message_id": id, "message_type": type]
    if let subscription { metadata["subscription_type"] = subscription }
    return try! JSONSerialization.data(withJSONObject: ["metadata": metadata, "payload": payload])
}

private func chatNotification(id: String) -> Data {
    let event: [String: Any] = ["broadcaster_user_id": "channel", "chatter_user_id": "viewer", "chatter_user_name": "Viewer", "chatter_user_login": "viewer", "message_id": id, "message": ["text": "Hello", "fragments": [["type": "text", "text": "Hello"]]], "color": "#FFFFFF", "badges": []]
    return frame(type: "notification", id: id, subscription: "channel.chat.message", payload: ["event": event])
}
