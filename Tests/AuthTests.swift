import XCTest
@testable import DuoTwitch

@MainActor
final class AuthTests: XCTestCase {
    func testRealKeychainReadIsAvailableToTheApp() {
        // Read only: exercise the application's real signing/Keychain boundary
        // without clearing a saved session or printing credential contents.
        XCTAssertNoThrow(try KeychainCredentialStore().load())
    }

    private func makeAuth(store: MemoryCredentialStore, sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) -> TwitchAuth {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubTwitchProtocol.self]
        return TwitchAuth(clientId: "test-client", store: store, http: TwitchHTTP(session: URLSession(configuration: configuration)), authorizationSleep: sleep)
    }

    override func tearDown() { StubTwitchProtocol.install(nil); super.tearDown() }

    func testConcurrentRefreshRotatesTheCredentialRecordOnce() async throws {
        let store = MemoryCredentialStore()
        store.value = credentials()
        let counter = RequestCounter()
        StubTwitchProtocol.install { request in
            if request.url!.path.hasSuffix("/token") {
                counter.increment()
                return (200, ["access_token": "rotated-access", "refresh_token": "rotated-refresh", "expires_in": 3600, "scope": ["user:read:chat", "user:write:chat", "user:read:follows"]])
            }
            return (200, ["client_id": "test-client", "user_id": "user", "login": "viewer", "expires_in": 3600, "scopes": ["user:read:chat", "user:write:chat", "user:read:follows"]])
        }
        let auth = makeAuth(store: store)
        await auth.restore()
        XCTAssertEqual(auth.account?.id, "user")
        let tasks = (0..<12).map { _ in Task { try await auth.accessToken(forceRefresh: true) } }
        var tokens: [String] = []
        for task in tasks { tokens.append(try await task.value) }
        XCTAssertEqual(tokens.count, 12)
        XCTAssertTrue(tokens.allSatisfy { $0 == "rotated-access" })
        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(store.value?.refreshToken, "rotated-refresh")
        XCTAssertEqual(store.saveCount, 1)
    }

    func testSignOutCannotClaimSuccessWhenKeychainDeletionFails() async throws {
        let store = MemoryCredentialStore()
        store.value = credentials()
        StubTwitchProtocol.install { _ in
            (200, ["client_id": "test-client", "user_id": "user", "login": "viewer", "expires_in": 3600, "scopes": ["user:read:chat", "user:write:chat", "user:read:follows"]])
        }
        let auth = makeAuth(store: store)
        await auth.restore()
        store.failClear = true
        XCTAssertThrowsError(try auth.signOut())
        XCTAssertEqual(auth.account?.id, "user")
        XCTAssertNotNil(store.value)
    }

    func testRestoringWrongClientNeverExposesAnAccountOrSendsItsToken() async {
        let store = MemoryCredentialStore()
        store.value = credentials(client: "another-client")
        let counter = RequestCounter()
        StubTwitchProtocol.install { _ in counter.increment(); return (500, [:]) }
        let auth = makeAuth(store: store)
        await auth.restore()
        XCTAssertNil(auth.account)
        XCTAssertEqual(counter.count, 0)
    }

    func testFormEncodingPreservesRefreshTokenSpecialCharacters() {
        let result = String(data: TwitchHTTP.form(["refresh_token": "a+b&c= d/%"]), encoding: .utf8)
        XCTAssertEqual(result, "refresh_token=a%2Bb%26c%3D%20d%2F%25")
    }

    func testExpiredRefreshClearsSavedSessionAndFinishesRestore() async {
        let store = MemoryCredentialStore()
        store.value = credentials(expired: true)
        StubTwitchProtocol.install { _ in (400, ["message": "Invalid refresh token"]) }
        let auth = makeAuth(store: store)
        await auth.restore()
        XCTAssertNil(auth.account)
        XCTAssertNil(store.value)
        XCTAssertFalse(auth.isRestoring)
        XCTAssertNotNil(auth.errorMessage)
    }

    func testRefreshRotationSurvivesValidationFailureAndRetryUsesNewToken() async {
        let store = MemoryCredentialStore()
        store.value = credentials(expired: true)
        let refreshes = RequestCounter()
        StubTwitchProtocol.install { request in
            if request.url!.path.hasSuffix("/token") {
                refreshes.increment()
                return (200, ["access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 3600, "scope": ["user:read:chat", "user:write:chat", "user:read:follows"]])
            }
            return (500, [:])
        }
        let auth = makeAuth(store: store)
        await auth.restore()
        XCTAssertNil(auth.account)
        XCTAssertFalse(auth.isRestoring)
        XCTAssertEqual(store.value?.refreshToken, "new-refresh")
        XCTAssertEqual(store.saveCount, 1)
        auth.cancelSignIn()
        StubTwitchProtocol.install { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "OAuth new-access")
            return (200, ["client_id": "test-client", "user_id": "user", "login": "viewer", "expires_in": 3600, "scopes": ["user:read:chat", "user:write:chat", "user:read:follows"]])
        }
        await auth.maintainSession()
        XCTAssertEqual(auth.account?.id, "user")
        XCTAssertNil(auth.errorMessage)
        XCTAssertEqual(refreshes.count, 1)
    }

    func testTransientRestoreFailureCanRecoverWithoutRelaunching() async {
        let store = MemoryCredentialStore()
        store.value = credentials()
        StubTwitchProtocol.install { _ in (503, [:]) }
        let auth = makeAuth(store: store)
        await auth.restore()
        XCTAssertNil(auth.account)
        XCTAssertNotNil(store.value)
        StubTwitchProtocol.install { _ in
            (200, ["client_id": "test-client", "user_id": "user", "login": "viewer", "expires_in": 3600, "scopes": ["user:read:chat", "user:write:chat", "user:read:follows"]])
        }
        await auth.maintainSession()
        XCTAssertEqual(auth.account?.id, "user")
    }

    func testFailedSaveKeepsRotatedTokenUsableAndRetriesPersistence() async throws {
        let store = MemoryCredentialStore()
        store.value = credentials(expired: true)
        store.failSave = true
        installValidRefresh()
        let auth = makeAuth(store: store)
        await auth.restore()
        XCTAssertNotNil(auth.account)
        XCTAssertNotNil(auth.persistenceWarning)
        let token = try await auth.accessToken()
        XCTAssertEqual(token, "new-access")
        XCTAssertEqual(store.value?.refreshToken, "old-refresh")
        store.failSave = false
        await auth.maintainSession()
        XCTAssertEqual(store.value?.refreshToken, "new-refresh")
        XCTAssertNil(auth.persistenceWarning)
    }

    func testValidation401RefreshesInsteadOfDiscardingTheAccount() async {
        let store = MemoryCredentialStore()
        store.value = credentials()
        installValidRefresh(rejectOld: true)
        let auth = makeAuth(store: store)
        await auth.restore()
        XCTAssertEqual(auth.account?.id, "user")
        XCTAssertEqual(store.value?.refreshToken, "new-refresh")
    }

    func testLateValidation401CannotEraseASuccessfullyRotatedToken() async throws {
        let store = MemoryCredentialStore()
        store.value = credentials()
        let gate = DispatchSemaphore(value: 0)
        let oldValidation = RequestCounter()
        StubTwitchProtocol.install { request in
            if request.url!.path.hasSuffix("/token") {
                return (200, ["access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 3600, "scope": ["user:read:chat", "user:write:chat", "user:read:follows"]])
            }
            if request.value(forHTTPHeaderField: "Authorization") == "OAuth old-access" {
                oldValidation.increment()
                _ = gate.wait(timeout: .now() + 3)
                return (401, [:])
            }
            return (200, ["client_id": "test-client", "user_id": "user", "login": "viewer", "expires_in": 3600, "scopes": ["user:read:chat", "user:write:chat", "user:read:follows"]])
        }
        let auth = makeAuth(store: store)
        let restoring = Task { await auth.restore() }
        let deadline = Date().addingTimeInterval(2)
        while oldValidation.count == 0 {
            guard Date() < deadline else { gate.signal(); XCTFail("Validation never started"); return }
            try await Task.sleep(for: .milliseconds(10))
        }
        let token = try await auth.accessToken(forceRefresh: true)
        XCTAssertEqual(token, "new-access")
        gate.signal()
        await restoring.value
        XCTAssertEqual(auth.account?.id, "user")
        XCTAssertEqual(store.value?.refreshToken, "new-refresh")
    }

    func testSignOutDuringRefreshCannotRestoreCredentials() async throws {
        let store = MemoryCredentialStore()
        store.value = credentials()
        installValidRefresh()
        let auth = makeAuth(store: store)
        await auth.restore()
        let refresh = Task { try await auth.accessToken(forceRefresh: true) }
        await Task.yield()
        try auth.signOut()
        _ = try? await refresh.value
        XCTAssertNil(auth.account)
        XCTAssertNil(store.value)
        XCTAssertFalse(auth.isRestoring)
    }

    func testChat401RefreshesOnceBeforeRetryingTheRejectedRequest() async throws {
        let store = MemoryCredentialStore()
        store.value = credentials()
        let sends = RequestCounter()
        let refreshes = RequestCounter()
        StubTwitchProtocol.install { request in
            if request.url!.path.hasSuffix("/chat/messages") {
                sends.increment()
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access" { return (401, [:]) }
                return (200, ["data": [["is_sent": true, "message_id": "sent-once"]]])
            }
            if request.url!.path.hasSuffix("/token") {
                refreshes.increment()
                return (200, ["access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 3600, "scope": ["user:read:chat", "user:write:chat", "user:read:follows"]])
            }
            return (200, ["client_id": "test-client", "user_id": "user", "login": "viewer", "expires_in": 3600, "scopes": ["user:read:chat", "user:write:chat", "user:read:follows"]])
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubTwitchProtocol.self]
        let http = TwitchHTTP(session: URLSession(configuration: configuration))
        let auth = TwitchAuth(clientId: "test-client", store: store, http: http)
        await auth.restore()
        let result = try await TwitchAPI(auth: auth, http: http).sendChat(broadcasterId: "channel", message: "Hello")
        XCTAssertTrue(result.isSent)
        XCTAssertEqual(sends.count, 2, "The first HTTP 401 rejected the request without processing it")
        XCTAssertEqual(refreshes.count, 1)
        XCTAssertNotNil(auth.account)
    }

    func testDeviceAuthorizationSurvivesTemporaryErrorsAndHonorsSlowDown() async throws {
        let polls = RequestCounter()
        let store = MemoryCredentialStore()
        var sleeps: [Duration] = []
        let scopes = TwitchAuth.requestedScopes
        StubTwitchProtocol.install { request in
            if request.url!.path.hasSuffix("/device") {
                return (200, ["device_code": "private-device-fixture", "user_code": "ABCD", "verification_uri": "https://www.twitch.tv/activate", "expires_in": 600, "interval": 2])
            }
            if request.url!.path.hasSuffix("/token") {
                let step = polls.count
                polls.increment()
                switch step {
                case 0: throw URLError(.networkConnectionLost)
                case 1: return (503, [:])
                case 2: return (400, ["error": "authorization_pending"])
                case 3: return (400, ["error": "slow_down"])
                default: return (200, ["access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 3600, "scope": scopes])
                }
            }
            return (200, ["client_id": "test-client", "user_id": "user", "login": "viewer", "expires_in": 3600, "scopes": scopes])
        }
        let auth = makeAuth(store: store, sleep: { duration in sleeps.append(duration); await Task.yield() })
        auth.beginSignIn()
        try await waitUntil { !auth.isAuthorizing }
        XCTAssertEqual(auth.account?.id, "user")
        XCTAssertEqual(store.value?.refreshToken, "new-refresh")
        XCTAssertEqual(polls.count, 5)
        XCTAssertEqual(sleeps, [.seconds(2), .seconds(2), .seconds(2), .seconds(2), .seconds(7)])
        XCTAssertNil(auth.errorMessage)
        XCTAssertNil(auth.challenge)
    }

    func testDeviceAuthorizationDeclineAndExpiryAreFinal() async throws {
        for (code, expected) in [("access_denied", TwitchError.authorizationDeclined), ("expired_token", .authorizationExpired)] {
            let store = MemoryCredentialStore()
            StubTwitchProtocol.install { request in
                if request.url!.path.hasSuffix("/device") {
                    return (200, ["device_code": "private-device-fixture", "user_code": "ABCD", "verification_uri": "https://www.twitch.tv/activate", "expires_in": 600, "interval": 1])
                }
                return (400, ["error": code])
            }
            let auth = makeAuth(store: store, sleep: { _ in await Task.yield() })
            auth.beginSignIn()
            try await waitUntil { !auth.isAuthorizing }
            XCTAssertNil(auth.account)
            XCTAssertNil(store.value)
            XCTAssertEqual(auth.errorMessage, expected.localizedDescription)
            XCTAssertNil(auth.challenge)
        }
    }

    func testCancellingDeviceAuthorizationPreventsFurtherPollingAndPersistence() async throws {
        let polls = RequestCounter()
        var sleeping: CheckedContinuation<Void, Never>?
        StubTwitchProtocol.install { request in
            if request.url!.path.hasSuffix("/device") {
                return (200, ["device_code": "private-device-fixture", "user_code": "ABCD", "verification_uri": "https://www.twitch.tv/activate", "expires_in": 600, "interval": 1])
            }
            polls.increment()
            return (400, ["error": "authorization_pending"])
        }
        let store = MemoryCredentialStore()
        let auth = makeAuth(store: store, sleep: { _ in await withCheckedContinuation { sleeping = $0 } })
        auth.beginSignIn()
        try await waitUntil { sleeping != nil }
        let cancelled = auth.cancelSignIn()
        sleeping?.resume()
        await cancelled?.value
        XCTAssertFalse(auth.isAuthorizing)
        XCTAssertNil(auth.account)
        XCTAssertNil(auth.challenge)
        XCTAssertNil(store.value)
        XCTAssertEqual(polls.count, 0)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(4)
        while !condition() {
            if Date() > deadline { XCTFail("Authorization did not settle"); throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func installValidRefresh(rejectOld: Bool = false) {
        StubTwitchProtocol.install { request in
            if request.url!.path.hasSuffix("/token") {
                return (200, ["access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 3600, "scope": ["user:read:chat", "user:write:chat", "user:read:follows"]])
            }
            if rejectOld && request.value(forHTTPHeaderField: "Authorization") == "OAuth old-access" { return (401, [:]) }
            return (200, ["client_id": "test-client", "user_id": "user", "login": "viewer", "expires_in": 3600, "scopes": ["user:read:chat", "user:write:chat", "user:read:follows"]])
        }
    }

    private func credentials(client: String = "test-client", expired: Bool = false) -> TwitchCredentials {
        TwitchCredentials(clientId: client, accessToken: "old-access", refreshToken: "old-refresh", expiresAt: .now.addingTimeInterval(expired ? -1 : 3600), userId: "user", login: "viewer", scopes: TwitchAuth.requestedScopes)
    }
}

final class MemoryCredentialStore: CredentialStoring {
    var value: TwitchCredentials?
    var saveCount = 0
    var failClear = false
    var failSave = false
    func load() throws -> TwitchCredentials? { value }
    func save(_ credentials: TwitchCredentials) throws { if failSave { throw TwitchError.keychain }; value = credentials; saveCount += 1 }
    func clear() throws { if failClear { throw TwitchError.keychain }; value = nil }
}

final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func increment() { lock.lock(); value += 1; lock.unlock() }
}

final class StubTwitchProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, [String: Any])
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    private let stateLock = NSLock()
    private var cancelled = false
    static func install(_ value: Handler?) { lock.lock(); handler = value; lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let responder = Self.handler
        Self.lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.06) { [self] in
            stateLock.lock()
            defer { stateLock.unlock() }
            guard !cancelled, let responder else { return }
            do {
                let (status, body) = try responder(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: body))
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() { stateLock.lock(); cancelled = true; stateLock.unlock() }
}
