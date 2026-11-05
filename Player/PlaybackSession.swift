import AVFAudio
import Observation
import WebKit
import UIKit

/// The watch session owns this one browser. Layout changes only move its host;
/// they must never replace the browser or reload the current channel.
@MainActor @Observable
final class PlaybackSession: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private(set) var channel = ""
    private(set) var status = "Choose a channel"
    private(set) var mediaState = "No video element reported"
    private(set) var presentationMode = "inline"
    private(set) var probeResult = "Not tested"
    private(set) var hostEvent = "No host event"
    private(set) var loadCount = 0
    private(set) var pipSupported = false
    private(set) var isPlaying = false
    private(set) var audioWarning: String?
    private(set) var failure: String?
    private(set) var needsLoad = true
    var hasCurrentPage: Bool { !needsLoad && !channel.isEmpty }
    @ObservationIgnored private let configuration: PlayerConfiguration
    @ObservationIgnored private var bridgeSession = UUID().uuidString
    @ObservationIgnored private let loadRequest: @MainActor (WKWebView, URLRequest) -> Void
    @ObservationIgnored private let activateAudio: @MainActor () async throws -> Void
    @ObservationIgnored private let deactivateAudio: @MainActor () async throws -> Void
    @ObservationIgnored private let pauseMedia: @MainActor (WKWebView) async -> Void
    @ObservationIgnored private let pauseTimeout: Duration
    @ObservationIgnored private var videoFits = true
    private static let insufficientSpace = "Video paused because this view is too small. Expand it to continue."
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var pauseReason: String?
    @ObservationIgnored private var pauseTransaction = UUID()
    @ObservationIgnored private var pauseTimedOut = false
    @ObservationIgnored private var interruptionTask: Task<Void, Never>?
    @ObservationIgnored private var audioTask: Task<Void, Never>?
    @ObservationIgnored private var audioReady = false
    @ObservationIgnored private(set) var webView: WKWebView!
    var isConfigured: Bool { configuration.hostURL != nil || configuration.probeEnabled }

    init(configuration: PlayerConfiguration = .current,
         loadRequest: (@MainActor (WKWebView, URLRequest) -> Void)? = nil,
         activateAudio: (@MainActor () async throws -> Void)? = nil,
         deactivateAudio: (@MainActor () async throws -> Void)? = nil,
         inactivityEvents: AsyncStream<AudioDeactivation>? = nil,
         pauseMedia: (@MainActor (WKWebView) async -> Void)? = nil,
         pauseTimeout: Duration = .seconds(2)) {
        self.configuration = configuration
        self.loadRequest = loadRequest ?? { view, request in view.load(request) }
        self.activateAudio = activateAudio ?? { try await AudioPlaybackSession.activate() }
        self.deactivateAudio = deactivateAudio ?? { try await AudioPlaybackSession.deactivate() }
        self.pauseMedia = pauseMedia ?? { view in await view.pauseAllMediaPlayback() }
        self.pauseTimeout = pauseTimeout
        super.init()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(WeakMediaHandler(self), name: "mediaState")
        #if DEBUG
        if configuration.probeEnabled {
            config.userContentController.addUserScript(WKUserScript(
                source: Self.observerScript, injectionTime: .atDocumentEnd,
                forMainFrameOnly: false))
        }
        #endif
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.accessibilityIdentifier = "twitchPlayer"
        let events = inactivityEvents ?? AudioPlaybackSession.inactivityEvents()
        interruptionTask = Task { [weak self] in
            for await source in events {
                guard !Task.isCancelled else { return }
                guard source == .system, let self, self.audioReady, self.isPlaying, self.failure == nil else { continue }
                self.audioReady = false // The system already deactivated it.
                await self.pause(reason: "Audio interrupted. Tap Play to continue.")
            }
        }
    }

    deinit { interruptionTask?.cancel(); loadTask?.cancel() }

    func open(channel input: String, forceReload: Bool = false) {
        guard let login = Self.validChannel(input) else {
            status = "Enter a Twitch channel name using letters, numbers, or underscores."
            return
        }
        guard forceReload || channel != login || needsLoad else { return }
        let mustPausePrevious = isPlaying || audioReady || loadTask != nil
        loadTask?.cancel()
        loadTask = nil
        channel = login
        needsLoad = true
        pauseReason = nil
        failure = nil
        pauseTimedOut = false
        hostEvent = "Loading host"
        pipSupported = false
        status = "Loading Twitch player…"
        let target: URL
        if let host = configuration.hostURL { target = host }
        else if configuration.probeEnabled { target = URL(string: "https://player.twitch.tv/")! }
        else {
            status = "Playback is not configured in this development build yet."
            return
        }
        bridgeSession = UUID().uuidString
        var url = URLComponents(url: target, resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "channel", value: login), URLQueryItem(name: "session", value: bridgeSession)]
        if configuration.probeEnabled {
            url.queryItems! += [URLQueryItem(name: "parent", value: "player.twitch.tv"),
                               URLQueryItem(name: "autoplay", value: "false"),
                               URLQueryItem(name: "muted", value: "false")]
        }
        let request = URLRequest(url: url.url!)
        if mustPausePrevious {
            let ticket = bridgeSession
            loadTask = Task { [weak self] in
                guard let self else { return }
                let paused = await self.pauseWithDeadline()
                guard !Task.isCancelled, self.bridgeSession == ticket else { return }
                guard paused else {
                    self.loadTask = nil
                    self.recordPauseTimeout()
                    return
                }
                self.setPlaying(false)
                self.needsLoad = false
                self.loadCount += 1
                self.loadRequest(self.webView, request)
                self.loadTask = nil
            }
        } else {
            needsLoad = false
            loadCount += 1
            loadRequest(webView, request)
        }
    }

    private func setPlaying(_ playing: Bool) {
        isPlaying = playing
        guard audioTask == nil else { return }
        audioTask = Task { [weak self] in
            guard let self else { return }
            // Serialize transitions, including a Pause arriving during activation.
            while self.audioReady != self.isPlaying {
                let activating = self.isPlaying
                do {
                    if activating { try await self.activateAudio() }
                    else { try await self.deactivateAudio() }
                    self.audioReady = activating
                    self.audioWarning = nil
                } catch {
                    self.audioWarning = "Audio could not be updated. Try the player again."
                    break
                }
            }
            self.audioTask = nil
        }
    }

    private func fail(_ message: String) {
        pauseTimedOut = false
        failure = message
        status = message
        let ticket = bridgeSession
        Task { [weak self] in
            guard let self, self.bridgeSession == ticket else { return }
            await self.pause()
        }
    }

    static func validChannel(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (1...25).contains(value.count),
              value.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }) else { return nil }
        return value
    }

    func pause(reason: String = "Paused") async {
        let ticket = bridgeSession
        let transaction = UUID()
        pauseTransaction = transaction
        if loadTask != nil {
            needsLoad = true
            if failure == nil { failure = "Channel opening paused. Retry to open this channel."; status = failure! }
        }
        loadTask?.cancel()
        loadTask = nil
        pauseReason = reason
        // Use WebKit's public pause API without relying on the host script.
        // Cross-origin/offscreen behavior still requires runtime verification.
        let paused = await pauseWithDeadline()
        guard bridgeSession == ticket, pauseTransaction == transaction else { return }
        guard paused else {
            recordPauseTimeout()
            return
        }
        setPlaying(false)
        clearPauseTimeout()
        if failure == nil { status = pauseReason ?? reason }
    }

    func hideVideo() {
        videoFits = false
        let ticket = bridgeSession
        Task { [weak self] in
            guard let self, !self.videoFits, self.bridgeSession == ticket else { return }
            await self.pause(reason: "Video paused. Tap Play to continue.")
        }
    }

    private func recordPauseTimeout() {
        guard failure == nil || pauseTimedOut else { return }
        pauseTimedOut = true
        failure = "The player did not respond to Pause. Retry to reconnect."
        status = failure!
    }

    private func clearPauseTimeout() {
        guard pauseTimedOut else { return }
        pauseTimedOut = false
        failure = needsLoad ? "Channel opening paused. Retry to open this channel." : nil
        if let failure { status = failure }
    }

    func videoAreaChanged(fits: Bool, channel: String) async {
        videoFits = fits
        if fits && isConfigured {
            if pauseReason == Self.insufficientSpace {
                pauseReason = "Video paused. Tap Play to continue."
                if failure == nil { status = pauseReason! }
            }
            open(channel: channel)
        } else {
            await pause(reason: Self.insufficientSpace)
        }
    }

    private func pauseWithDeadline() async -> Bool {
        let view = webView!
        let pause = pauseMedia
        let deadline = pauseTimeout
        return await withCheckedContinuation { continuation in
            let result = MediaPauseResult(continuation)
            let operation = Task { await pause(view); result.finish(true) }
            let timer = Task {
                do { try await Task.sleep(for: deadline) } catch { return }
                result.finish(false)
            }
            result.onFinish = { operation.cancel(); timer.cancel() }
        }
    }

    func inspectMedia() async {
        #if DEBUG
        guard configuration.probeEnabled else { return }
        do {
            let result = try await webView.evaluateJavaScript("""
            (() => { const v = document.querySelector('video');
              if (!v) return JSON.stringify({video:false, title:document.title});
              return JSON.stringify({video:true, paused:v.paused, ready:v.readyState,
                width:v.videoWidth, height:v.videoHeight, time:v.currentTime,
                mode:v.webkitPresentationMode || 'inline',
                pip:!!(v.webkitSupportsPresentationMode && v.webkitSupportsPresentationMode('picture-in-picture')),
                error:v.error ? v.error.code : null}); })()
            """)
            probeResult = result as? String ?? "No media information returned"
        } catch { probeResult = "Media inspection failed: \(error.localizedDescription)" }
        #endif
    }

    func requestPictureInPicture() async {
        #if DEBUG
        guard configuration.probeEnabled else { return }
        do {
            let result = try await webView.evaluateJavaScript("""
            (() => { const v = document.querySelector('video');
              if (!v) return 'No video element';
              if (!v.webkitSupportsPresentationMode || !v.webkitSupportsPresentationMode('picture-in-picture'))
                return 'Picture in Picture is unavailable for this video';
              v.webkitSetPresentationMode('picture-in-picture');
              return 'Requested Picture in Picture'; })()
            """)
            probeResult = result as? String ?? "No result returned"
        } catch { probeResult = "Picture in Picture failed: \(error.localizedDescription)" }
        #endif
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if failure == nil && status == "Loading Twitch player…" {
            status = "Twitch player loaded. Tap its Play control to start."
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard failure == nil, (error as NSError).code != NSURLErrorCancelled else { return }
        fail("Could not load Twitch: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard failure == nil, (error as NSError).code != NSURLErrorCancelled else { return }
        fail("Player connection failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        fail("The video player stopped. Retry to reconnect.")
    }

    func allowsPlayerOrigin(_ url: URL) -> Bool {
        let expected = configuration.hostURL ?? (configuration.probeEnabled ? URL(string: "https://player.twitch.tv/") : nil)
        guard let expected else { return false }
        return url.scheme == "https" && url.host?.lowercased() == expected.host?.lowercased()
            && (url.port ?? 443) == (expected.port ?? 443) && url.user == nil && url.password == nil
            && (url.path.isEmpty ? "/" : url.path) == (expected.path.isEmpty ? "/" : expected.path)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.targetFrame?.isMainFrame != false else { decisionHandler(.allow); return }
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if allowsPlayerOrigin(url) && navigationAction.targetFrame != nil { decisionHandler(.allow) }
        else {
            decisionHandler(.cancel)
            if navigationAction.navigationType == .linkActivated { openExternal(url) }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
        let statusCode = (navigationResponse.response as? HTTPURLResponse)?.statusCode
        decisionHandler(responsePolicy(statusCode: statusCode, isMainFrame: navigationResponse.isForMainFrame))
    }

    func responsePolicy(statusCode: Int?, isMainFrame: Bool) -> WKNavigationResponsePolicy {
        if isMainFrame, let statusCode, !(200..<300).contains(statusCode) {
            fail("The video service returned an error (\(statusCode)). Retry to reconnect.")
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { openExternal(url) }
        return nil
    }

    private func openExternal(_ url: URL) {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return }
        UIApplication.shared.open(url)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let origin = message.frameInfo.securityOrigin
        if handleHostMessage(message.body, scheme: origin.protocol, host: origin.host,
                             port: origin.port, isMainFrame: message.frameInfo.isMainFrame) { return }
        #if DEBUG
        guard configuration.probeEnabled else { return }
        guard message.frameInfo.securityOrigin.host == "player.twitch.tv",
              let data = message.body as? [String: Any],
              let event = data["event"] as? String else { return }
        mediaState = event
        pipSupported = data["pip"] as? Bool ?? false
        presentationMode = data["mode"] as? String ?? "inline"
        setPlaying(data["playing"] as? Bool ?? false)
        if isPlaying { status = "Video playing" }
        #endif
    }

    @discardableResult
    func handleHostMessage(_ body: Any, scheme: String, host: String, port: Int, isMainFrame: Bool) -> Bool {
        guard let expected = configuration.hostURL, isMainFrame,
              scheme == "https", host.lowercased() == expected.host?.lowercased(),
              (port == 0 ? 443 : port) == (expected.port ?? 443),
              let data = body as? [String: Any], data["session"] as? String == bridgeSession,
              let event = data["event"] as? String else { return false }
        switch event {
        case "READY": status = "Ready. Tap Play in the Twitch player."
        case "PLAYING":
            guard videoFits else {
                Task { [weak self] in
                    guard let self, !self.videoFits else { return }
                    await self.pause(reason: Self.insufficientSpace)
                }
                return true
            }
            pauseReason = nil; failure = nil; status = "Video playing"; setPlaying(true)
        case "PAUSE": clearPauseTimeout(); if failure == nil { status = pauseReason ?? "Paused" }; setPlaying(false)
        case "ONLINE": status = "Channel is live. Tap Play to watch."
        case "OFFLINE": status = "This channel is offline."; setPlaying(false)
        case "PLAYBACK_BLOCKED": status = "Tap Play in the Twitch player to start."
        case "ENDED": status = "This broadcast has ended."; setPlaying(false)
        default: return false
        }
        hostEvent = event
        return true
    }

    #if DEBUG
    private static let observerScript = """
    (() => {
      const attached = new WeakSet();
      const inspect = () => document.querySelectorAll('video').forEach(v => {
        if (attached.has(v)) return; attached.add(v);
        const report = event => window.webkit.messageHandlers.mediaState.postMessage({
          event, playing:!v.paused && v.readyState > 2,
          pip:!!(v.webkitSupportsPresentationMode && v.webkitSupportsPresentationMode('picture-in-picture')),
          mode:v.webkitPresentationMode || 'inline'});
        ['playing','pause','waiting','error','loadedmetadata','webkitpresentationmodechanged']
          .forEach(event => v.addEventListener(event, () => report(event)));
        report('video-attached');
      });
      inspect(); new MutationObserver(inspect).observe(document.documentElement, {childList:true,subtree:true});
    })();
    """
    #endif
}

/// A WebKit callback may arrive after the deadline. Resolve exactly once;
/// the timeout never releases audio without confirmation that media paused.
@MainActor
private final class MediaPauseResult {
    private var continuation: CheckedContinuation<Bool, Never>?
    var onFinish: (() -> Void)?
    init(_ continuation: CheckedContinuation<Bool, Never>) { self.continuation = continuation }
    func finish(_ value: Bool) {
        guard let continuation else { return }
        self.continuation = nil
        let cleanup = onFinish
        onFinish = nil
        continuation.resume(returning: value)
        cleanup?()
    }
}

/// WKUserContentController retains its handler; the session owns the controller.
/// Break that cycle so a closed watch session releases the player process.
@MainActor
private final class WeakMediaHandler: NSObject, WKScriptMessageHandler {
    weak var target: PlaybackSession?
    init(_ target: PlaybackSession) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
