import Observation
import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case live = "Live", following = "Following", categories = "Categories"
    var id: Self { self }
    var symbol: String {
        switch self { case .live: "dot.radiowaves.left.and.right"; case .following: "heart"; case .categories: "square.grid.2x2" }
    }
}

enum WatchMode: String, CaseIterable, Identifiable {
    case balanced = "Video & chat", slim = "Slim chat", video = "Full video"
    var id: Self { self }
    var symbol: String {
        switch self { case .balanced: "rectangle.split.2x1"; case .slim: "sidebar.right"; case .video: "arrow.up.left.and.arrow.down.right" }
    }
}

@MainActor @Observable
final class AppModel {
    let auth: TwitchAuth
    let api: TwitchAPI
    let player: PlaybackSession
    let chat: ChatSession
    var selectedChannel: WatchedChannel?
    private(set) var isWatching = false
    var accountPresented = false
    var notice: String?
    private var drafts: [String: String] = [:]
    private var draftErrors: [String: String] = [:]
    private var watchAppearance: UUID?

    init(auth: TwitchAuth? = nil, http: TwitchHTTP? = nil, player: PlaybackSession? = nil, chat: ChatSession? = nil) {
        let auth = auth ?? TwitchAuth()
        let api = TwitchAPI(auth: auth, http: http)
        self.auth = auth
        self.api = api
        self.player = player ?? PlaybackSession()
        self.chat = chat ?? ChatSession(api: api)
        self.chat.onSendResult = { [weak self] account, channel, text, error in
            guard let self, self.auth.sessionId == account else { return }
            if self.selectedChannel?.id == channel {
                self.chat.reconcileDraft(sentText: text, error: error)
            }
            if error == nil && self.drafts[channel] == text { self.drafts[channel] = "" }
            self.draftErrors[channel] = error
        }
    }

    @discardableResult
    func watch(_ channel: WatchedChannel, appearance: UUID = UUID()) -> UUID {
        watchAppearance = appearance
        isWatching = true
        let changed = selectedChannel?.id != channel.id
        if changed {
            if let previous = selectedChannel { drafts[previous.id] = chat.draft; draftErrors[previous.id] = chat.sendError }
            chat.stop(clear: true)
            selectedChannel = channel
        }
        if auth.account != nil {
            if changed || !chat.resume() { chat.start(broadcasterId: channel.id) }
        }
        if changed { chat.restoreDraft(drafts[channel.id] ?? "", sendError: draftErrors[channel.id]) }
        return appearance
    }

    func accountChanged() {
        chat.stop(clear: true)
        drafts.removeAll()
        draftErrors.removeAll()
        if isWatching, let selectedChannel, auth.account != nil { chat.start(broadcasterId: selectedChannel.id) }
    }

    func leaveWatch(_ channel: WatchedChannel, appearance: UUID) {
        guard selectedChannel?.id == channel.id, watchAppearance == appearance else { return }
        watchAppearance = nil
        isWatching = false
        drafts[channel.id] = chat.draft
        draftErrors[channel.id] = chat.sendError
        chat.suspend()
        player.hideVideo()
    }
}

enum AppTheme {
    static let background = Color(red: 0.055, green: 0.055, blue: 0.075)
    static let surface = Color(red: 0.095, green: 0.095, blue: 0.125)
    static let accent = Color(red: 1, green: 0.40, blue: 0.32)
}
