import AuthenticationServices
import Observation
import SwiftUI

struct AccountView: View {
    @Bindable var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var browser = TwitchApprovalSession()
    @State private var browserError: String?
    @State private var openWhenReady = false
    @State private var justConnected = false
    @State private var copiedCode = false
    @State private var signOutError: String?
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let account = app.auth.account {
                        connected(account)
                    } else {
                        connection
                    }
                    if let error = signOutError ?? browserError ?? app.auth.errorMessage {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                            if app.auth.canRetryRestore && app.auth.account == nil {
                                Button("Reconnect saved account") { Task { await app.auth.restore() } }
                                    .disabled(app.auth.isRestoring)
                            } else if app.auth.account == nil && !app.auth.isAuthorizing {
                                Button("Try again", action: connect).buttonStyle(.bordered)
                            }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface, in: .rect(cornerRadius: 18))
                    }
                    if let warning = app.auth.persistenceWarning {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(warning, systemImage: "exclamationmark.shield").foregroundStyle(.orange)
                            Button("Save this sign-in again") { Task { await app.auth.maintainSession() } }
                        }
                    }
                    NavigationLink {
                        PlaybackDiagnosticsView(diagnostics: app.player.diagnostics)
                    } label: {
                        Label("Playback diagnostics", systemImage: "waveform.path.ecg")
                    }.frame(minHeight: 44)
                    NavigationLink("Blocked chat users") {
                        List {
                            if app.chat.blockedUsers.isEmpty {
                                Text("No users blocked in this app.").foregroundStyle(.secondary)
                            }
                            ForEach(app.chat.blockedUsers.keys.sorted(), id: \.self) { id in
                                HStack {
                                    Text(app.chat.blockedUsers[id] ?? id)
                                    Spacer()
                                    Button("Unblock") { app.chat.unblock(userId: id) }
                                        .frame(minHeight: 44)
                                }
                            }
                        }
                        .navigationTitle("Blocked chat users")
                    }.frame(minHeight: 44)
                    Link("Privacy policy", destination: SupportLinks.privacy).frame(minHeight: 44)
                    Link("Support & safety", destination: SupportLinks.support).frame(minHeight: 44)
                    DisclosureGroup("About your connection") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Foldstream connects to your Twitch account for discovery, following and chat. Your password stays with Twitch.")
                            Text("Twitch’s approval page still calls this connection Saphid Duo Viewer. It is the existing Twitch connection for Foldstream.")
                            Text("Foldstream is independent and is not sponsored or endorsed by Twitch. Long-press a chat message to report it or block its author in this app. Twitch’s moderators also control the channel chat.")
                            Text("Twitch’s video player manages its own account. If a stream requires a subscription or age check, the player may ask you to sign in separately.")
                            Text("Subscriptions, Bits, channel points and creator tools open in Twitch.")
                            Link("Twitch privacy policy", destination: URL(string: "https://www.twitch.tv/p/en/legal/privacy-notice/")!)
                        }.font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                    }.font(.subheadline)
                }
                .padding(24).frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(AppTheme.background)
            .navigationTitle(app.auth.account == nil ? "Connect Twitch" : "Your account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
            .onChange(of: app.auth.challenge?.id) { _, _ in
                if let challenge = app.auth.challenge, openWhenReady {
                    openApproval(challenge)
                    openWhenReady = false
                } else if app.auth.challenge == nil {
                    browser.close()
                }
            }
            .onChange(of: app.auth.account) { _, account in
                if account != nil { browser.close(); justConnected = true; openWhenReady = false }
            }
            .confirmationDialog("Sign out of Twitch?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    do { try app.auth.signOut(); justConnected = false }
                    catch { signOutError = error.localizedDescription }
                }
            }
        }.presentationDragIndicator(.visible)
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48, weight: .light)).foregroundStyle(AppTheme.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Twitch.\nReady when you are.").font(.largeTitle.bold())
                Text("Connect once for your followed channels and live chat. Use your Twitch account, or create one on Twitch.")
                    .font(.body).foregroundStyle(.secondary)
            }
            if let challenge = app.auth.challenge {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Waiting for Twitch approval", systemImage: "clock")
                        .font(.headline).accessibilityIdentifier("authorizationProgress")
                    Text(app.auth.authorizationNotice ?? "Approve access on Twitch, then return here.")
                        .foregroundStyle(.secondary)
                    Button { openApproval(challenge) } label: {
                        Label("Continue on Twitch", systemImage: "arrow.up.forward.square")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    Text(challenge.includesCodeInURL ? "Your code is included in the Twitch page. There’s nothing to type." : "If Twitch asks for a code, copy it below and paste it on the page.")
                        .font(.footnote).foregroundStyle(.secondary)
                    DisclosureGroup("Need to enter a code?") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(challenge.userCode).font(.title.monospaced().bold()).textSelection(.enabled)
                                .accessibilityLabel("Sign-in code: \(challenge.userCode.map(String.init).joined(separator: " "))")
                            Button(copiedCode ? "Code copied" : "Copy code", systemImage: copiedCode ? "checkmark" : "doc.on.doc") {
                                UIPasteboard.general.setItems([["public.utf8-plain-text": challenge.userCode]],
                                    options: [.localOnly: true, .expirationDate: challenge.expiresAt])
                                copiedCode = true
                            }.buttonStyle(.bordered)
                            Text("Expires \(challenge.expiresAt, style: .relative)").font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 10)
                    }
                    Button("Cancel connection", role: .cancel) { openWhenReady = false; browser.close(); app.auth.cancelSignIn() }
                        .frame(minHeight: 44)
                }.padding(18).background(AppTheme.surface, in: .rect(cornerRadius: 20))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Approve securely on Twitch", systemImage: "lock.shield")
                    Label("Return straight to your streams", systemImage: "play.rectangle")
                }.font(.subheadline)
                Button(action: connect) {
                    HStack(spacing: 12) {
                        if app.auth.isAuthorizing || app.auth.isRestoring { ProgressView().tint(.white) }
                        Text(app.auth.isRestoring ? "Restoring your account…" : app.auth.isAuthorizing ? "Opening Twitch…" : "Continue with Twitch")
                            .fontWeight(.semibold)
                    }.frame(maxWidth: .infinity).padding(.vertical, 10)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(app.auth.isAuthorizing || app.auth.isRestoring || !app.auth.isConfigured)
                Text(app.auth.isConfigured ? "Twitch opens securely inside Foldstream. We never see your password." : "Twitch connection is unavailable in this build.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func connected(_ account: TwitchAccount) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(.green).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(justConnected ? "You’re connected." : "Connected to Twitch").font(.largeTitle.bold())
                Text("Signed in as \(account.login)").font(.title3).foregroundStyle(.secondary)
                Text("Your followed channels and chat are ready.").foregroundStyle(.secondary)
            }
            Button(justConnected ? "Start watching" : "Back to streams") { dismiss() }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(minHeight: 44)
            Button("Sign out", role: .destructive) { confirmSignOut = true }.frame(minHeight: 44)
        }
    }

    private func openApproval(_ challenge: SignInChallenge) {
        browserError = browser.open(challenge.verificationURL) ? nil : "Couldn’t open Twitch. Tap Continue to try again."
    }

    private func connect() {
        browserError = nil
        copiedCode = false
        openWhenReady = true
        app.auth.beginSignIn()
    }
}

/// Uses the system sign-in browser and its existing web session. The public
/// device flow completes through polling, so no callback URL or secret is needed.
@MainActor @Observable
private final class TwitchApprovalSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    @ObservationIgnored private var session: ASWebAuthenticationSession?
    @ObservationIgnored private var anchor: UIWindow?
    @ObservationIgnored private var generation = UUID()

    func open(_ url: URL) -> Bool {
        if session != nil { return true }
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .filter({ $0.activationState == .foregroundActive })
            .flatMap(\.windows).first(where: \.isKeyWindow) else { return false }
        anchor = window
        let ticket = UUID()
        generation = ticket
        let request = ASWebAuthenticationSession(url: url, callbackURLScheme: nil) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.generation == ticket else { return }
                self.session = nil; self.anchor = nil
            }
        }
        request.presentationContextProvider = self
        request.prefersEphemeralWebBrowserSession = false
        session = request
        guard request.start() else { session = nil; anchor = nil; return false }
        return true
    }

    func close() {
        generation = UUID()
        session?.cancel()
        session = nil
        anchor = nil
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }
}
