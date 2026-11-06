import Observation
import SwiftUI
import XCTest
@testable import DuoTwitch

/// Mounted SwiftUI evidence with synthetic division regions. These are not
/// physical hinge tests and do not imply live Twitch continuity.
@MainActor
final class MountedWatchLayoutTests: XCTestCase {
    func testProductionWatchFullVideoReturnAtNarrowRegularWidthDoesNotPause() async throws {
        try await assertProductionWatchFullVideoReturn(dynamicTypeSize: .large)
    }

    func testProductionWatchFullVideoReturnPreservesPlaybackWithAccessibilityText() async throws {
        for size in [DynamicTypeSize.accessibility3, .accessibility5] {
            try await assertProductionWatchFullVideoReturn(dynamicTypeSize: size)
        }
    }

    private func assertProductionWatchFullVideoReturn(dynamicTypeSize: DynamicTypeSize) async throws {
        for (width, returningMode) in [(466.0, WatchMode.balanced), (466.0, .slim), (550.0, .balanced), (550.0, .slim)] {
            let preferencesName = "DuoTwitch-layout-test-\(UUID().uuidString)"
            let preferences = try XCTUnwrap(UserDefaults(suiteName: preferencesName))
            defer { preferences.removePersistentDomain(forName: preferencesName) }
            preferences.set(WatchMode.video.rawValue, forKey: "watchMode")
            var nonce: String?
            var pauses = 0
            var loads = 0
            let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
                loadRequest: { _, request in
                    loads += 1
                    nonce = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "session" }?.value
                }, pauseMedia: { _ in pauses += 1 }, requestPlay: { _, _ in true })
            let app = AppModel(auth: TwitchAuth(clientId: ""), player: session)
            let channel = WatchedChannel(channel: TwitchChannel(id: "fixture", broadcasterLogin: "fixture", displayName: "Fixture", gameName: "", title: "", thumbnailUrl: "", isLive: true))
            let host = UIHostingController(rootView: WatchView(app: app, channel: channel)
                .environment(\.horizontalSizeClass, .regular).dynamicTypeSize(dynamicTypeSize)
                .defaultAppStorage(preferences).ignoresSafeArea())
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            let container = UIViewController()
            window.rootViewController = container
            window.makeKeyAndVisible()
            container.addChild(host)
            container.view.addSubview(host.view)
            host.view.frame = CGRect(x: 0, y: 0, width: width, height: 700)
            host.didMove(toParent: container)
            defer { window.isHidden = true; window.rootViewController = nil }
            try await Task.sleep(for: .milliseconds(200))
            let currentNonce = try XCTUnwrap(nonce)
            session.handleHostMessage(["session": currentNonce, "event": "READY"], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true)
            try await Task.sleep(for: .milliseconds(40))
            XCTAssertTrue(session.canPlay)
            await session.play()
            session.handleHostMessage(["session": currentNonce, "event": "PLAYING"], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true)
            let baselinePauses = pauses
            preferences.set(returningMode.rawValue, forKey: "watchMode")
            try await Task.sleep(for: .milliseconds(250))
            host.view.layoutIfNeeded()
            XCTAssertTrue(session.isPlaying, "Full video return to \(returningMode) must retain playback when the screen can fit the player")
            XCTAssertEqual(pauses, baselinePauses, "Returning layout must not request an insufficient-space Pause")
            XCTAssertEqual(loads, 1)
            await session.pause()
            preferences.set(WatchMode.video.rawValue, forKey: "watchMode")
            try await Task.sleep(for: .milliseconds(60))
            preferences.set(returningMode.rawValue, forKey: "watchMode")
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertFalse(session.isPlaying, "Layout changes must preserve an intentional Pause")
            XCTAssertEqual(loads, 1)
        }
    }

    func testProductionPanelDoesNotPauseItselfAfterPlay() async throws {
        let channel = WatchedChannel(channel: TwitchChannel(id: "lofi", broadcasterLogin: "lofigirl", displayName: "LofiGirl", gameName: "Music", title: "A live stream with a title that wraps in smaller video panes", thumbnailUrl: "", isLive: true))
        var testedSizes = 0
        for width in [402.0, 420.0, 500.0, 600.0] {
            for height in [364.0, 384.0, 420.0, 480.0, 560.0] {
                var nonce: String?
                var pauses = 0
                let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
                    loadRequest: { _, request in nonce = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "session" }?.value },
                    pauseMedia: { _ in pauses += 1 }, requestPlay: { _, _ in true })
                let host = UIHostingController(rootView: WatchVideoPanel(session: session, channel: channel, toggleFullVideo: {}).ignoresSafeArea())
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = UIWindow(windowScene: scene)
                let container = UIViewController()
                window.rootViewController = container
                window.makeKeyAndVisible()
                container.addChild(host)
                container.view.addSubview(host.view)
                host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
                host.didMove(toParent: container)
                try await Task.sleep(for: .milliseconds(100))
                host.view.layoutIfNeeded()
                if let nonce {
                    session.handleHostMessage(["session": nonce, "event": "READY"], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true)
                    try await Task.sleep(for: .milliseconds(40))
                    if session.canPlay {
                        testedSizes += 1
                        let before = pauses
                        await session.play()
                        session.handleHostMessage(["session": nonce, "event": "PLAYING"], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true)
                        try await Task.sleep(for: .milliseconds(150))
                        XCTAssertTrue(session.isPlaying, "Playback stopped at \(width)×\(height): \(session.status)")
                        XCTAssertEqual(pauses, before, "Panel issued a Pause after Play at \(width)×\(height)")
                    }
                }
                window.isHidden = true
                window.rootViewController = nil
            }
        }
        XCTAssertEqual(testedSizes, 20, "Every supported panel size must load a playable player, including the compact allocation")
    }

    func testMountedPanesFollowBookTabletopAndSidePreferences() async throws {
        let model = LayoutHarnessModel()
        let mounted = try MountedHarness(model: model)
        defer { mounted.close() }
        for division in [CGRect(x: 440, y: 0, width: 20, height: 700), CGRect(x: 0, y: 330, width: 900, height: 20)] {
            for leading in [false, true] {
                model.division = division
                model.chatLeading = leading
                await mounted.settle()
                let expected = WatchPaneGeometry(size: mounted.size, compact: false, division: division, mode: .balanced, chatLeading: leading)
                let video = try XCTUnwrap(model.video.view).convert(try XCTUnwrap(model.video.view).bounds, to: mounted.host.view)
                let chat = try XCTUnwrap(model.chat.view).convert(try XCTUnwrap(model.chat.view).bounds, to: mounted.host.view)
                assertRect(video, expected.video)
                assertRect(chat, expected.chat)
                XCTAssertFalse(video.intersects(division))
                XCTAssertFalse(chat.intersects(division))
            }
        }
    }

    func testChangingModesKeepsBothPaneIdentities() async throws {
        let model = LayoutHarnessModel()
        let mounted = try MountedHarness(model: model)
        defer { mounted.close() }
        await mounted.settle()
        let video = try XCTUnwrap(model.video.view)
        let chat = try XCTUnwrap(model.chat.view)
        for mode in [WatchMode.slim, .video, .balanced] {
            model.mode = mode
            await mounted.settle()
            XCTAssertTrue(model.video.view === video)
            XCTAssertTrue(model.chat.view === chat)
            let expected = WatchPaneGeometry(size: mounted.size, compact: false, division: nil, mode: mode, chatLeading: false)
            assertRect(video.convert(video.bounds, to: mounted.host.view), expected.video)
        }
    }

    func testNativeComposerKeepsDraftSelectionAndFocusAcrossPaneChanges() async throws {
        let model = LayoutHarnessModel()
        model.session.draft = "A native draft with selection"
        let mounted = try MountedHarness(model: model)
        defer { mounted.close() }
        await mounted.settle()
        let composer = try XCTUnwrap(findTextInput(in: mounted.host.view))
        let input = try XCTUnwrap(composer as? any UITextInput)
        XCTAssertTrue(composer.becomeFirstResponder())
        let start = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: 2))
        let end = try XCTUnwrap(input.position(from: input.beginningOfDocument, offset: 8))
        input.selectedTextRange = input.textRange(from: start, to: end)
        for division in [CGRect?.none, CGRect(x: 440, y: 0, width: 20, height: 700), CGRect(x: 0, y: 330, width: 900, height: 20)] {
            model.division = division
            model.mode = .slim
            model.chatLeading.toggle()
            await mounted.settle()
            XCTAssertTrue(findTextInput(in: mounted.host.view) === composer)
            XCTAssertTrue(composer.isFirstResponder)
            XCTAssertEqual(model.session.draft, "A native draft with selection")
            let selection = try XCTUnwrap(input.selectedTextRange)
            XCTAssertEqual(input.offset(from: input.beginningOfDocument, to: selection.start), 2)
            XCTAssertEqual(input.offset(from: input.beginningOfDocument, to: selection.end), 8)
        }
        model.mode = .video
        await mounted.settle()
        XCTAssertFalse(composer.isFirstResponder, "Full video must not type into an invisible composer")
        XCTAssertEqual(model.session.draft, "A native draft with selection")
    }

    private func findTextInput(in view: UIView) -> UIView? {
        if view is UITextField || view is UITextView { return view }
        for child in view.subviews {
            if let input = findTextInput(in: child) { return input }
        }
        return nil
    }

    private func assertRect(_ actual: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 1, file: file, line: line)
    }
}

@MainActor @Observable
private final class LayoutHarnessModel {
    var division: CGRect?
    var chatLeading = false
    var mode: WatchMode = .balanced
    let video = ViewIdentity()
    let chat = ViewIdentity()
    let session = ChatSession(api: TwitchAPI(auth: TwitchAuth(clientId: "")))
}

@MainActor
private final class ViewIdentity { weak var view: UIView? }

private struct PaneProbe: UIViewRepresentable {
    let identity: ViewIdentity
    func makeUIView(context: Context) -> UIView { let view = UIView(); identity.view = view; return view }
    func updateUIView(_ uiView: UIView, context: Context) { }
}

private struct WatchLayoutHarness: View {
    let model: LayoutHarnessModel
    var body: some View {
        ArrangementView { PaneProbe(identity: model.video) } secondary: {
            NativeChatView(session: model.session, signedIn: true, composerVisible: model.mode != .video) { }
                .background(PaneProbe(identity: model.chat))
                .opacity(model.mode == .video ? 0 : 1)
                .allowsHitTesting(model.mode != .video)
        }
            .arrangementViewStyle(WatchArrangementStyle(compact: false, division: model.division,
                mode: model.mode, chatLeading: model.chatLeading))
            .ignoresSafeArea()
    }
}

@MainActor
private final class MountedHarness {
    let size = CGSize(width: 900, height: 700)
    let host: UIHostingController<WatchLayoutHarness>
    private let window: UIWindow
    init(model: LayoutHarnessModel) throws {
        host = UIHostingController(rootView: WatchLayoutHarness(model: model))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let container = UIViewController()
        window.rootViewController = container
        window.makeKeyAndVisible()
        container.addChild(host)
        container.view.addSubview(host.view)
        host.view.frame = CGRect(origin: .zero, size: size)
        host.didMove(toParent: container)
    }
    func settle() async {
        try? await Task.sleep(for: .milliseconds(60))
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }
    func close() { window.isHidden = true; window.rootViewController = nil }
}
