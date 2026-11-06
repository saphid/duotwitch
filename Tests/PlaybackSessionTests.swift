import XCTest
import WebKit
@testable import DuoTwitch

@MainActor
final class PlaybackSessionTests: XCTestCase {
    func testSystemInactivityWithoutAnInterruptionDoesNotStopTheVideo() async throws {
        let events = AsyncStream<AudioDeactivation>.makeStream()
        var pauses = 0
        let (session, nonce) = makeBridgeSession(events: events.stream,
                                               pause: { _ in pauses += 1 })
        for _ in 0..<3 {
            emit("PLAYING", session: session, nonce: nonce)
            events.continuation.yield(AudioPlaybackSession.deactivationEvent(isSystem: true, wasInterrupted: false))
            try await Task.sleep(for: .milliseconds(40))
            XCTAssertTrue(session.isPlaying, "A system deactivation without interruption context must not pause WebKit video")
        }
        XCTAssertEqual(pauses, 0)
        events.continuation.yield(.system)
        try await waitUntil { !session.isPlaying }
        XCTAssertEqual(pauses, 1, "A real interruption must still pause after system inactivity")
        events.continuation.finish()
    }

    func testTransientUndersizeCannotPauseAfterRefitOrEnablePlayWhileSettling() async throws {
        var pauses = 0
        let (session, nonce) = makeBridgeSession(pause: { _ in pauses += 1 })
        emit("READY", session: session, nonce: nonce)
        let shrinking = Task { await session.videoAreaChanged(fits: false, channel: "lofigirl", settlingFor: .milliseconds(80)) }
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertFalse(session.canPlay)
        emit("PLAYING", session: session, nonce: nonce)
        await session.videoAreaChanged(fits: true, channel: "lofigirl")
        await shrinking.value
        XCTAssertEqual(pauses, 0)
        XCTAssertTrue(session.isPlaying)
        await session.pause()
        await session.videoAreaChanged(fits: true, channel: "lofigirl")
        XCTAssertFalse(session.isPlaying, "Refitting must not undo intentional Pause")
    }

    func testPersistentUndersizeStillPausesAfterSettlingAndLeavingPausesImmediately() async throws {
        var pauses = 0
        let (session, nonce) = makeBridgeSession(pause: { _ in pauses += 1 })
        emit("PLAYING", session: session, nonce: nonce)
        await session.videoAreaChanged(fits: false, channel: "lofigirl", settlingFor: .milliseconds(20))
        XCTAssertEqual(pauses, 1)
        XCTAssertFalse(session.isPlaying)
        await session.videoAreaChanged(fits: true, channel: "lofigirl")
        emit("PLAYING", session: session, nonce: nonce)
        let shrinking = Task { await session.videoAreaChanged(fits: false, channel: "lofigirl", settlingFor: .milliseconds(80)) }
        try await Task.sleep(for: .milliseconds(10))
        session.hideVideo()
        try await waitUntil { pauses == 2 }
        await shrinking.value
        XCTAssertEqual(pauses, 2, "A stale settling task must not add a second Pause after leaving")
    }

    func testRefitCannotPlayUntilOlderPauseCompletes() async throws {
        var completion: CheckedContinuation<Void, Never>?
        var requests = 0
        let (session, nonce) = makeBridgeSession(pause: { _ in
            await withCheckedContinuation { completion = $0 }
        }, play: { _, _ in requests += 1; return true })
        emit("READY", session: session, nonce: nonce)
        let shrinking = Task { await session.videoAreaChanged(fits: false, channel: "lofigirl") }
        try await waitUntil { completion != nil }
        await session.videoAreaChanged(fits: true, channel: "lofigirl")
        XCTAssertFalse(session.canPlay, "An older pause must finish before a new Play is allowed")
        await session.play()
        XCTAssertEqual(requests, 0)
        completion?.resume()
        await shrinking.value
        XCTAssertTrue(session.canPlay)
        await session.play()
        XCTAssertEqual(requests, 1)
        emit("PLAYING", session: session, nonce: nonce)
        XCTAssertTrue(session.isPlaying)
        XCTAssertEqual(session.status, "Video playing")
    }

    func testNativePlayWaitsForReadyAndOnlyBridgePlaybackConfirmsPlayback() async throws {
        var requests = 0
        let (session, nonce) = makeBridgeSession(play: { _, received in
            XCTAssertFalse(received.isEmpty)
            requests += 1
            return true
        })
        await session.play()
        XCTAssertEqual(requests, 0)
        emit("READY", session: session, nonce: nonce)
        XCTAssertTrue(session.canPlay)
        await session.play()
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(session.status, "Starting video…")
        XCTAssertFalse(session.isPlaying)
        emit("PLAYING", session: session, nonce: nonce)
        XCTAssertTrue(session.isPlaying)
        XCTAssertFalse(session.canPlay)
    }

    func testNativePlayWaitsForTimedOutPauseCallbackEvenAfterPauseEvent() async throws {
        var completion: CheckedContinuation<Void, Never>?
        var requests = 0
        let (session, nonce) = makeBridgeSession(pause: { _ in
            await withCheckedContinuation { completion = $0 }
        }, play: { _, _ in requests += 1; return true }, pauseTimeout: .milliseconds(30))
        emit("READY", session: session, nonce: nonce)
        await session.videoAreaChanged(fits: false, channel: "lofigirl")
        XCTAssertNotNil(session.failure)
        await session.videoAreaChanged(fits: true, channel: "lofigirl")
        emit("PAUSE", session: session, nonce: nonce)
        XCTAssertNil(session.failure)
        XCTAssertFalse(session.canPlay, "An event does not cancel a still-pending WebKit pause")
        await session.play()
        XCTAssertEqual(requests, 0)
        completion?.resume()
        try await waitUntil { session.canPlay }
        await session.play()
        XCTAssertEqual(requests, 1)
    }

    func testHiddenVideoCannotRequestNativePlay() async {
        var requests = 0
        let (session, nonce) = makeBridgeSession(play: { _, _ in requests += 1; return true })
        emit("READY", session: session, nonce: nonce)
        session.hideVideo()
        await session.play()
        XCTAssertEqual(requests, 0)
        XCTAssertFalse(session.canPlay)
    }

    func testLatePlayFailureCannotOverwriteNewerPauseOrChannel() async throws {
        var completion: CheckedContinuation<Bool, Error>?
        let (session, nonce) = makeBridgeSession(play: { _, _ in
            try await withCheckedThrowingContinuation { completion = $0 }
        })
        emit("READY", session: session, nonce: nonce)
        let request = Task { await session.play() }
        try await waitUntil { completion != nil }
        await session.pause(reason: "Paused by user")
        completion?.resume(throwing: URLError(.cannotConnectToHost))
        await request.value
        XCTAssertEqual(session.status, "Paused by user")
        XCTAssertFalse(session.isRequestingPlay)

        completion = nil
        let second = Task { await session.play() }
        try await waitUntil { completion != nil }
        session.open(channel: "monstercat")
        completion?.resume(returning: false)
        await second.value
        XCTAssertEqual(session.status, "Loading Twitch player…")
        XCTAssertEqual(session.channel, "monstercat")
        XCTAssertFalse(session.canPlay)
    }

    func testRejectedNativePlayKeepsOfficialControlsAvailableWithoutClaimingPlayback() async {
        let (session, nonce) = makeBridgeSession(play: { _, _ in false })
        emit("READY", session: session, nonce: nonce)
        await session.play()
        XCTAssertFalse(session.isPlaying)
        XCTAssertNil(session.failure)
        XCTAssertTrue(session.canPlay)
        XCTAssertTrue(session.status.contains("Twitch player"))
    }

    func testUnresponsiveNativePlayIsBoundedAndCanBeRetried() async {
        var completion: CheckedContinuation<Bool, Error>?
        var url: URL?
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, request in url = request.url }, pauseTimeout: .milliseconds(30), requestPlay: { _, _ in
                try await withCheckedThrowingContinuation { completion = $0 }
            })
        session.open(channel: "lofigirl")
        let nonce = URLComponents(url: url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        emit("READY", session: session, nonce: nonce)
        await session.play()
        XCTAssertFalse(session.isRequestingPlay)
        XCTAssertTrue(session.canPlay)
        XCTAssertFalse(session.isPlaying)
        XCTAssertTrue(session.status.contains("Could not start"))
        completion?.resume(returning: true)
    }

    func testChannelInputCannotInjectURLParametersOrHTML() {
        XCTAssertEqual(PlaybackSession.validChannel("  ThePrimeagen\n"), "theprimeagen")
        for input in ["", "bad&parent=example.com", "<script>", "a/b", "hello world", "café", String(repeating: "a", count: 26)] {
            XCTAssertNil(PlaybackSession.validChannel(input), input)
        }
        XCTAssertEqual(PlaybackSession.validChannel("twitch_123"), "twitch_123")
    }

    func testReopeningTheSameChannelPreservesThePlayerAndLoadCount() {
        var requests: [URLRequest] = []
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://example.invalid/player"), probeEnabled: false),
                                      loadRequest: { _, request in requests.append(request) })
        let identity = ObjectIdentifier(session.webView)
        session.open(channel: "monstercat")
        session.open(channel: "MONSTERCAT")
        XCTAssertEqual(session.loadCount, 1)
        XCTAssertEqual(ObjectIdentifier(session.webView), identity)
        XCTAssertEqual(requests.count, 1)
        session.open(channel: "other_channel")
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(ObjectIdentifier(session.webView), identity)
    }

    func testContentProcessTerminationOffersRetryAndRetainsBrowserIdentity() {
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://example.invalid/player"), probeEnabled: false),
                                      loadRequest: { _, _ in })
        session.open(channel: "monstercat")
        let identity = ObjectIdentifier(session.webView)
        session.webViewWebContentProcessDidTerminate(session.webView)
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(session.isPlaying)
        session.open(channel: "monstercat", forceReload: true)
        XCTAssertNil(session.failure)
        XCTAssertEqual(session.loadCount, 2)
        XCTAssertEqual(ObjectIdentifier(session.webView), identity)
    }

    func testLoadingDoesNotClaimPlaybackBeforeHostConfirmation() {
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://example.invalid/player"), probeEnabled: false),
                                      loadRequest: { _, _ in })
        session.open(channel: "monstercat")
        XCTAssertTrue(session.hasCurrentPage)
        XCTAssertEqual(session.loadCount, 1)
        XCTAssertFalse(session.isPlaying)
        XCTAssertFalse(session.canPlay, "Loading alone is not a READY or PLAYING confirmation")
    }

    func testBridgeRejectsWrongOriginFramePortAndNonce() {
        let (session, nonce) = makeBridgeSession()
        for bad in [("http", "player.example.org", 443, true, nonce),
                    ("https", "evil.example.org", 443, true, nonce),
                    ("https", "player.example.org", 8443, true, nonce),
                    ("https", "player.example.org", 443, false, nonce),
                    ("https", "player.example.org", 443, true, "old-session")] {
            XCTAssertFalse(session.handleHostMessage(["event": "PLAYING", "session": bad.4], scheme: bad.0, host: bad.1, port: bad.2, isMainFrame: bad.3))
            XCTAssertFalse(session.isPlaying)
        }
        XCTAssertTrue(session.handleHostMessage(["event": "PLAYING", "session": nonce], scheme: "https", host: "PLAYER.EXAMPLE.ORG", port: 0, isMainFrame: true))
        XCTAssertTrue(session.isPlaying)
    }

    func testHTTPFailureSurvivesPolicyCancellationAndFinishedNavigation() {
        let (session, _) = makeBridgeSession()
        XCTAssertEqual(session.responsePolicy(statusCode: 404, isMainFrame: true), .cancel)
        let message = session.failure
        session.webView(session.webView, didFailProvisionalNavigation: nil, withError: NSError(domain: "WebKitErrorDomain", code: 102))
        session.webView(session.webView, didFinish: nil)
        XCTAssertEqual(session.failure, message)
        XCTAssertTrue(session.status.contains("404"))
    }

    func testOfflineOnlineAndBridgeStatusAreNotOverwrittenByDidFinish() {
        let (session, nonce) = makeBridgeSession()
        emit("OFFLINE", session: session, nonce: nonce)
        XCTAssertEqual(session.status, "This channel is offline.")
        emit("ONLINE", session: session, nonce: nonce)
        session.webView(session.webView, didFinish: nil)
        XCTAssertEqual(session.status, "Channel is live. Tap Play to watch.")
    }

    func testNavigationAcceptsOnlyTheConfiguredHTTPSOrigin() {
        let (session, _) = makeBridgeSession()
        XCTAssertTrue(session.allowsPlayerOrigin(URL(string: "https://PLAYER.EXAMPLE.ORG:443/player")!))
        for value in ["http://player.example.org", "https://player.example.org:8443", "https://player.example.org.evil.test", "https://user@player.example.org", "https://elsewhere.test", "https://player.example.org/another-page"] {
            XCTAssertFalse(session.allowsPlayerOrigin(URL(string: value)!), value)
        }
    }

    func testShrinkingVideoWaitsForMediaPauseAndDoesNotLoadAnotherChannel() async throws {
        var pauseCompletion: CheckedContinuation<Void, Never>?
        let (session, nonce) = makeBridgeSession(pause: { _ in
            await withCheckedContinuation { pauseCompletion = $0 }
        })
        emit("PLAYING", session: session, nonce: nonce)
        try await Task.sleep(for: .milliseconds(20))
        let shrinking = Task { await session.videoAreaChanged(fits: false, channel: "another_channel") }
        try await waitUntil { pauseCompletion != nil }
        XCTAssertTrue(session.isPlaying)
        pauseCompletion?.resume()
        await shrinking.value
        XCTAssertFalse(session.isPlaying)
        XCTAssertEqual(session.channel, "lofigirl")
        XCTAssertEqual(session.loadCount, 1)
        XCTAssertTrue(session.status.contains("too small"))
    }

    func testChannelSwitchWaitsForOldMediaPauseBeforeLoading() async throws {
        var pauseCompletion: CheckedContinuation<Void, Never>?
        var requests: [URLRequest] = []
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, request in requests.append(request) }, pauseMedia: { _ in await withCheckedContinuation { pauseCompletion = $0 } })
        session.open(channel: "lofigirl")
        let nonce = URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        emit("PLAYING", session: session, nonce: nonce)
        try await Task.sleep(for: .milliseconds(20))
        session.open(channel: "monstercat")
        try await waitUntil { pauseCompletion != nil }
        XCTAssertEqual(requests.count, 1)
        pauseCompletion?.resume()
        try await waitUntil { requests.count == 2 }
        XCTAssertFalse(session.isPlaying)
        XCTAssertEqual(session.channel, "monstercat")
    }

    func testPausingPendingSwitchAllowsSameChannelToLoadOnReopenAndIgnoresLateCompletion() async throws {
        var firstPause: CheckedContinuation<Void, Never>?
        var pauses = 0
        var requests: [URLRequest] = []
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, request in requests.append(request) }, pauseMedia: { _ in
                pauses += 1
                if pauses == 1 { await withCheckedContinuation { firstPause = $0 } }
            })
        session.open(channel: "lofigirl")
        let nonce = URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        emit("PLAYING", session: session, nonce: nonce)
        session.open(channel: "monstercat")
        try await waitUntil { firstPause != nil }
        await session.pause()
        XCTAssertTrue(session.needsLoad)
        XCTAssertFalse(session.hasCurrentPage)
        XCTAssertNotNil(session.failure)
        session.open(channel: "monstercat")
        try await waitUntil { requests.count == 2 }
        firstPause?.resume()
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(session.loadCount, 2)
        XCTAssertEqual(session.channel, "monstercat")
        XCTAssertTrue(session.hasCurrentPage)
        XCTAssertNil(session.failure)
        XCTAssertEqual(URLComponents(url: requests[1].url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "channel" }?.value, "monstercat")
    }

    func testLatePlaybackWhileVideoDoesNotFitIsPaused() async throws {
        var pauses = 0
        let (session, nonce) = makeBridgeSession(pause: { _ in pauses += 1 })
        await session.videoAreaChanged(fits: false, channel: "lofigirl")
        XCTAssertEqual(pauses, 1, "Buffering media must be paused before PLAYING arrives too")
        emit("PLAYING", session: session, nonce: nonce)
        try await waitUntil { pauses == 2 }
        XCTAssertFalse(session.isPlaying)
        await session.videoAreaChanged(fits: true, channel: "lofigirl")
        emit("PAUSE", session: session, nonce: nonce)
        XCTAssertEqual(session.status, "Video paused. Tap Play to continue.")
    }

    func testUnresponsivePauseShowsRetryWithoutClaimingStoppedMedia() async throws {
        var completion: CheckedContinuation<Void, Never>?
        var request: URLRequest?
        var pauses = 0
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, value in request = value }, pauseMedia: { _ in
                pauses += 1
                if pauses == 1 { await withCheckedContinuation { completion = $0 } }
            }, pauseTimeout: .milliseconds(30))
        session.open(channel: "lofigirl")
        let nonce = URLComponents(url: request!.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        emit("PLAYING", session: session, nonce: nonce)
        // The timeout is a transport failure; its completion must not claim
        // that still-unconfirmed WebKit media has paused.
        await session.pause()
        XCTAssertNotNil(completion)
        XCTAssertTrue(session.failure?.contains("did not respond") == true)
        XCTAssertTrue(session.isPlaying, "A timeout is not evidence that playback stopped")
        let failure = session.failure
        completion?.resume()
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(session.failure, failure)
        await session.pause()
        XCTAssertNil(session.failure, "A newer confirmed pause clears only its stale timeout")
        XCTAssertFalse(session.isPlaying)
    }

    func testConfirmedPauseAfterSwitchTimeoutKeepsRetryUntilChannelLoads() async throws {
        var firstCompletion: CheckedContinuation<Void, Never>?
        var pauses = 0
        var requests: [URLRequest] = []
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, request in requests.append(request) }, pauseMedia: { _ in
                pauses += 1
                if pauses == 1 { await withCheckedContinuation { firstCompletion = $0 } }
            }, pauseTimeout: .milliseconds(30))
        session.open(channel: "lofigirl")
        let nonce = URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        emit("PLAYING", session: session, nonce: nonce)
        session.open(channel: "monstercat")
        try await waitUntil { session.failure?.contains("did not respond") == true }
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(session.needsLoad)
        await session.pause()
        XCTAssertFalse(session.isPlaying)
        XCTAssertEqual(session.failure, "Channel opening paused. Retry to open this channel.")
        XCTAssertEqual(session.status, session.failure)
        XCTAssertFalse(session.hasCurrentPage)
        session.open(channel: "monstercat", forceReload: true)
        try await waitUntil { requests.count == 2 }
        XCTAssertTrue(session.hasCurrentPage)
        XCTAssertNil(session.failure)
        firstCompletion?.resume()
    }

    func testHostPauseClearsOnlyPauseTimeoutFailure() async throws {
        var completion: CheckedContinuation<Void, Never>?
        var request: URLRequest?
        var pauses = 0
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, value in request = value }, pauseMedia: { _ in
                pauses += 1
                if pauses == 1 { await withCheckedContinuation { completion = $0 } }
            }, pauseTimeout: .milliseconds(30))
        session.open(channel: "lofigirl")
        let nonce = URLComponents(url: request!.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        await session.pause()
        XCTAssertNotNil(session.failure)
        emit("PAUSE", session: session, nonce: nonce)
        XCTAssertNil(session.failure)
        completion?.resume()
        _ = session.responsePolicy(statusCode: 404, isMainFrame: true)
        let failure = session.failure
        emit("PAUSE", session: session, nonce: nonce)
        XCTAssertNotNil(failure)
        XCTAssertEqual(session.failure, failure)
    }

    func testOlderPauseTimeoutCannotOverwriteANewerSuccessfulPause() async throws {
        var firstCompletion: CheckedContinuation<Void, Never>?
        var pauses = 0
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, _ in }, pauseMedia: { _ in
                pauses += 1
                if pauses == 1 { await withCheckedContinuation { firstCompletion = $0 } }
            }, pauseTimeout: .milliseconds(250))
        session.open(channel: "lofigirl")
        let older = Task { await session.pause(reason: "Older request") }
        try await waitUntil { firstCompletion != nil }
        await session.pause(reason: "Newer request")
        await older.value
        XCTAssertNil(session.failure)
        XCTAssertEqual(session.status, "Newer request")
        firstCompletion?.resume()
    }

    func testLeavingWatchRejectsLatePlayback() async throws {
        var pauses = 0
        let (session, nonce) = makeBridgeSession(pause: { _ in pauses += 1 })
        let app = AppModel(player: session)
        let channel = WatchedChannel(channel: TwitchChannel(id: "lofi", broadcasterLogin: "lofigirl", displayName: "LofiGirl", gameName: "", title: "", thumbnailUrl: "", isLive: true))
        let appearance = app.watch(channel)
        app.leaveWatch(channel, appearance: appearance)
        emit("PLAYING", session: session, nonce: nonce)
        try await waitUntil { pauses > 0 }
        XCTAssertFalse(app.isWatching)
        XCTAssertFalse(session.isPlaying)
    }

    func testStaleSameChannelDisappearanceDoesNotHideTheReplacement() async throws {
        var pauses = 0
        let (session, nonce) = makeBridgeSession(pause: { _ in pauses += 1 })
        let app = AppModel(player: session)
        let channel = WatchedChannel(channel: TwitchChannel(id: "lofi", broadcasterLogin: "lofigirl", displayName: "LofiGirl", gameName: "", title: "", thumbnailUrl: "", isLive: true))
        let oldAppearance = app.watch(channel)
        let replacement = app.watch(channel)
        await session.videoAreaChanged(fits: true, channel: channel.login)
        app.leaveWatch(channel, appearance: oldAppearance)
        emit("PLAYING", session: session, nonce: nonce)
        XCTAssertTrue(app.isWatching)
        XCTAssertTrue(session.isPlaying)
        XCTAssertEqual(pauses, 0)
        app.leaveWatch(channel, appearance: replacement)
        try await waitUntil { pauses == 1 && !session.isPlaying }
        XCTAssertFalse(app.isWatching)
    }

    func testLeavingAndReopeningSameChannelRestoresFitAndUsefulPauseMessage() async throws {
        let (session, nonce) = makeBridgeSession()
        let app = AppModel(player: session)
        let channel = WatchedChannel(channel: TwitchChannel(id: "lofi", broadcasterLogin: "lofigirl", displayName: "LofiGirl", gameName: "", title: "", thumbnailUrl: "", isLive: true))
        let appearance = app.watch(channel)
        app.leaveWatch(channel, appearance: appearance)
        try await waitUntil { session.status == "Video paused. Tap Play to continue." }
        app.watch(channel)
        await session.videoAreaChanged(fits: true, channel: channel.login)
        XCTAssertTrue(app.isWatching)
        XCTAssertEqual(session.status, "Video paused. Tap Play to continue.")
        emit("PLAYING", session: session, nonce: nonce)
        XCTAssertTrue(session.isPlaying)
        XCTAssertEqual(session.loadCount, 1)
    }

    func testRefittingBeforePauseCompletionKeepsTheUpdatedExplanation() async throws {
        var completion: CheckedContinuation<Void, Never>?
        let (session, _) = makeBridgeSession(pause: { _ in await withCheckedContinuation { completion = $0 } })
        let shrinking = Task { await session.videoAreaChanged(fits: false, channel: "lofigirl") }
        try await waitUntil { completion != nil }
        await session.videoAreaChanged(fits: true, channel: "lofigirl")
        completion?.resume()
        await shrinking.value
        XCTAssertEqual(session.status, "Video paused. Tap Play to continue.")
    }

    func testAppDeactivationDoesNotPauseOrOverwriteOfflineAndFailureStatus() async throws {
        let events = AsyncStream<AudioDeactivation>.makeStream()
        let (session, nonce) = makeBridgeSession(events: events.stream)
        emit("PLAYING", session: session, nonce: nonce)
        events.continuation.yield(.app)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertTrue(session.isPlaying)
        XCTAssertEqual(session.status, "Video playing")
        emit("OFFLINE", session: session, nonce: nonce)
        events.continuation.yield(.app)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(session.status, "This channel is offline.")
        session.webViewWebContentProcessDidTerminate(session.webView)
        let failure = session.status
        events.continuation.yield(.system)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(session.status, failure)
        events.continuation.finish()
    }

    func testSystemDeactivationPausesOnlyAnActivePlayingSession() async throws {
        let events = AsyncStream<AudioDeactivation>.makeStream()
        let (session, nonce) = makeBridgeSession(events: events.stream)
        emit("PLAYING", session: session, nonce: nonce)
        events.continuation.yield(.system)
        try await waitUntil { session.status == "Audio interrupted. Tap Play to continue." }
        XCTAssertFalse(session.isPlaying)
        emit("PAUSE", session: session, nonce: nonce)
        XCTAssertEqual(session.status, "Audio interrupted. Tap Play to continue.")
        events.continuation.finish()
    }

    private func makeBridgeSession(events: AsyncStream<AudioDeactivation>? = nil,
                                   pause: @escaping @MainActor (WKWebView) async -> Void = { _ in },
                                   play: @escaping @MainActor (WKWebView, String) async throws -> Bool = { _, _ in true },
                                   pauseTimeout: Duration = .seconds(2)) -> (PlaybackSession, String) {
        var url: URL?
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://Player.Example.org/player"), probeEnabled: false),
            loadRequest: { _, request in url = request.url }, inactivityEvents: events, pauseMedia: pause, pauseTimeout: pauseTimeout, requestPlay: play)
        session.open(channel: "lofigirl")
        let nonce = URLComponents(url: url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        return (session, nonce)
    }

    private func emit(_ event: String, session: PlaybackSession, nonce: String) {
        XCTAssertTrue(session.handleHostMessage(["event": event, "session": nonce], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition() {
            if Date() > deadline { XCTFail("Player state did not settle"); throw URLError(.timedOut) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

}
