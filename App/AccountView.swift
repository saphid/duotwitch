import SwiftUI

struct AccountView: View {
    @Bindable var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var signOutError: String?
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                if let account = app.auth.account {
                    Section {
                        Label(account.login, systemImage: "person.crop.circle.fill").font(.title2.bold()).padding(.vertical, 8)
                        Text("Connected to Twitch").foregroundStyle(.secondary)
                    }
                    Section {
                        Button("Sign out", role: .destructive) { confirmSignOut = true }
                    } footer: { Text("Signing out removes the saved access and refresh tokens from this iPhone.") }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Make yourself at home.").font(.title2.bold())
                            Text("Connect your Twitch account to discover streams, see who’s live, and join the conversation.").foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }
                    if let challenge = app.auth.challenge {
                        Section("Your sign-in code") {
                            Text(challenge.userCode).font(.largeTitle.monospaced().bold()).textSelection(.enabled)
                                .accessibilityLabel("Sign-in code: \(challenge.userCode.map(String.init).joined(separator: " "))")
                            Button("Continue on Twitch", systemImage: "arrow.up.forward.square") { openURL(challenge.verificationURL) }
                            Text("Enter this code on Twitch. This screen will update when you approve access.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button("Cancel sign-in", role: .cancel) { app.auth.cancelSignIn() }
                        }
                    } else {
                        Section {
                            Button { app.auth.beginSignIn() } label: {
                                HStack {
                                    Text(app.auth.isAuthorizing ? "Contacting Twitch…" : "Sign in with Twitch")
                                    Spacer()
                                    if app.auth.isAuthorizing { ProgressView() } else { Image(systemName: "arrow.up.forward.square") }
                                }.padding(.vertical, 6)
                            }.disabled(app.auth.isAuthorizing || app.auth.isRestoring || !app.auth.isConfigured)
                        } footer: {
                            Text(app.auth.isConfigured ? "You approve access directly on Twitch. DuoTwitch never sees your password." : "Twitch sign-in isn’t configured in this development build yet.")
                        }
                    }
                }
                if let error = signOutError ?? app.auth.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        if app.auth.isConfigured && app.auth.canRetryRestore && app.auth.account == nil && !app.auth.isAuthorizing {
                            Button("Retry connection") { Task { await app.auth.restore() } }.disabled(app.auth.isRestoring)
                        }
                    }
                }
                if let warning = app.auth.persistenceWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.shield").foregroundStyle(.orange)
                        Button("Retry saving sign-in") { Task { await app.auth.maintainSession() } }
                    }
                }
                Section("About this viewer") {
                    Text("DuoTwitch is an independent Twitch viewer, designed for video and native chat on iPhone.")
                    Text("Subscriptions, Bits, channel points, Drops and creator tools open in Twitch. Your API sign-in and the video player’s account are separate.")
                        .foregroundStyle(.secondary)
                    Link("Twitch privacy policy", destination: URL(string: "https://www.twitch.tv/p/en/legal/privacy-notice/")!)
                }
            }
            .navigationTitle(app.auth.account == nil ? "Connect" : "Account")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() }.labelStyle(.iconOnly) } }
            .confirmationDialog("Sign out of Twitch?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    do { try app.auth.signOut() } catch { signOutError = error.localizedDescription }
                }
            }
        }.presentationDragIndicator(.visible)
    }
}
