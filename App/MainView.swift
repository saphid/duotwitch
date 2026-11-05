import SwiftUI

struct MainView: View {
    @Bindable var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var phase
    @State private var section: LibrarySection? = .live
    @State private var visibility: NavigationSplitViewVisibility = .all
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    @State private var libraryVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: $compactColumn) {
            List(selection: $section) {
                Section {
                    ForEach(LibrarySection.allCases) { item in
                        NavigationLink(value: item) { Label(item.rawValue, systemImage: item.symbol) }
                    }
                } header: {
                    Label("DuoTwitch", systemImage: "rectangle.split.2x1.fill")
                        .font(.title2.bold()).textCase(nil).padding(.vertical, 16)
                        .accessibilityElement(children: .ignore).accessibilityLabel("DuoTwitch")
                }
                Section {
                    Button { app.accountPresented = true } label: {
                        Label(app.auth.account?.login ?? "Sign in", systemImage: "person.crop.circle")
                    }
                }
            }
            .navigationTitle("Explore")
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            NavigationStack {
                LibraryView(app: app, section: section ?? .live)
                    .navigationDestination(for: WatchedChannel.self) { channel in
                        WatchView(app: app, channel: channel)
                    }
                    .navigationDestination(for: TwitchCategory.self) { category in
                        LibraryView(app: app, section: .live, category: category)
                    }
                    .toolbar {
                        if sizeClass == .regular && visibility != .detailOnly {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Hide sidebar", systemImage: "sidebar.leading") { visibility = .detailOnly }
                                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Account", systemImage: "person.crop.circle") { app.accountPresented = true }
                                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        }
                    }
            }
        }
        .sheet(isPresented: $app.accountPresented) { AccountView(app: app) }
        .task(id: phase) {
            guard phase == .active else { return }
            await app.auth.maintainSession()
            guard !Task.isCancelled else { return }
            if app.isWatching { app.chat.resume() }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                await app.auth.maintainSession()
            }
        }
        .onChange(of: app.auth.account) { _, _ in app.accountChanged() }
        .onChange(of: app.isWatching) { _, watching in
            if watching { libraryVisibility = visibility; visibility = .detailOnly }
            else { visibility = libraryVisibility }
        }
        .onChange(of: phase) { _, value in
            if value == .background { app.chat.suspend() }

        }
    }
}
