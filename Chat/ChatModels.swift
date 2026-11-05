import Foundation

struct ChatEvent: Decodable {
    let broadcasterUserId: String
    let chatterUserId: String
    let chatterUserName: String
    let chatterUserLogin: String
    let messageId: String
    let message: Message
    let color: String
    let badges: [Badge]
    let reply: Reply?
    let sourceBroadcasterUserName: String?

    struct Message: Decodable {
        let text: String
        let fragments: [Fragment]
    }
    struct Fragment: Decodable {
        let type: String
        let text: String
        let emote: Emote?
    }
    struct Emote: Decodable { let id: String; let format: [String]? }
    struct Badge: Decodable { let setId: String; let id: String; let info: String? }
    struct Reply: Decodable {
        let parentMessageId: String
        let parentUserName: String
        let parentMessageBody: String
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let userId: String
    let name: String
    let login: String
    let text: String
    let color: String
    let fragments: [Fragment]
    let badges: [String]
    let replyName: String?
    let replyText: String?
    let sourceChannel: String?

    struct Fragment: Equatable {
        let text: String
        let emoteId: String?
        let animated: Bool
        var emoteURL: URL? {
            guard let emoteId,
                  !emoteId.isEmpty,
                  emoteId.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 95 || $0 == 45 }) else { return nil }
            return URL(string: "https://static-cdn.jtvnw.net/emoticons/v2/\(emoteId)/\(animated ? "animated" : "static")/dark/2.0")
        }
    }

    init(event: ChatEvent) {
        id = event.messageId; userId = event.chatterUserId; name = event.chatterUserName
        login = event.chatterUserLogin; text = event.message.text; color = event.color
        fragments = event.message.fragments.map { Fragment(text: $0.text, emoteId: $0.emote?.id, animated: $0.emote?.format?.contains("animated") == true) }
        badges = event.badges.map(\.setId)
        replyName = event.reply?.parentUserName; replyText = event.reply?.parentMessageBody
        sourceChannel = event.sourceBroadcasterUserName
    }
}

/// Moderation changes are applied to the canonical buffer, including messages
/// waiting for the next UI batch. A deleted pending message cannot reappear.
struct ChatBuffer {
    let capacity: Int
    private(set) var messages: [ChatMessage] = []
    private var identifiers: Set<String> = []

    init(capacity: Int = 500) { self.capacity = max(1, capacity) }

    mutating func append(_ message: ChatMessage) {
        guard identifiers.insert(message.id).inserted else { return }
        messages.append(message)
        if messages.count > capacity {
            let excess = messages.count - capacity
            for old in messages.prefix(excess) { identifiers.remove(old.id) }
            messages.removeFirst(excess)
        }
    }

    mutating func delete(id: String) {
        messages.removeAll { $0.id == id }
        identifiers.remove(id)
    }

    mutating func clear(userId: String? = nil) {
        if let userId {
            let removed = messages.filter { $0.userId == userId }
            removed.forEach { identifiers.remove($0.id) }
            messages.removeAll { $0.userId == userId }
        } else {
            messages.removeAll(keepingCapacity: true)
            identifiers.removeAll(keepingCapacity: true)
        }
    }
}
