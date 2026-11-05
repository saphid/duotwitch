import Foundation

struct HelixPage<Value: Decodable>: Decodable {
    let data: [Value]
    let pagination: Pagination?
    struct Pagination: Decodable { let cursor: String? }
    var nextCursor: String? { pagination?.cursor }
}

struct TwitchStream: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String
    let userLogin: String
    let userName: String
    let gameId: String
    let gameName: String
    let title: String
    let viewerCount: Int
    let thumbnailUrl: String
    let isMature: Bool?
    var thumbnail: URL? { URL(string: thumbnailUrl.replacingOccurrences(of: "{width}", with: "640").replacingOccurrences(of: "{height}", with: "360")) }
}

struct TwitchCategory: Decodable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let boxArtUrl: String
    var artwork: URL? { URL(string: boxArtUrl.replacingOccurrences(of: "{width}", with: "285").replacingOccurrences(of: "{height}", with: "380")) }
}

struct TwitchChannel: Decodable, Identifiable, Equatable, Hashable {
    let id: String
    let broadcasterLogin: String
    let displayName: String
    let gameName: String
    let title: String
    let thumbnailUrl: String
    let isLive: Bool
    var avatar: URL? { URL(string: thumbnailUrl) }
}

struct TwitchUser: Decodable, Identifiable {
    let id: String
    let login: String
    let displayName: String
    let description: String
    let profileImageUrl: String
    let offlineImageUrl: String
}

struct WatchedChannel: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let login: String
    let name: String
    var title: String
    var category: String
    var avatarURL: URL?
    var viewers: Int?
    var isLive: Bool?

    init(stream: TwitchStream) {
        id = stream.userId; login = stream.userLogin; name = stream.userName
        title = stream.title; category = stream.gameName; viewers = stream.viewerCount
        isLive = true; avatarURL = nil
    }

    init(channel: TwitchChannel) {
        id = channel.id; login = channel.broadcasterLogin; name = channel.displayName
        title = channel.title; category = channel.gameName; avatarURL = channel.avatar
        isLive = channel.isLive; viewers = nil
    }

    init(user: TwitchUser) {
        id = user.id; login = user.login; name = user.displayName
        title = user.description; category = ""; avatarURL = URL(string: user.profileImageUrl)
        viewers = nil; isLive = nil
    }
}

struct ChatSendOutcome: Decodable {
    let messageId: String
    let isSent: Bool
    let dropReason: DropReason?
    struct DropReason: Decodable {
        let code: String
        let message: String
    }
}
