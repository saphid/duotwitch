import SwiftUI

struct NativeChatView: View {
    @Bindable var session: ChatSession
    let signedIn: Bool
    var composerVisible = true
    var composerFocus: FocusState<Bool>.Binding? = nil
    let signIn: () -> Void
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var atBottom = true
    @State private var reporting: ChatMessage?
    @State private var blocking: ChatMessage?
    @FocusState private var composerFocused: Bool

    private var inputFocused: Bool {
        get { composerFocus?.wrappedValue ?? composerFocused }
        nonmutating set {
            if let composerFocus { composerFocus.wrappedValue = newValue }
            else { composerFocused = newValue }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !signedIn {
                GeometryReader { geometry in
                    ViewThatFits {
                        Button("Sign in", action: signIn)
                            .buttonStyle(.bordered).controlSize(.large)
                            .fixedSize().padding(12)
                            .accessibilityLabel("Sign in to chat")
                        Button(action: signIn) {
                            let side = min(44, max(0, min(geometry.size.width, geometry.size.height)))
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 22))
                                .scaleEffect(min(1, side / 44))
                                .frame(width: side, height: side)
                                .background(AppTheme.surface, in: .circle)
                                .contentShape(Circle())
                        }.buttonStyle(.plain).accessibilityLabel("Sign in to chat")
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            } else {
                timeline
                composer
            }
        }
        .background(AppTheme.background)
        .accessibilityIdentifier("nativeChat")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chat")
        .onChange(of: composerVisible) { _, visible in if !visible { inputFocused = false } }
        .sheet(item: $reporting) { message in
            NavigationStack {
                Form {
                    Section("Report message from \(message.name)") {
                        Text(message.text).textSelection(.enabled)
                        Text("Describe the concern in an email to support. The message and its ID are included in the draft. Nothing is sent until you send the email.")
                        if let url = SupportLinks.report(message) {
                            Link("Email safety report", destination: url).frame(minHeight: 44)
                        }
                        Text(SupportLinks.email).textSelection(.enabled)
                        Link("Report to Twitch", destination: URL(string: "https://safety.twitch.tv/s/article/Filing-a-Report")!)
                    }
                    Section {
                        Button("Block \(message.name) in Duo Viewer", role: .destructive) {
                            session.block(message)
                            reporting = nil
                        }
                    } footer: {
                        Text("Blocking removes this user’s messages here and hides future messages in this app. It does not change your Twitch account’s block list. Manage blocked users in Account.")
                    }
                }
                .navigationTitle("Report message")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { reporting = nil } } }
            }
        }
        .confirmationDialog("Block this user in Duo Viewer?", isPresented: Binding(
            get: { blocking != nil }, set: { if !$0 { blocking = nil } }), titleVisibility: .visible) {
            if let message = blocking {
                Button("Block \(message.name)", role: .destructive) { session.block(message); blocking = nil }
            }
        } message: { Text("Their messages will be removed and hidden in this app. You can unblock them in Account.") }
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
                                        inputFocused = true
                                    }
                                    Link("View profile in Twitch", destination: URL(string: "https://www.twitch.tv/\(message.login)")!)
                                    Button("Report message", systemImage: "flag") { reporting = message }
                                    Button("Block user in Duo Viewer", systemImage: "person.crop.circle.badge.xmark", role: .destructive) { blocking = message }
                                }
                        }
                        // Keep clearance inside the jump target so an explicit
                        // bottom-aligned jump cannot hide the newest line under
                        // the persistent VoiceOver action.
                        Color.clear
                            .frame(height: voiceOver && !session.messages.isEmpty ? 49 : 1)
                            .id("latest")
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
                .overlay(alignment: .bottomTrailing) {
                    if !atBottom || voiceOver && !session.messages.isEmpty {
                        Button {
                            proxy.scrollTo("latest", anchor: .bottom)
                            atBottom = true
                        } label: {
                            Image(systemName: "arrow.down")
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain).accessibilityLabel("Jump to latest")
                        .background(.regularMaterial, in: .circle)
                        .padding(8)
                    }
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
                    .lineLimit(1...4).focused(composerFocus ?? $composerFocused)
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
