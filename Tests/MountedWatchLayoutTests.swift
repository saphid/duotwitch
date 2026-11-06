import Observation
import SwiftUI
import XCTest
@testable import DuoTwitch

/// Mounted SwiftUI evidence with synthetic division regions. These are not
/// physical hinge tests and do not imply live Twitch continuity.
@MainActor
final class MountedWatchLayoutTests: XCTestCase {
    func testKeyboardChatResizeKeepsComposerFocusAndDraft() async throws {
        // Restore fixture credentials entirely in memory; no account or socket
        // traffic is used to mount the actual production composer and toolbar.
        let scopes = TwitchAuth.requestedScopes
        StubTwitchProtocol.install { _ in
            (200, ["client_id": "test-client", "user_id": "fixture", "login": "fixture",
                   "expires_in": 3600, "scopes": scopes])
        }
        defer { StubTwitchProtocol.install(nil) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubTwitchProtocol.self]
        let store = MemoryCredentialStore()
        store.value = TwitchCredentials(clientId: "test-client", accessToken: "fixture", refreshToken: "fixture",
            expiresAt: .now.addingTimeInterval(3600), userId: "fixture", login: "fixture", scopes: TwitchAuth.requestedScopes)
        let auth = TwitchAuth(clientId: "test-client", store: store, http: TwitchHTTP(session: URLSession(configuration: config)))
        await auth.restore()
        XCTAssertNotNil(auth.account)
        let preferencesName = "DuoTwitch-keyboard-resize-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: preferencesName))
        defer { preferences.removePersistentDomain(forName: preferencesName) }
        preferences.set(WatchChatPlacement.beside.rawValue, forKey: "watchChatPlacement")
        preferences.set(WatchMode.balanced.rawValue, forKey: "watchMode")
        let player = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, _ in }, pauseMedia: { _ in }, requestPlay: { _, _ in true })
        // This unconfigured chat API cannot open a network connection or send.
        let chat = ChatSession(api: TwitchAPI(auth: TwitchAuth(clientId: "")))
        let app = AppModel(auth: auth, player: player, chat: chat)
        let channel = WatchedChannel(channel: TwitchChannel(id: "fixture", broadcasterLogin: "fixture", displayName: "Fixture", gameName: "", title: "", thumbnailUrl: "", isLive: true))
        let host = UIHostingController(rootView: NavigationStack {
            WatchView(app: app, channel: channel).defaultAppStorage(preferences)
        })
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.endEditing(true); window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(250))
        let composer = try XCTUnwrap(findTextInput(in: host.view))
        chat.draft = "Keep this unsent draft"
        XCTAssertTrue(composer.becomeFirstResponder())
        try await Task.sleep(for: .milliseconds(500))
        for placement in [WatchChatPlacement.beside, .below] {
            preferences.set(placement.rawValue, forKey: "watchChatPlacement")
            try await Task.sleep(for: .milliseconds(120))
            let slider = try XCTUnwrap(sliders(in: window).first,
                "The focused composer must expose a live Chat size slider")
            let before = player.webView.convert(player.webView.bounds, to: host.view).size
            slider.value = slider.minimumValue + (slider.maximumValue - slider.minimumValue) * 0.75
            slider.sendActions(for: .valueChanged)
            try await Task.sleep(for: .milliseconds(120))
            host.view.layoutIfNeeded()
            let after = player.webView.convert(player.webView.bounds, to: host.view).size
            XCTAssertNotEqual(placement == .beside ? before.width : before.height,
                              placement == .beside ? after.width : after.height,
                              "The keyboard resize control must change the actual video allocation")
            XCTAssertGreaterThan(preferences.double(forKey: placement == .beside ? "watchChatWidth" : "watchChatHeight"), 0)
            XCTAssertTrue(composer.isFirstResponder, "Resizing from the keyboard must not dismiss the composer")
            XCTAssertTrue(findTextInput(in: host.view) === composer)
            XCTAssertEqual(chat.draft, "Keep this unsent draft")
        }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Focused composer with live resize control"
        attachment.lifetime = .keepAlways
        add(attachment)
        window.endEditing(true)
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertTrue(sliders(in: window).isEmpty, "Resize accessory must leave when the composer loses focus")
        XCTAssertEqual(chat.draft, "Keep this unsent draft")
    }

    private func sliders(in view: UIView) -> [UISlider] {
        (view as? UISlider).map { [$0] } ?? view.subviews.flatMap { sliders(in: $0) }
    }

    func testProductionWatchFullVideoReturnAtNarrowRegularWidthDoesNotPause() async throws {
        try await assertProductionWatchFullVideoReturn(dynamicTypeSize: .large)
    }

    func testProductionWatchFullVideoReturnPreservesPlaybackWithAccessibilityText() async throws {
        for size in [DynamicTypeSize.accessibility3, .accessibility5] {
            try await assertProductionWatchFullVideoReturn(dynamicTypeSize: size)
        }
    }

    private func assertProductionWatchFullVideoReturn(dynamicTypeSize: DynamicTypeSize) async throws {
        let cases: [(Double, Double, UserInterfaceSizeClass, WatchMode)] = [
            (466, 700, .regular, .balanced), (466, 700, .regular, .slim),
            (550, 700, .regular, .balanced), (550, 700, .regular, .slim),
            (750, 304, .compact, .balanced), (750, 304, .compact, .slim)
        ]
        for (width, height, sizeClass, returningMode) in cases {
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
                .environment(\.horizontalSizeClass, sizeClass).dynamicTypeSize(dynamicTypeSize)
                .defaultAppStorage(preferences).ignoresSafeArea())
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            let container = UIViewController()
            window.rootViewController = container
            window.makeKeyAndVisible()
            container.addChild(host)
            container.view.addSubview(host.view)
            host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
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

    func testProductionResizableChatRetainsPlayerAndPlayback() async throws {
        for (width, height, placement) in [(1000.0, 700.0, WatchChatPlacement.beside), (800, 1100, .below)] {
            let name = "DuoTwitch-resize-test-\(UUID().uuidString)"
            let preferences = try XCTUnwrap(UserDefaults(suiteName: name))
            defer { preferences.removePersistentDomain(forName: name) }
            preferences.set(WatchMode.balanced.rawValue, forKey: "watchMode")
            preferences.set(placement.rawValue, forKey: "watchChatPlacement")
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
                .environment(\.horizontalSizeClass, .regular).dynamicTypeSize(.accessibility3)
                .defaultAppStorage(preferences).ignoresSafeArea())
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            let container = UIViewController()
            window.rootViewController = container
            window.makeKeyAndVisible()
            container.addChild(host)
            container.view.addSubview(host.view)
            host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
            host.didMove(toParent: container)
            defer { window.isHidden = true; window.rootViewController = nil }
            try await Task.sleep(for: .milliseconds(250))
            let currentNonce = try XCTUnwrap(nonce)
            session.handleHostMessage(["session": currentNonce, "event": "READY"], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true)
            await session.play()
            session.handleHostMessage(["session": currentNonce, "event": "PLAYING"], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true)
            let baseline = pauses
            let browser = session.webView
            var extents: [CGFloat] = []
            for amount in [240.0, 340, 10000, 240] {
                preferences.set(amount, forKey: placement == .beside ? "watchChatWidth" : "watchChatHeight")
                try await Task.sleep(for: .milliseconds(180))
                host.view.layoutIfNeeded()
                XCTAssertTrue(session.webView === browser)
                XCTAssertTrue(session.isPlaying)
                XCTAssertEqual(pauses, baseline)
                XCTAssertEqual(loads, 1)
                XCTAssertGreaterThanOrEqual(session.webView.bounds.width, 400)
                XCTAssertGreaterThanOrEqual(session.webView.bounds.height, 300)
                extents.append(placement == .beside ? session.webView.bounds.width : session.webView.bounds.height)
            }
            XCTAssertGreaterThan(extents[0], extents[1], "Growing chat must shrink the actual production player allocation")
            XCTAssertEqual(extents[0], extents[3], accuracy: 1, "Reset split must restore the original allocation")
            preferences.set(WatchMode.slim.rawValue, forKey: "watchMode")
            try await Task.sleep(for: .milliseconds(180))
            let slimExtent = placement == .beside ? session.webView.bounds.width : session.webView.bounds.height
            XCTAssertGreaterThan(slimExtent, extents[0], "Slim chat must visibly reserve more room for video by default")
            preferences.set(320.0, forKey: placement == .beside ? "watchSlimChatWidth" : "watchSlimChatHeight")
            try await Task.sleep(for: .milliseconds(180))
            preferences.set(WatchMode.balanced.rawValue, forKey: "watchMode")
            try await Task.sleep(for: .milliseconds(180))
            let restored = placement == .beside ? session.webView.bounds.width : session.webView.bounds.height
            XCTAssertEqual(restored, extents[0], accuracy: 1, "Resizing Slim must preserve the saved regular split")
            XCTAssertTrue(session.isPlaying)
            XCTAssertEqual(pauses, baseline)
            XCTAssertEqual(loads, 1)
            if placement == .beside {
                let attachedHost = session.webView.superview
                host.view.frame.size = CGSize(width: 340, height: 286)
                try await Task.sleep(for: .milliseconds(80))
                host.view.frame.size = CGSize(width: 750, height: 304)
                try await Task.sleep(for: .milliseconds(450))
                XCTAssertTrue(session.isPlaying, "A transient rotation allocation must not issue Pause")
                XCTAssertEqual(pauses, baseline)
                XCTAssertTrue(session.webView.superview === attachedHost, "The browser host must survive transient undersize geometry")
                XCTAssertEqual(loads, 1)
                // A persistent keyboard-sized allocation must keep playing,
                // not merely survive a short transition grace period.
                host.view.frame.size = CGSize(width: 750, height: 160)
                try await Task.sleep(for: .milliseconds(500))
                host.view.layoutIfNeeded()
                XCTAssertTrue(session.isPlaying, "The keyboard-sized layout must not pause video")
                XCTAssertEqual(pauses, baseline)
                XCTAssertTrue(session.webView.superview === attachedHost)
                XCTAssertGreaterThanOrEqual(session.webView.bounds.width, 400)
                XCTAssertGreaterThanOrEqual(session.webView.bounds.height, 300)
                let presented = session.webView.convert(session.webView.bounds, to: host.view)
                XCTAssertGreaterThan(presented.height, 0)
                XCTAssertLessThanOrEqual(presented.height, 161, "The visible player must scale inside the reduced allocation")
                await session.pause()
                host.view.frame.size = CGSize(width: 750, height: 304)
                try await Task.sleep(for: .milliseconds(180))
                XCTAssertFalse(session.isPlaying, "Keyboard dismissal must not undo intentional Pause")
                XCTAssertEqual(loads, 1)
            }
        }
    }

    func testProductionPanelDoesNotPauseItselfAfterPlay() async throws {
        let channel = WatchedChannel(channel: TwitchChannel(id: "lofi", broadcasterLogin: "lofigirl", displayName: "LofiGirl", gameName: "Music", title: "A live stream with a title that wraps in smaller video panes", thumbnailUrl: "", isLive: true))
        var testedSizes = 0
        for (width, height) in [(750.0, 304.0), (464.0, 304.0), (500.0, 160.0), (382.0, 280.0), (160.0, 120.0)] + [402.0, 420.0, 500.0, 600.0].flatMap({ width in
            [364.0, 384.0, 420.0, 480.0, 560.0].map { (width, $0) }
        }) {
            var nonce: String?
            var pauses = 0
            let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
                loadRequest: { _, request in nonce = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "session" }?.value },
                pauseMedia: { _ in pauses += 1 }, requestPlay: { _, _ in true })
            let host = UIHostingController(rootView: WatchVideoPanel(session: session, channel: channel).ignoresSafeArea())
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
            let expectedViewport = WatchVideoViewport(available: CGSize(width: width, height: height))
            XCTAssertEqual(session.webView.bounds.width, expectedViewport.size.width, accuracy: 1,
                           "The player must use the whole video pane without a duplicate controls rail")
            XCTAssertEqual(session.webView.bounds.height, expectedViewport.size.height, accuracy: 1,
                           "The player must not reserve a second transport bar below Twitch's controls")
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
        XCTAssertEqual(testedSizes, 25, "Every supported panel size must load a playable player, including short landscape")
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

    func testOnePointChatAllocationIsEnforcedOnBothSidesAndBelow() async throws {
        let model = LayoutHarnessModel()
        let mounted = try MountedHarness(model: model)
        defer { mounted.close() }
        model.chatWidth = 1
        model.chatHeight = 1
        for placement in [WatchChatPlacement.beside, .below] {
            model.placement = placement
            for leading in [false, true] {
                model.chatLeading = leading
                await mounted.settle()
                let expected = WatchPaneGeometry(size: mounted.size, compact: false, division: nil,
                    mode: .balanced, chatLeading: leading, placement: placement, chatWidth: 1, chatHeight: 1)
                let probe = try XCTUnwrap(model.chat.view)
                let chat = probe.convert(probe.bounds, to: mounted.host.view)
                assertRect(chat, expected.chat)
                XCTAssertFalse(chat.intersects(expected.video), "The allocated chat wrapper must not overlap video")
                XCTAssertTrue(CGRect(origin: .zero, size: mounted.size).contains(chat))
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
    var chatWidth: CGFloat? = nil
    var chatHeight: CGFloat? = nil
    var placement: WatchChatPlacement = .automatic
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
            WatchPaneBounds {
                NativeChatView(session: model.session, signedIn: true, composerVisible: model.mode != .video) { }
            }
                .background(PaneProbe(identity: model.chat))
                .opacity(model.mode == .video ? 0 : 1)
                .allowsHitTesting(model.mode != .video)
        }
            .arrangementViewStyle(WatchArrangementStyle(compact: false, division: model.division,
                mode: model.mode, chatLeading: model.chatLeading, placement: model.placement,
                chatWidth: model.chatWidth, chatHeight: model.chatHeight))
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
