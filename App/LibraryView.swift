import SwiftUI

struct LibraryView: View {
    @Bindable var app: AppModel
    let section: LibrarySection
    var category: TwitchCategory?
    @State private var model = LibraryModel()
    @State private var query = ""
    private var title: String { category?.name ?? section.rawValue }
    private var requestKey: String { "\(app.auth.sessionId)|\(app.auth.account?.id ?? "")|\(section)|\(category?.id ?? "")|\(query)" }

    var body: some View {
        Group {
            if app.auth.isRestoring {
                ProgressView("Restoring your account…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if app.auth.account == nil {
                welcome
            } else {
                results
            }
        }
        .background(AppTheme.background)
        .navigationTitle(title)
        .modifier(LibrarySearch(query: $query, enabled: category == nil && app.auth.account != nil,
            prompt: section == .categories ? "Search categories" : "Search channels"))
        .task(id: requestKey) {
            guard app.auth.account != nil else { return }
            do { try await Task.sleep(for: .milliseconds(query.isEmpty ? 0 : 300)) } catch { return }
            await reload(force: false)
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: "rectangle.split.2x1.fill")
                    .font(.system(size: 64, weight: .light)).foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your stream.\nYour space.").font(.largeTitle.bold())
                    Text("Live video and native chat, with room for both.")
                        .font(.title3).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    Label("Discover live channels and categories", systemImage: "dot.radiowaves.left.and.right")
                    Label("Keep chat beside the action", systemImage: "rectangle.split.2x1")
                    Label("Adapt your view as your iPhone unfolds", systemImage: "rectangle.expand.diagonal")
                }
                Button { app.accountPresented = true } label: {
                    Text("Connect to Twitch").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 8)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                Text("Sign in to browse Twitch and join chat. DuoTwitch is an independent viewer.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let error = app.auth.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.orange)
                }
            }
            .padding(28).frame(maxWidth: 540, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !model.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(query.isEmpty ? (section == .following ? "Your people, live now" : category == nil ? "Find your next watch" : "Live in \(title)") : "Search results")
                            .font(.title2.bold())
                        Text(query.isEmpty ? (section == .categories ? "Explore a world of live communities." : "Drop in. Find your community.") : "\(section == .categories ? "Categories" : "Channels") matching “\(query)”")
                            .foregroundStyle(.secondary).font(.subheadline)
                    }.padding(.top, 8)
                }
                if !model.categories.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 16)], spacing: 24) {
                        ForEach(model.categories) { category in
                            NavigationLink(value: category) { CategoryCard(category: category) }.buttonStyle(.plain)
                        }
                    }
                }
                if !model.streams.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 540), spacing: 20)], spacing: 26) {
                        ForEach(model.streams) { stream in
                            NavigationLink(value: WatchedChannel(stream: stream)) { StreamCard(stream: stream) }.buttonStyle(.plain)
                        }
                    }
                }
                ForEach(model.channels) { channel in
                    NavigationLink(value: WatchedChannel(channel: channel)) { ChannelRow(channel: channel) }.buttonStyle(.plain)
                }
                if model.isLoading { ProgressView().frame(maxWidth: .infinity).padding(40).accessibilityLabel("Loading Twitch") }
                if let error = model.error {
                    ContentUnavailableView {
                        Label("Couldn’t load Twitch", systemImage: "wifi.exclamationmark")
                    } description: { Text(error) } actions: {
                        Button("Try again") { Task { await reload() } }.buttonStyle(.bordered)
                    }
                } else if model.isEmpty && !model.isLoading {
                    ContentUnavailableView {
                        Label(query.isEmpty ? "No live channels" : "No results", systemImage: query.isEmpty ? "moon" : "magnifyingglass")
                    } description: {
                        Text(query.isEmpty ? "Check back soon, or explore another category." : "Try a different channel or category name.")
                    }
                }
                if model.nextCursor != nil {
                    Button("Load more") { Task { await model.load(api: app.api, section: section, query: query, category: category, more: true) } }
                        .buttonStyle(.bordered).disabled(model.isLoading).frame(maxWidth: .infinity)
                }
            }.padding(20)
        }.refreshable { await reload() }
    }

    private func reload(force: Bool = true) async { await model.load(api: app.api, section: section, query: query, category: category, refresh: force) }
}

private struct StreamCard: View {
    let stream: TwitchStream
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RemoteArtwork(url: stream.thumbnail, symbol: "play.rectangle")
                    .aspectRatio(16 / 9, contentMode: .fit).clipShape(.rect(cornerRadius: 14))
                Text("LIVE").font(.caption2.bold()).padding(.horizontal, 7).padding(.vertical, 4)
                    .background(.red, in: .rect(cornerRadius: 5)).padding(10)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.userName).font(.headline)
                Text(stream.title).font(.subheadline).lineLimit(2)
                HStack {
                    Text(stream.gameName).lineLimit(1)
                    Spacer(minLength: 4)
                    Label(stream.viewerCount.formatted(.number.notation(.compactName)), systemImage: "person.fill")
                }.font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

private struct CategoryCard: View {
    let category: TwitchCategory
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtwork(url: category.artwork, symbol: "square.grid.2x2")
                .aspectRatio(3 / 4, contentMode: .fit).clipShape(.rect(cornerRadius: 12))
            Text(category.name).font(.subheadline.weight(.semibold)).lineLimit(2)
        }.accessibilityElement(children: .combine)
    }
}

private struct ChannelRow: View {
    let channel: TwitchChannel
    var body: some View {
        HStack(spacing: 14) {
            RemoteArtwork(url: channel.avatar, symbol: "person.fill").frame(width: 56, height: 56).clipShape(.circle)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.displayName).font(.headline)
                    if channel.isLive { Text("LIVE").font(.caption2.bold()).foregroundStyle(.red) }
                }
                Text(channel.isLive ? channel.title : "Offline").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(.vertical, 6).accessibilityElement(children: .combine)
    }
}

struct RemoteArtwork: View {
    let url: URL?
    let symbol: String
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                ZStack { AppTheme.surface; Image(systemName: symbol).font(.largeTitle).foregroundStyle(.tertiary) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true)
    }
}

private struct LibrarySearch: ViewModifier {
    @Binding var query: String
    let enabled: Bool
    let prompt: String
    func body(content: Content) -> some View {
        if enabled { content.searchable(text: $query, prompt: Text(prompt)) }
        else { content }
    }
}
