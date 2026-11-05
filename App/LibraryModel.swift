import Observation
import Foundation

/// Each library owns its pagination and generation. A late search or old
/// account response cannot replace the results of a newer request.
@MainActor @Observable
final class LibraryModel {
    private(set) var streams: [TwitchStream] = []
    private(set) var channels: [TwitchChannel] = []
    private(set) var categories: [TwitchCategory] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var nextCursor: String?
    private var generation = UUID()
    private var key = ""
    private var loadedKey: String?

    func load(api: TwitchAPI, section: LibrarySection, query: String, category: TwitchCategory? = nil, more: Bool = false, refresh: Bool = true) async {
        let newKey = "\(api.auth.sessionId)|\(section.rawValue)|\(query)|\(category?.id ?? "")"
        if more { guard !isLoading, nextCursor != nil, key == newKey else { return } }
        else {
            if !refresh && loadedKey == newKey { return }
            loadedKey = nil
            generation = UUID()
            key = newKey
            streams = []; channels = []; categories = []; nextCursor = nil
        }
        let ticket = generation
        let cursor = more ? nextCursor : nil
        isLoading = true
        error = nil
        defer { if generation == ticket { isLoading = false } }
        do {
            if section == .categories && category == nil {
                let page = try await api.categories(query: query, cursor: cursor)
                try Task.checkCancellation()
                guard generation == ticket else { return }
                categories = Self.merging(categories, page.data)
                nextCursor = page.nextCursor
            } else if !query.isEmpty && category == nil {
                let page = try await api.searchChannels(query: query, cursor: cursor)
                try Task.checkCancellation()
                guard generation == ticket else { return }
                channels = Self.merging(channels, page.data)
                nextCursor = page.nextCursor
            } else {
                let page: HelixPage<TwitchStream>
                if section == .following && category == nil { page = try await api.followedStreams(cursor: cursor) }
                else { page = try await api.streams(category: category?.id, cursor: cursor) }
                try Task.checkCancellation()
                guard generation == ticket else { return }
                streams = Self.merging(streams, page.data)
                nextCursor = page.nextCursor
            }
            if generation == ticket { loadedKey = newKey }
        } catch is CancellationError { }
        catch { if generation == ticket { self.error = error.localizedDescription } }
    }

    var isEmpty: Bool { streams.isEmpty && channels.isEmpty && categories.isEmpty }

    private static func merging<T: Identifiable>(_ old: [T], _ new: [T]) -> [T] {
        var ids = Set(old.map(\.id))
        return old + new.filter { ids.insert($0.id).inserted }
    }
}
