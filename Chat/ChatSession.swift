import Foundation
import Observation

enum ChatConnection: Equatable {
    case signedOut, connecting, connected, reconnecting, paused, failed(String)
    var title: String {
        switch self {
        case .signedOut: "Sign in to join chat"
        case .connecting: "Connecting to chat…"
        case .connected: "Live chat"
        case .reconnecting: "Reconnecting to chat…"
        case .paused: "Chat paused in the background"
        case .failed(let message): message
        }
    }
}

@MainActor @Observable
final class ChatSession {
    private(set) var messages: [ChatMessage] = []
    private(set) var connection: ChatConnection = .signedOut
    private(set) var gapNotice: String?
    private var pendingSends: [String: UUID] = [:]
    @ObservationIgnored private var pendingSendAccount: UUID?
    var isSending: Bool { broadcasterId.flatMap { pendingSends[$0] } != nil }
    private(set) var sendError: String?
    var draft = ""
    var replyingTo: ChatMessage?
    @ObservationIgnored var onSendResult: (@MainActor (UUID, String, String, String?) -> Void)?
    @ObservationIgnored private let api: TwitchAPI
    @ObservationIgnored private let makeSocket: @MainActor (URL) -> any ChatSocket
    @ObservationIgnored private var buffer = ChatBuffer()
    @ObservationIgnored private var broadcasterId: String?
    @ObservationIgnored private var accountSession: UUID?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var socket: (any ChatSocket)?
    @ObservationIgnored private var pendingSocket: (any ChatSocket)?
    @ObservationIgnored private var drainingSocket: (any ChatSocket)?
    @ObservationIgnored private var drainTask: Task<Void, Never>?
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let watchdogInterval: Duration
    @ObservationIgnored private let migrationTimeout: Duration
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    @ObservationIgnored private var connectTask: Task<Void, Never>?
    @ObservationIgnored private var migrationTask: Task<Void, Never>?
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var lastReceipt = Date.distantPast
    @ObservationIgnored private var keepalive: TimeInterval = 15
    @ObservationIgnored private var retryCount = 0
    @ObservationIgnored private var receivedEvents: [String] = []
    @ObservationIgnored private var receivedEventSet: Set<String> = []
    @ObservationIgnored private var suspended = false
    @ObservationIgnored private var sendTransaction = UUID()

    init(api: TwitchAPI, makeSocket: @escaping @MainActor (URL) -> any ChatSocket = { URLSessionChatSocket(url: $0) },
         now: @escaping @MainActor () -> Date = { .now }, watchdogInterval: Duration = .seconds(2), migrationTimeout: Duration = .seconds(25)) {
        self.api = api
        self.makeSocket = makeSocket
        self.now = now
        self.watchdogInterval = watchdogInterval
        self.migrationTimeout = migrationTimeout
    }

    func start(broadcasterId: String) {
        guard api.auth.account != nil else { stop(clear: true); connection = .signedOut; return }
        if self.broadcasterId == broadcasterId && accountSession == api.auth.sessionId && socket != nil { return }
        stop(clear: self.broadcasterId != broadcasterId || accountSession != api.auth.sessionId)
        self.broadcasterId = broadcasterId
        accountSession = api.auth.sessionId
        suspended = false
        connection = .connecting
        scheduleConnection(after: 0)
    }

    func stop(clear: Bool = false) {
        generation = UUID()
        connectTask?.cancel(); connectTask = nil
        receiveTask?.cancel(); receiveTask = nil
        migrationTask?.cancel(); migrationTask = nil
        watchdog?.cancel(); watchdog = nil
        flushTask?.cancel(); flushTask = nil
        socket?.cancel(); socket = nil
        pendingSocket?.cancel(); pendingSocket = nil
        drainingSocket?.cancel(); drainingSocket = nil
        drainTask?.cancel(); drainTask = nil
        retryCount = 0
        if clear {
            sendTransaction = UUID()
            if pendingSendAccount != api.auth.sessionId {
                pendingSends.removeAll()
                pendingSendAccount = nil
            }
            broadcasterId = nil
            accountSession = nil
            connection = .signedOut
            buffer.clear(); messages = []; draft = ""; replyingTo = nil
            receivedEvents = []; receivedEventSet = []; gapNotice = nil; sendError = nil
        }
    }

    func suspend() {
        guard broadcasterId != nil, !suspended else { return }
        suspended = true
        stop()
        messages = buffer.messages
        connection = .paused
    }

    @discardableResult
    func resume() -> Bool {
        guard suspended, let broadcasterId, api.auth.account != nil else { return false }
        suspended = false
        gapNotice = "Chat resumed. Messages sent while you were away may be missing."
        start(broadcasterId: broadcasterId)
        return true
    }

    func retry() {
        guard let broadcasterId else { return }
        start(broadcasterId: broadcasterId)
    }

    func dismissGapNotice() { gapNotice = nil }

    func sendDraft() async {
        guard !isSending, let broadcasterId else { return }
        let text = draft
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard text.count <= 500 else { sendError = "Messages can contain up to 500 characters."; return }
        let identity = accountSession
        let transaction = UUID()
        sendTransaction = transaction
        let reply = replyingTo?.id
        pendingSendAccount = identity
        pendingSends[broadcasterId] = transaction
        sendError = nil
        defer { if pendingSends[broadcasterId] == transaction { pendingSends[broadcasterId] = nil } }
        do {
            let outcome = try await api.sendChat(broadcasterId: broadcasterId, message: text, replyTo: reply)
            let rejection = outcome.isSent ? nil : outcome.dropReason?.message ?? "Twitch did not send your message. Your draft is saved."
            if let identity, api.auth.sessionId == identity { onSendResult?(identity, broadcasterId, text, rejection) }
            guard sendTransaction == transaction, accountSession == identity, self.broadcasterId == broadcasterId else { return }
            guard outcome.isSent else {
                sendError = outcome.dropReason?.message ?? "Twitch did not send your message. Your draft is saved."
                return
            }
            // The EventSub echo owns insertion. The acknowledgement must never
            // add a duplicate or erase text typed while the request was running.
            if draft == text { draft = "" }
            if replyingTo?.id == reply { replyingTo = nil }
        } catch is CancellationError { }
        catch {
            let message: String
            switch error as? TwitchError {
            case .some(.unauthorized), .some(.signInRequired), .some(.permissionDenied), .some(.missingScopes), .some(.rateLimited), .some(.messageNotSent):
                message = error.localizedDescription
            default:
                message = "Twitch did not confirm delivery. Check chat before sending again. Your draft is saved."
            }
            if let identity, api.auth.sessionId == identity { onSendResult?(identity, broadcasterId, text, message) }
            guard sendTransaction == transaction, accountSession == identity, self.broadcasterId == broadcasterId else { return }
            sendError = message
        }
    }

    func reconcileDraft(sentText: String, error: String?) {
        if error == nil && draft == sentText { draft = "" }
        sendError = error
    }

    func restoreDraft(_ text: String, sendError: String?) {
        draft = text
        self.sendError = sendError
    }

    private func scheduleConnection(after delay: TimeInterval) {
        guard !suspended, api.auth.account != nil, connectTask == nil else { return }
        let ticket = generation
        connectTask = Task { [weak self] in
            guard let self else { return }
            do {
                if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                guard self.generation == ticket else { return }
                let new = self.makeSocket( URL(string: "wss://eventsub.wss.twitch.tv/ws")!)
                self.socket = new
                self.lastReceipt = self.now()
                self.keepalive = 10
                new.resume()
                self.beginWatchdog(ticket: ticket)
                let welcomeData = try await self.receive(new)
                let welcome = try TwitchHTTP.decode(EventSubFrame.self, from: welcomeData)
                guard welcome.metadata.messageType == "session_welcome", let session = welcome.payload.session else { throw TwitchError.invalidResponse }
                guard self.generation == ticket, self.api.auth.sessionId == self.accountSession else { new.cancel(); return }
                self.keepalive = TimeInterval(max(5, session.keepaliveTimeoutSeconds ?? 10))
                self.lastReceipt = self.now()
                guard let broadcasterId = self.broadcasterId else { new.cancel(); return }
                // Consume keepalives while subscription HTTP requests run.
                // Otherwise a slow subscription could falsely time out a
                // healthy socket before the receive loop even starts.
                self.beginReceiving(new, ticket: ticket)
                for type in ["channel.chat.message", "channel.chat.message_delete", "channel.chat.clear", "channel.chat.clear_user_messages"] {
                    try await self.api.subscribe(type: type, broadcasterId: broadcasterId, sessionId: session.id)
                    guard self.generation == ticket else { new.cancel(); return }
                }
                self.connectTask = nil
                self.retryCount = 0
                self.connection = .connected
            } catch is CancellationError { }
            catch {
                guard self.generation == ticket else { return }
                self.connectTask = nil
                self.connectionFailed(error)
            }
        }
    }

    private func beginReceiving(_ active: any ChatSocket, ticket: UUID) {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            do {
                while self.generation == ticket {
                    let data = try await self.receive(active)
                    guard self.generation == ticket else { return }
                    if self.socket === active { self.lastReceipt = self.now() }
                    guard let frame = try? TwitchHTTP.decode(EventSubFrame.self, from: data) else { continue }
                    switch frame.metadata.messageType {
                    case "session_keepalive": break
                    case "session_reconnect":
                        guard self.socket === active else { continue }
                        guard let value = frame.payload.session?.reconnectUrl, let url = EventSubFrame.validReconnectURL(value) else { throw TwitchError.invalidResponse }
                        self.migrate(to: url, from: active, ticket: ticket)
                    case "revocation":
                        self.stop()
                        self.connection = .failed("Twitch revoked chat access. Sign in again to rejoin.")
                        return
                    case "notification": try? self.apply(frame: frame, data: data)
                    default: break
                    }
                }
            } catch is CancellationError { }
            catch {
                guard self.generation == ticket, self.socket === active else { return }
                self.connectionFailed(error)
            }
        }
    }

    private func migrate(to url: URL, from previous: any ChatSocket, ticket: UUID) {
        guard migrationTask == nil else { return }
        migrationTask = Task { [weak self] in
            guard let self else { return }
            let replacement = self.makeSocket( url)
            self.pendingSocket = replacement
            replacement.resume()
            // The old receive loop stays active until the new socket welcomes
            // us. The existing subscriptions transfer; do not recreate them.
            let timeout = Task {
                try? await Task.sleep(for: self.migrationTimeout)
                if !Task.isCancelled { replacement.cancel() }
            }
            defer { timeout.cancel() }
            do {
                let data = try await self.receive(replacement)
                let frame = try TwitchHTTP.decode(EventSubFrame.self, from: data)
                guard frame.metadata.messageType == "session_welcome", let session = frame.payload.session else { throw TwitchError.invalidResponse }
                guard self.generation == ticket, self.socket === previous else { replacement.cancel(); return }
                self.keepalive = TimeInterval(max(5, session.keepaliveTimeoutSeconds ?? 10))
                self.lastReceipt = self.now()
                self.socket = replacement
                self.pendingSocket = nil
                self.migrationTask = nil
                self.beginReceiving(replacement, ticket: ticket)
                // Keep reading the old socket briefly after welcome so queued
                // notifications drain through the same dedupe path.
                self.drainingSocket?.cancel()
                self.drainTask?.cancel()
                self.drainingSocket = previous
                self.drainTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                    guard let self, self.generation == ticket, self.drainingSocket === previous else { return }
                    previous.cancel()
                    self.drainingSocket = nil
                    self.drainTask = nil
                }
            } catch {
                replacement.cancel()
                guard self.generation == ticket, self.socket === previous else { return }
                self.migrationTask = nil
                self.connectionFailed(error)
            }
        }
    }

    private func beginWatchdog(ticket: UUID) {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: self?.watchdogInterval ?? .seconds(2)) } catch { return }
                guard let self, self.generation == ticket else { return }
                if self.now().timeIntervalSince(self.lastReceipt) > self.keepalive + 5 {
                    self.socket?.cancel()
                    return
                }
            }
        }
    }

    private func connectionFailed(_ error: Error) {
        generation = UUID()
        connectTask?.cancel(); connectTask = nil
        flushTask?.cancel(); flushTask = nil
        messages = buffer.messages
        socket?.cancel(); socket = nil
        pendingSocket?.cancel(); pendingSocket = nil
        drainingSocket?.cancel(); drainingSocket = nil
        drainTask?.cancel(); drainTask = nil
        watchdog?.cancel(); watchdog = nil
        receiveTask?.cancel(); receiveTask = nil
        migrationTask?.cancel(); migrationTask = nil
        guard !suspended else { return }
        if error as? TwitchError == .unauthorized || error as? TwitchError == .permissionDenied || error as? TwitchError == .signInRequired || error as? TwitchError == .missingScopes {
            connection = .failed(error.localizedDescription)
            return
        }
        gapNotice = "Connection interrupted. Some messages may be missing."
        connection = .reconnecting
        retryCount += 1
        let backoff = min(30, pow(2, Double(min(retryCount, 5))))
        if case TwitchError.rateLimited(let until) = error {
            scheduleConnection(after: max(backoff, until.timeIntervalSince(now())))
        } else { scheduleConnection(after: backoff) }
    }

    private func receive(_ task: any ChatSocket) async throws -> Data {
        try await task.receiveData()
    }

    private func apply(frame: EventSubFrame, data: Data) throws {
        let id = frame.metadata.messageId
        guard !receivedEventSet.contains(id) else { return }
        let eventData = try EventSubFrame.eventData(from: data)
        switch frame.metadata.subscriptionType ?? frame.payload.subscription?.type {
        case "channel.chat.message":
            let event = try TwitchHTTP.decode(ChatEvent.self, from: eventData)
            guard event.broadcasterUserId == broadcasterId else { return }
            buffer.append(ChatMessage(event: event))
        case "channel.chat.message_delete":
            struct Delete: Decodable { let messageId: String }
            buffer.delete(id: try TwitchHTTP.decode(Delete.self, from: eventData).messageId)
        case "channel.chat.clear": buffer.clear()
        case "channel.chat.clear_user_messages":
            struct ClearUser: Decodable { let targetUserId: String }
            buffer.clear(userId: try TwitchHTTP.decode(ClearUser.self, from: eventData).targetUserId)
        default: return
        }
        receivedEventSet.insert(id)
        receivedEvents.append(id)
        if receivedEvents.count > 1_000 { receivedEventSet.remove(receivedEvents.removeFirst()) }
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        let ticket = generation
        flushTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
            guard let self, self.generation == ticket else { return }
            self.messages = self.buffer.messages
            self.flushTask = nil
        }
    }
}
