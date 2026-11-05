import XCTest
import WebKit
import AVFAudio
@testable import DuoTwitch

@MainActor
final class WebKitAudioOwnershipTests: XCTestCase {
    func testProviderPlaybackDoesNotStartACompetingNativeAudioTransition() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let diagnostics = PlaybackDiagnostics(store: PlaybackDiagnosticStore(directory: directory))
        let native = AVAudioSession.sharedInstance()
        let category = native.category
        let mode = native.mode
        var url: URL?
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, request in url = request.url },
            inactivityEvents: AsyncStream { $0.finish() }, pauseMedia: { _ in }, diagnostics: diagnostics)
        session.open(channel: "fixture")
        let nonce = URLComponents(url: try XCTUnwrap(url), resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        // Replay the host PLAYING boundary from both captured phone attempts.
        // The browser/media commands are stubbed: no video or audio is started.
        for _ in 0..<2 {
            XCTAssertTrue(session.handleHostMessage(["event": "PLAYING", "session": nonce], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true))
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertTrue(session.isPlaying)
            XCTAssertTrue(session.handleHostMessage(["event": "PAUSE", "session": nonce], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true))
            XCTAssertFalse(session.isPlaying)
        }
        let exported = try await diagnostics.export()
        let records = try String(contentsOf: exported, encoding: .utf8).split(separator: "\n").map {
            try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
        }
        let nativeTransitions = records.filter { ($0["event"] as? String)?.hasPrefix("audio.transition.") == true }
        XCTAssertTrue(nativeTransitions.isEmpty,
            "WebKit already owns audible media when PLAYING arrives; native category/activation transitions can interrupt it")
        XCTAssertEqual(native.category, category)
        XCTAssertEqual(native.mode, mode)
        XCTAssertEqual(records.filter { $0["event"] as? String == "host.applied" }.count, 4)
    }
}
