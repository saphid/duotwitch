import SwiftUI

/// Temporary feasibility surface. This is not the finished viewing interface.
struct PlayerProbeView: View {
    let session: PlaybackSession
    @State private var channel = PlaybackSession.validChannel(UserDefaults.standard.string(forKey: "DuoTwitchProbeChannel") ?? "monstercat") ?? "monstercat"
    @State private var fullScreen = false
    @State private var playerOnRight = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    PlayerHost(session: session)
                        .frame(height: fullScreen ? geo.size.height : max(300, geo.size.height * 0.52))
                    if !fullScreen {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Playback feasibility build", systemImage: "wrench.and.screwdriver")
                                    .font(.headline)
                                HStack {
                                    TextField("Twitch channel", text: $channel)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityIdentifier("channelInput")
                                    Button("Open") { session.open(channel: channel) }
                                        .buttonStyle(.borderedProminent)
                                }
                                Text(session.status).accessibilityIdentifier("playerStatus")
                                LabeledContent("Host event", value: session.hostEvent)
                                LabeledContent("Media event", value: session.mediaState)
                                LabeledContent("Presentation", value: session.presentationMode)
                                LabeledContent("Player loads", value: "\(session.loadCount)")
                                HStack {
                                    Button("Pause video", systemImage: "pause.fill") {
                                        Task { await session.pause() }
                                    }
                                    Button("Inspect video", systemImage: "info.circle") {
                                        Task { await session.inspectMedia() }
                                    }
                                    Button("Picture in Picture", systemImage: "pip.enter") {
                                        Task { await session.requestPictureInPicture() }
                                    }
                                }.buttonStyle(.bordered)
                                Text(session.probeResult)
                                    .font(.footnote.monospaced())
                                    .textSelection(.enabled)
                                    .accessibilityIdentifier("probeResult")
                                Text("This screen tests Twitch’s official player. Sign-in and chat require separate verification.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }.padding(20)
                        }
                    }
                }
            }
            .navigationTitle("Foldstream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(fullScreen ? "Show details" : "Full screen", systemImage: fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                        fullScreen.toggle()
                    }
                }
            }
            .task { session.open(channel: channel) }
        }
    }
}
