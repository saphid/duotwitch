import SwiftUI

struct NativeChatView: View {
    @Bindable var session: ChatSession
    let signedIn: Bool
    var composerVisible = true
    var onComposerFocusChange: (Bool) -> Void = { _ in }
    let signIn: () -> Void
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var atBottom = true
    @State private var showConnectionNotice = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Chat", systemImage: "bubble.left.and.bubble.right").font(.headline)
                Spacer()
                if let gap = session.gapNotice {
                    Button { showConnectionNotice = true } label: {
                        Image(systemName: "exclamationmark.bubble").foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel(gap)
                    .accessibilityHint("Shows connection details.")
                }
                if session.connection == .connected {
                    Circle().fill(.green).frame(width: 7, height: 7).accessibilityLabel("Connected")
                } else if signedIn {
                    Button("Reconnect chat", systemImage: "arrow.clockwise") { session.retry() }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }
            }.padding(.horizontal, 14).frame(minHeight: 48)
            Divider()
            if !signedIn {
                VStack(spacing: 12) {
                    Text("Sign in to join chat.").font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Sign in", action: signIn).buttonStyle(.bordered)
                }
                .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                timeline
                composer
            }
        }
        .background(AppTheme.background)
        .accessibilityIdentifier("nativeChat")
        .alert("Chat connection", isPresented: $showConnectionNotice) {
            Button("OK") { session.dismissGapNotice() }
        } message: {
            Text(session.gapNotice ?? "")
        }
        .onChange(of: composerFocused) { _, focused in onComposerFocusChange(focused) }
        .onChange(of: composerVisible) { _, visible in if !visible { composerFocused = false } }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if session.messages.isEmpty {
                            Text(session.connection == .connected ? "You’re connected. New messages will appear here." : session.connection.title)
                                .font(.callout).foregroundStyle(.secondary).padding(.vertical, 20)
                        }
                        ForEach(session.messages) { message in
                            ChatMessageRow(message: message)
                                .id(message.id)
                                .contextMenu {
                                    Button("Reply to \(message.name)", systemImage: "arrowshape.turn.up.left") {
                                        session.replyingTo = message
                                        composerFocused = true
                                    }
                                    Link("View profile in Twitch", destination: URL(string: "https://www.twitch.tv/\(message.login)")!)
                                }
                        }
                        Color.clear.frame(height: 1).id("latest")
                    }.padding(12)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.visibleRect.maxY >= geometry.contentSize.height - 60
                } action: { _, nearBottom in atBottom = nearBottom }
                .onChange(of: session.messages.last?.id) { _, _ in
                    if atBottom && !voiceOver { proxy.scrollTo("latest", anchor: .bottom) }
                }
                if !atBottom || voiceOver && !session.messages.isEmpty {
                    Button("Jump to latest", systemImage: "arrow.down") {
                        proxy.scrollTo("latest", anchor: .bottom)
                        atBottom = true
                    }.buttonStyle(.bordered).padding(8)
                }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reply = session.replyingTo {
                HStack {
                    Text("Replying to \(reply.name)").font(.caption).lineLimit(1)
                    Spacer(minLength: 4)
                    Button("Cancel reply", systemImage: "xmark") { session.replyingTo = nil }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }
            }
            if let error = session.sendError { Text(error).font(.caption).foregroundStyle(.orange) }
            if session.connection != .connected && !session.messages.isEmpty {
                Text(session.connection.title).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Send a message", text: $session.draft, axis: .vertical)
                    .lineLimit(1...4).focused($composerFocused)
                    .padding(12).background(AppTheme.surface, in: .rect(cornerRadius: 16))
                    .accessibilityIdentifier("chatComposer")
                Button {
                    Task { await session.sendDraft() }
                } label: {
                    Group {
                        if session.isSending { ProgressView().tint(.black) }
                        else { Image(systemName: "arrow.up").font(.headline) }
                    }.frame(width: 44, height: 44)
                }
                .background(AppTheme.accent, in: .circle).foregroundStyle(.black)
                .accessibilityLabel(session.isSending ? "Sending message" : "Send message")
                .disabled(session.isSending || session.connection != .connected || session.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.draft.count > 500)
            }
            if session.draft.count > 450 {
                Text("\(session.draft.count) / 500").font(.caption.monospacedDigit())
                    .foregroundStyle(session.draft.count > 500 ? .orange : .secondary)
            }
        }.padding(12).background(AppTheme.background)
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let replyName = message.replyName {
                Text("↳ \(replyName): \(message.replyText ?? "")").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Text("\(Text(message.name).fontWeight(.bold).foregroundColor(.white))  \(message.text)")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            let emotes = message.fragments.filter { $0.emoteURL != nil }
            if !emotes.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        ForEach(Array(emotes.prefix(8).enumerated()), id: \.offset) { _, fragment in
                            let url = reduceMotion ? fragment.emoteURL.flatMap { URL(string: $0.absoluteString.replacingOccurrences(of: "/animated/", with: "/static/")) } : fragment.emoteURL
                            AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { Color.clear }
                                .frame(width: 28, height: 28).accessibilityHidden(true)
                        }
                    }
                    EmptyView()
                }
            }
            if let source = message.sourceChannel {
                Text("Shared from \(source)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(message.badges.joined(separator: ", ")) \(message.name): \(message.text)")
    }
}
