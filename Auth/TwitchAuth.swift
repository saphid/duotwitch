import Foundation
import Observation

struct TwitchAccount: Equatable {
    let id: String
    let login: String
}

struct SignInChallenge: Identifiable {
    let id: UUID
    let userCode: String
    let verificationURL: URL
    let expiresAt: Date
    var includesCodeInURL: Bool {
        URLComponents(url: verificationURL, resolvingAgainstBaseURL: false)?.queryItems?
            .contains { $0.name == "device-code" && $0.value == userCode } == true
    }
}

private struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let expiresIn: Int
    let interval: Int
    let userCode: String
    let verificationUri: String
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let scope: [String]
}

private struct ValidationResponse: Decodable {
    let clientId: String
    let userId: String
    let login: String
    let scopes: [String]
    let expiresIn: Int
}

private struct OAuthProblem: Decodable {
    let error: String?
    let message: String?
    var code: String { error ?? message ?? "unknown" }
}

private struct RejectedCredential: Error {
    let token: String
    let reason: TwitchError
}

@MainActor @Observable
final class TwitchAuth {
    static let requestedScopes = ["user:read:chat", "user:write:chat", "user:read:follows"]
    let clientId: String
    private(set) var account: TwitchAccount?
    private(set) var challenge: SignInChallenge?
    private(set) var isRestoring = false
    private(set) var isAuthorizing = false
    private(set) var authorizationNotice: String?
    private(set) var errorMessage: String?
    private(set) var persistenceWarning: String?
    private(set) var canRetryRestore = false
    @ObservationIgnored private let store: any CredentialStoring
    @ObservationIgnored private let http: TwitchHTTP
    @ObservationIgnored private let authorizationNow: @MainActor () -> Date
    @ObservationIgnored private let authorizationSleep: @MainActor (Duration) async throws -> Void
    @ObservationIgnored private var credentials: TwitchCredentials?
    @ObservationIgnored private var lastValidated: Date?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var authorizationId = UUID()
    @ObservationIgnored private var pendingPersistence = false
    @ObservationIgnored private var authorizationTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<TwitchCredentials, Error>?
    @ObservationIgnored private var refreshId: UUID?

    init(clientId: String = Bundle.main.object(forInfoDictionaryKey: "TwitchClientID") as? String ?? "",
         store: any CredentialStoring = KeychainCredentialStore(), http: TwitchHTTP? = nil,
         authorizationNow: @escaping @MainActor () -> Date = { Date() },
         authorizationSleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.clientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.store = store
        self.http = http ?? TwitchHTTP()
        self.authorizationSleep = authorizationSleep
        self.authorizationNow = authorizationNow
    }

    var isConfigured: Bool { !clientId.isEmpty && !clientId.hasPrefix("$(") }
    var sessionId: UUID { generation }

    func restore() async {
        guard isConfigured, !isRestoring, !isAuthorizing, account == nil else { return }
        let ticket = generation
        isRestoring = true
        defer { if ticket == generation { isRestoring = false } }
        do {
            guard let saved = try credentials ?? store.load(), saved.clientId == clientId else { return }
            credentials = saved
            canRetryRestore = true
            _ = try await accessToken()
            guard ticket == generation, let current = credentials else { return }
            account = TwitchAccount(id: current.userId, login: current.login)
            errorMessage = nil
        } catch is CancellationError { }
        catch {
            guard ticket == generation else { return }
            errorMessage = error.localizedDescription
        }
    }

    func beginSignIn() {
        guard !isRestoring, refreshTask == nil, account == nil else { return }
        cancelSignIn()
        errorMessage = nil
        authorizationNotice = nil
        guard isConfigured else { errorMessage = TwitchError.notConfigured.localizedDescription; return }
        let ticket = authorizationId
        isAuthorizing = true
        authorizationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.authorizationId == ticket {
                    self.isAuthorizing = false
                    self.challenge = nil
                    self.authorizationNotice = nil
                    self.authorizationTask = nil
                }
            }
            do {
                let response = try await self.oauth(path: "device", fields: ["client_id": self.clientId, "scopes": Self.requestedScopes.joined(separator: " ")])
                try TwitchHTTP.requireSuccess(response.1)
                let code = try TwitchHTTP.decode(DeviceCodeResponse.self, from: response.0)
                guard let url = URL(string: code.verificationUri), Self.isTwitchAuthorizationURL(url),
                      code.expiresIn > 0, !code.deviceCode.isEmpty, !code.userCode.isEmpty else { throw TwitchError.invalidResponse }
                try Task.checkCancellation()
                guard self.authorizationId == ticket else { return }
                let deadline = self.authorizationNow().addingTimeInterval(TimeInterval(code.expiresIn))
                self.challenge = SignInChallenge(id: ticket, userCode: code.userCode, verificationURL: url, expiresAt: deadline)
                self.authorizationNotice = "Approve access on Twitch. We’ll finish connecting automatically."
                var interval = max(1, code.interval)
                while authorizationNow() < deadline {
                    try await self.authorizationSleep(.seconds(interval))
                    try Task.checkCancellation()
                    guard self.authorizationId == ticket else { return }
                    guard self.authorizationNow() < deadline else { throw TwitchError.authorizationExpired }
                    let result: (Data, HTTPURLResponse)
                    do { result = try await self.oauth(path: "token", fields: [
                        "client_id": self.clientId, "device_code": code.deviceCode,
                        "scopes": Self.requestedScopes.joined(separator: " "),
                        "grant_type": "urn:ietf:params:oauth:grant-type:device_code"]) }
                    catch let error as URLError where [.networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains(error.code) {
                        self.authorizationNotice = "Connection interrupted. Retrying your sign-in…"
                        continue // Authorization remains valid until its deadline.
                    }
                    if (500..<600).contains(result.1.statusCode) {
                        self.authorizationNotice = "Twitch is taking a moment. Your sign-in is still in progress."
                        continue
                    }
                    if result.1.statusCode == 429 { interval += 5; continue }
                    if (200..<300).contains(result.1.statusCode) {
                        let tokens = try TwitchHTTP.decode(TokenResponse.self, from: result.0)
                        self.authorizationNotice = "Twitch approved. Finishing your connection…"
                        let value = try await self.validateAuthorization(tokens)
                        try Task.checkCancellation()
                        guard self.authorizationId == ticket else { return }
                        self.credentials = value
                        self.pendingPersistence = true
                        self.persistPendingCredentials()
                        self.lastValidated = .now
                        self.generation = UUID()
                        self.account = TwitchAccount(id: value.userId, login: value.login)
                        return
                    }
                    let problem = try? TwitchHTTP.decode(OAuthProblem.self, from: result.0)
                    switch problem?.code {
                    case "authorization_pending": continue
                    case "slow_down": interval += 5
                    case "access_denied": throw TwitchError.authorizationDeclined
                    case "expired_token", "invalid device code": throw TwitchError.authorizationExpired
                    default: try TwitchHTTP.requireSuccess(result.1)
                    }
                }
                throw TwitchError.authorizationExpired
            } catch is CancellationError { }
            catch { if self.authorizationId == ticket { self.errorMessage = error.localizedDescription } }
        }
    }

    @discardableResult
    func cancelSignIn() -> Task<Void, Never>? {
        // Cancelling an authorization challenge must not throw away a refresh
        // pair the server has already rotated for the existing session.
        authorizationId = UUID()
        let cancelled = authorizationTask
        cancelled?.cancel()
        authorizationTask = nil
        challenge = nil
        authorizationNotice = nil
        isAuthorizing = false
        return cancelled
    }

    func signOut() throws {
        // If Keychain deletion fails, surface it; do not claim durable sign-out.
        try store.clear()
        let token = credentials?.accessToken
        cancelSignIn()
        generation = UUID()
        isRestoring = false
        refreshTask?.cancel()
        refreshTask = nil
        refreshId = nil
        credentials = nil
        pendingPersistence = false
        persistenceWarning = nil
        canRetryRestore = false
        account = nil
        lastValidated = nil
        errorMessage = nil
        if let token {
            Task { [http, clientId] in
                var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/revoke")!)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = TwitchHTTP.form(["client_id": clientId, "token": token])
                _ = try? await http.perform(request)
            }
        }
    }

    func accessToken(forceRefresh: Bool = false) async throws -> String {
        let ticket = generation
        do { return try await validAccessToken(forceRefresh: forceRefresh) }
        catch let rejection as RejectedCredential {
            guard generation == ticket else { throw CancellationError() }
            if credentials?.accessToken == rejection.token {
                expireSession(rejection.reason)
                throw rejection.reason
            }
            // A late response for an older token cannot revoke its replacement.
            return try await accessToken()
        }
    }

    private func persistPendingCredentials() {
        guard pendingPersistence, let credentials else { return }
        do {
            try store.save(credentials)
            pendingPersistence = false
            persistenceWarning = nil
        } catch {
            persistenceWarning = "Your session is active, but its updated sign-in could not be saved securely. Keep the app open and retry saving."
        }
    }

    private func validAccessToken(forceRefresh: Bool) async throws -> String {
        guard let current = credentials else { throw TwitchError.signInRequired }
        persistPendingCredentials()
        let ticket = generation
        if refreshTask != nil || forceRefresh || current.expiresAt.timeIntervalSinceNow < 90 {
            let task: Task<TwitchCredentials, Error>
            let transaction: UUID
            if let existing = refreshTask, let existingId = refreshId {
                task = existing
                transaction = existingId
            }
            else {
                transaction = UUID()
                task = Task { [self] in
                    let result = try await oauth(path: "token", fields: [
                        "client_id": clientId, "grant_type": "refresh_token", "refresh_token": current.refreshToken])
                    if result.1.statusCode == 400 || result.1.statusCode == 401 {
                        throw RejectedCredential(token: current.accessToken, reason: .unauthorized)
                    }
                    try TwitchHTTP.requireSuccess(result.1)
                    let tokens = try TwitchHTTP.decode(TokenResponse.self, from: result.0)
                    guard !tokens.accessToken.isEmpty, !tokens.refreshToken.isEmpty, tokens.expiresIn > 0 else { throw TwitchError.invalidResponse }
                    guard generation == ticket else { throw CancellationError() }
                    // The previous refresh token is now spent. Persist its
                    // replacement before any further network call can fail.
                    let value = TwitchCredentials(clientId: clientId, accessToken: tokens.accessToken,
                        refreshToken: tokens.refreshToken, expiresAt: .now.addingTimeInterval(TimeInterval(tokens.expiresIn)),
                        userId: current.userId, login: current.login, scopes: tokens.scope)
                    credentials = value
                    lastValidated = nil
                    pendingPersistence = true
                    persistPendingCredentials()
                    let validated: ValidationResponse
                    do { validated = try await validate(token: value.accessToken) }
                    catch TwitchError.unauthorized { throw RejectedCredential(token: value.accessToken, reason: .unauthorized) }
                    guard generation == ticket else { throw CancellationError() }
                    guard validated.clientId == clientId, validated.userId == current.userId else { throw RejectedCredential(token: value.accessToken, reason: .unauthorized) }
                    guard Set(Self.requestedScopes).isSubset(of: Set(validated.scopes)) else { throw RejectedCredential(token: value.accessToken, reason: .missingScopes) }
                    lastValidated = .now
                    return value
                }
                refreshTask = task
                refreshId = transaction
            }
            do {
                let refreshed = try await task.value
                guard generation == ticket else { throw CancellationError() }
                if refreshId == transaction { refreshTask = nil; refreshId = nil }
                return refreshed.accessToken
            } catch {
                if generation == ticket && refreshId == transaction { refreshTask = nil; refreshId = nil }
                throw error
            }
        }
        if lastValidated == nil || Date().timeIntervalSince(lastValidated!) >= 3_600 {
            let validation: ValidationResponse
            do { validation = try await validate(token: current.accessToken) }
            catch TwitchError.unauthorized {
                guard generation == ticket else { throw CancellationError() }
                return try await validAccessToken(forceRefresh: credentials?.accessToken == current.accessToken)
            }
            guard generation == ticket else { throw CancellationError() }
            if credentials?.accessToken != current.accessToken { return try await validAccessToken(forceRefresh: false) }
            guard validation.clientId == clientId, validation.userId == current.userId else { throw RejectedCredential(token: current.accessToken, reason: .unauthorized) }
            guard Set(Self.requestedScopes).isSubset(of: Set(validation.scopes)) else { throw RejectedCredential(token: current.accessToken, reason: .missingScopes) }
            lastValidated = .now
        }
        return current.accessToken
    }

    func validateIfNeeded() async {
        guard account != nil else { return }
        let ticket = generation
        do {
            _ = try await accessToken()
            if ticket == generation { errorMessage = nil }
        }
        catch is CancellationError { }
        catch { if ticket == generation { errorMessage = error.localizedDescription } }
    }

    func maintainSession() async {
        if account == nil { await restore() }
        else { await validateIfNeeded() }
    }

    private func expireSession(_ error: Error) {
        do { try store.clear(); errorMessage = error.localizedDescription }
        catch { errorMessage = "Your Twitch session has expired, but its saved credentials could not be removed. Try signing out again." }
        credentials = nil
        pendingPersistence = false
        persistenceWarning = nil
        canRetryRestore = false
        account = nil
        lastValidated = nil
        generation = UUID()
        isRestoring = false
        refreshTask?.cancel()
        refreshTask = nil
        refreshId = nil
    }

    static func isTwitchAuthorizationURL(_ url: URL) -> Bool {
        url.scheme == "https" && ["www.twitch.tv", "twitch.tv", "id.twitch.tv"].contains(url.host?.lowercased() ?? "") && url.user == nil && url.password == nil
    }

    private func oauth(path: String, fields: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/\(path)")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = TwitchHTTP.form(fields)
        return try await http.perform(request)
    }

    private func validate(token: String) async throws -> ValidationResponse {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/validate")!)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        let response = try await http.perform(request)
        try TwitchHTTP.requireSuccess(response.1)
        return try TwitchHTTP.decode(ValidationResponse.self, from: response.0)
    }

    private func validatedCredentials(_ tokens: TokenResponse) async throws -> TwitchCredentials {
        guard !tokens.accessToken.isEmpty, !tokens.refreshToken.isEmpty, tokens.expiresIn > 0 else { throw TwitchError.invalidResponse }
        let validated = try await validate(token: tokens.accessToken)
        guard validated.clientId == clientId, !validated.userId.isEmpty, !validated.login.isEmpty else { throw TwitchError.unauthorized }
        guard Set(Self.requestedScopes).isSubset(of: Set(validated.scopes)) else { throw TwitchError.missingScopes }
        return TwitchCredentials(clientId: clientId, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken,
                                 expiresAt: Date().addingTimeInterval(TimeInterval(min(tokens.expiresIn, validated.expiresIn))),
                                 userId: validated.userId, login: validated.login, scopes: validated.scopes)
    }

    /// The device code is consumed at exchange. Keep its returned tokens while
    /// retrying temporary validation failures instead of making people approve again.
    private func validateAuthorization(_ tokens: TokenResponse) async throws -> TwitchCredentials {
        // Approval consumed the challenge. Its expiry no longer limits token validation.
        let deadline = authorizationNow().addingTimeInterval(60)
        while authorizationNow() < deadline {
            do { return try await validatedCredentials(tokens) }
            catch let error as URLError where [.networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed].contains(error.code) {
                try await authorizationSleep(.seconds(2))
            } catch TwitchError.serviceUnavailable {
                try await authorizationSleep(.seconds(2))
            } catch TwitchError.rateLimited(let until) {
                try await authorizationSleep(.seconds(max(1, min(30, until.timeIntervalSinceNow))))
            }
            try Task.checkCancellation()
        }
        throw TwitchError.serviceUnavailable
    }
}
