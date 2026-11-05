import AVFoundation
import Observation
import WebKit
import UIKit
import OSLog

/// The watch session owns this one browser. Layout changes only move its host;
/// they must never replace the browser or reload the current channel.
@MainActor @Observable
final class PlaybackSession: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    @ObservationIgnored let diagnostics: PlaybackDiagnostics
    private static let log = Logger(subsystem: "com.saphid.duotwitch", category: "Playback")
    private(set) var channel = ""
    private(set) var status = "Choose a channel"
    private(set) var mediaState = "No video element reported"
    private(set) var presentationMode = "inline"
    private(set) var probeResult = "Not tested"
    private(set) var hostEvent = "No host event"
    private(set) var loadCount = 0
    private(set) var pipSupported = false
    private(set) var isPlaying = false
    private(set) var isRequestingPlay = false
    private(set) var failure: String?
    private(set) var needsLoad = true
    var hasCurrentPage: Bool { !needsLoad && !channel.isEmpty }
    @ObservationIgnored private let configuration: PlayerConfiguration
    @ObservationIgnored private var bridgeSession = UUID().uuidString
    @ObservationIgnored private let loadRequest: @MainActor (WKWebView, URLRequest) -> Void
    @ObservationIgnored private let pauseMedia: @MainActor (WKWebView) async -> Void
    @ObservationIgnored private let requestPlay: @MainActor (WKWebView, String) async throws -> Bool
    @ObservationIgnored private let pauseTimeout: Duration
    private var videoFits = true
    private var playerReady = false
    private var pendingPauses = 0
    var canPlay: Bool {
        configuration.hostURL != nil && hasCurrentPage && playerReady && videoFits
            && !isPlaying && !isRequestingPlay && pendingPauses == 0 && failure == nil
    }
    private static let insufficientSpace = "Video paused because this view is too small. Expand it to continue."
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var pauseReason: String?
    @ObservationIgnored private var pauseTransaction = UUID()
    @ObservationIgnored private var pauseTimedOut = false
    @ObservationIgnored private var interruptionTask: Task<Void, Never>?
    @ObservationIgnored private var diagnosticTasks: [Task<Void, Never>] = []
    @ObservationIgnored private(set) var webView: WKWebView!
    var isConfigured: Bool { configuration.hostURL != nil || configuration.probeEnabled }

    init(configuration: PlayerConfiguration = .current,
         loadRequest: (@MainActor (WKWebView, URLRequest) -> Void)? = nil,
         inactivityEvents: AsyncStream<AudioDeactivation>? = nil,
         pauseMedia: (@MainActor (WKWebView) async -> Void)? = nil,
         pauseTimeout: Duration = .seconds(2),
         requestPlay: (@MainActor (WKWebView, String) async throws -> Bool)? = nil,
         diagnostics: PlaybackDiagnostics? = nil) {
        self.diagnostics = diagnostics ?? .shared
        self.configuration = configuration
        self.loadRequest = loadRequest ?? { view, request in view.load(request) }
        self.pauseMedia = pauseMedia ?? { view in await view.pauseAllMediaPlayback() }
        self.pauseTimeout = pauseTimeout
        self.requestPlay = requestPlay ?? { view, session in
            let result = try await view.callAsyncJavaScript("""
                if (new URL(location.href).searchParams.get('session') !== session ||
                    !window.duoPlayer || typeof window.duoPlayer.play !== 'function') return false;
                window.duoPlayer.play();
                return true;
                """, arguments: ["session": session], in: nil, contentWorld: .page)
            return result as? Bool == true
        }
        super.init()
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(WeakMediaHandler(self), name: "mediaState")
        config.userContentController.add(WeakMediaHandler(self), name: "playbackDiagnostic")
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
        recordDiagnostic("player.created")
        observeDiagnosticNotifications()
        let events = inactivityEvents ?? AudioPlaybackSession.inactivityEvents()
        interruptionTask = Task { [weak self] in
            for await source in events {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                Self.log.info("Audio event: \(String(describing: source), privacy: .public); playing=\(self.isPlaying)")
                self.recordDiagnostic("audio.deactivation", values: ["source": .text(String(describing: source))])
                if source == .systemIdle { continue }
                guard source == .system, self.isPlaying, self.failure == nil else { continue }
                await self.pause(reason: "Audio interrupted. Tap Play to continue.")
            }
        }
    }

    deinit { interruptionTask?.cancel(); loadTask?.cancel(); diagnosticTasks.forEach { $0.cancel() } }

    func open(channel input: String, forceReload: Bool = false) {
        guard let login = Self.validChannel(input) else {
            status = "Enter a Twitch channel name using letters, numbers, or underscores."
            return
        }
        recordDiagnostic("channel.open", values: ["forceReload": .flag(forceReload), "sameChannel": .flag(channel == login)])
        guard forceReload || channel != login || needsLoad else { return }
        let mustPausePrevious = isPlaying || loadTask != nil
        loadTask?.cancel()
        loadTask = nil
        channel = login
        needsLoad = true
        playerReady = false
        isRequestingPlay = false
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
                let paused = await self.pauseWithDeadline(cause: "channelSwitch")
                guard !Task.isCancelled, self.bridgeSession == ticket else { return }
                guard paused else {
                    self.loadTask = nil
                    self.recordPauseTimeout()
                    return
                }
                self.setPlaying(false)
                self.needsLoad = false
                self.loadCount += 1
                self.sendLoad(request)
                self.loadTask = nil
            }
        } else {
            needsLoad = false
            loadCount += 1
            sendLoad(request)
        }
    }

    private func setPlaying(_ playing: Bool) {
        recordDiagnostic("playback.state", values: ["requestedPlaying": .flag(playing)])
        // The WKWebView media process owns audio. Activating or deactivating a
        // second AVAudioSession here can interrupt a video that just started.
        isPlaying = playing
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

    /// Requests playback through Twitch's public embed API. Only PLAYING
    /// confirms success; WebKit owns audio, not a second native session.
    func play() async {
        let command = UUID().uuidString
        recordDiagnostic("native.play.requested", values: ["command": .text(command), "allowed": .flag(canPlay)])
        guard canPlay else { return }
        Self.log.info("Native Play requested")
        let ticket = bridgeSession
        let pauseTicket = pauseTransaction
        let event = hostEvent
        isRequestingPlay = true
        status = "Starting video…"
        defer { if bridgeSession == ticket { isRequestingPlay = false } }
        let view = webView!
        let request = requestPlay
        let accepted = await mediaCommandWithDeadline { (try? await request(view, ticket)) == true }
        recordDiagnostic("native.play.result", values: ["command": .text(command), "accepted": .flag(accepted), "stale": .flag(bridgeSession != ticket || pauseTransaction != pauseTicket)])
        guard bridgeSession == ticket, pauseTransaction == pauseTicket, videoFits,
              failure == nil, hostEvent == event, !isPlaying else { return }
        if !accepted { status = "Could not start video. Try Play again or use the Twitch player." }
    }

    func pause(reason: String = "Paused") async {
        // Keep Play disabled through both the WebKit callback and this
        // request's state updates, so an older Pause cannot undo a new Play.
        recordDiagnostic("native.pause.requested", values: ["cause": .text(Self.pauseCause(reason))])
        Self.log.info("Native Pause requested: \(reason, privacy: .public)")
        pendingPauses += 1
        defer { pendingPauses -= 1 }
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
        let paused = await pauseWithDeadline(cause: Self.pauseCause(reason))
        recordDiagnostic("native.pause.result", values: ["confirmed": .flag(paused), "stale": .flag(bridgeSession != ticket || pauseTransaction != transaction)])
        guard bridgeSession == ticket, pauseTransaction == transaction else { return }
        guard paused else {
            Self.log.info("Native Pause timed out")
            recordPauseTimeout()
            return
        }
        setPlaying(false)
        clearPauseTimeout()
        if failure == nil { status = pauseReason ?? reason }
    }

    func hideVideo() {
        recordDiagnostic("video.hidden")
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
        recordDiagnostic("video.fit", values: ["newFits": .flag(fits)])
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

    private func pauseWithDeadline(cause: String) async -> Bool {
        let command = UUID().uuidString
        recordDiagnostic("media.pause.begin", values: ["command": .text(command), "cause": .text(cause)])
        let view = webView!
        let pause = pauseMedia
        pendingPauses += 1
        let confirmed = await mediaCommandWithDeadline {
            // Timing out stops waiting; it does not cancel WebKit's command.
            // A new Play must still wait for that command's actual callback.
            defer { self.pendingPauses -= 1 }
            await pause(view)
            self.recordDiagnostic("media.pause.callback", values: ["command": .text(command), "cause": .text(cause)])
            return true
        }
        recordDiagnostic("media.pause.result", values: ["command": .text(command), "confirmed": .flag(confirmed)])
        return confirmed
    }

    private func mediaCommandWithDeadline(_ command: @escaping @MainActor () async -> Bool) async -> Bool {
        let deadline = pauseTimeout
        return await withCheckedContinuation { continuation in
            let result = MediaCommandResult(continuation)
            let operation = Task { result.finish(await command()) }
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
        recordDiagnostic("web.navigation.finished")
        if failure == nil && status == "Loading Twitch player…" {
            status = "Twitch player loaded. Tap its Play control to start."
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        recordDiagnosticError("web.navigation.provisionalFailed", error: error)
        guard failure == nil, (error as NSError).code != NSURLErrorCancelled else { return }
        fail("Could not load Twitch: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        recordDiagnosticError("web.navigation.failed", error: error)
        guard failure == nil, (error as NSError).code != NSURLErrorCancelled else { return }
        fail("Player connection failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        recordDiagnostic("web.process.terminated")
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
        if message.name == "playbackDiagnostic" {
            handleDiagnosticMessage(message.body, scheme: origin.protocol, host: origin.host, port: origin.port)
            return
        }
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
        guard ["READY", "PLAYING", "PAUSE", "ONLINE", "OFFLINE", "PLAYBACK_BLOCKED", "ENDED"].contains(event) else { return false }
        recordDiagnostic("host.received", values: ["event": .text(event)])
        switch event {
        case "READY": playerReady = true; status = "Ready. Tap Play to watch."
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
        Self.log.info("Host event: \(event, privacy: .public); playing=\(self.isPlaying); fits=\(self.videoFits)")
        hostEvent = event
        recordDiagnostic("host.applied", values: ["event": .text(event)])
        return true
    }

    private func sendLoad(_ request: URLRequest) {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(WKUserScript(source: PlaybackDiagnosticScript.source(session: bridgeSession),
            injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        #if DEBUG
        if configuration.probeEnabled {
            controller.addUserScript(WKUserScript(source: Self.observerScript,
                injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        }
        #endif
        recordDiagnostic("web.load.sent")
        loadRequest(webView, request)
    }

    func recordDiagnostic(_ event: String, values: [String: PlaybackDiagnosticValue] = [:]) {
        var state: [String: PlaybackDiagnosticValue] = [
            "playerSession": .text(bridgeSession), "playing": .flag(isPlaying),
            "requestingPlay": .flag(isRequestingPlay), "audioOwner": .text("webKit"),
            "fits": .flag(videoFits), "hostReady": .flag(playerReady), "needsLoad": .flag(needsLoad),
            "pendingPauses": .number(Double(pendingPauses)), "loadCount": .number(Double(loadCount)),
            "failed": .flag(failure != nil), "appState": .number(Double(UIApplication.shared.applicationState.rawValue))
        ]
        if let view = webView {
            state["windowAttached"] = .flag(view.window != nil)
            state["webWidth"] = .number(Double(view.bounds.width))
            state["webHeight"] = .number(Double(view.bounds.height))
        }
        state.merge(values) { _, new in new }
        diagnostics.record(event, state)
    }

    func recordVideoGeometry(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite else { return }
        recordDiagnostic("video.geometry", values: ["width": .number(Double(size.width)), "height": .number(Double(size.height))])
    }

    private static func pauseCause(_ reason: String) -> String {
        switch reason {
        case "Paused": return "user"
        case insufficientSpace: return "insufficientSpace"
        case "Video paused. Tap Play to continue.": return "watchHidden"
        case "Audio interrupted. Tap Play to continue.": return "audioInterruption"
        default: return "other" // Never write arbitrary reason/error text.
        }
    }

    private func recordDiagnosticError(_ event: String, error: Error) {
        let value = error as NSError
        let domain = [NSURLErrorDomain, WKErrorDomain, AVFoundationErrorDomain, NSOSStatusErrorDomain].contains(value.domain) ? value.domain : "other"
        recordDiagnostic(event, values: ["errorDomain": .text(domain), "errorCode": .number(Double(value.code))])
    }

    @discardableResult
    func handleDiagnosticMessage(_ body: Any, scheme: String, host: String, port: Int) -> Bool {
        guard scheme == "https", host == "player.twitch.tv", [0, 443].contains(port),
              let data = body as? [String: Any], data["session"] as? String == bridgeSession,
              let kind = data["kind"] as? String,
              ["observerReady", "attached", "detached", "sample", "play", "playing", "pause", "waiting", "stalled", "ended", "error", "emptied", "loadedmetadata", "visibility"].contains(kind) else { return false }
        var fields: [String: PlaybackDiagnosticValue] = ["kind": .text(kind)]
        for key in ["video", "time", "volume", "ready", "network", "rate", "width", "height", "error", "decoded", "dropped"] {
            if let number = data[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
               number.doubleValue.isFinite, abs(number.doubleValue) <= 1e12 { fields[key] = .number(number.doubleValue) }
        }
        for key in ["paused", "ended", "muted", "hidden"] {
            if let number = data[key] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { fields[key] = .flag(number.boolValue) }
        }
        recordDiagnostic("media.observed", values: fields)
        return true // Diagnostic data never changes playback state.
    }

    private func observeDiagnosticNotifications() {
        let names: [Notification.Name] = [AVAudioSession.didBecomeInactiveNotification,
            AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
            AVAudioSession.mediaServicesWereLostNotification, AVAudioSession.mediaServicesWereResetNotification]
        diagnosticTasks = names.map { name in
            Task { [weak self] in
                for await note in NotificationCenter.default.notifications(named: name) {
                    guard !Task.isCancelled, let self else { return }
                    var fields: [String: PlaybackDiagnosticValue] = [:]
                    if let context = note.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext {
                        fields["systemSource"] = .flag(context.source == .system)
                        fields["hasInterruption"] = .flag(context.interruptionContext != nil)
                        if let interruption = context.interruptionContext { fields["reason"] = .number(Double(interruption.reason.rawValue)) }
                    }
                    for (key, field) in [(AVAudioSessionInterruptionTypeKey, "type"), (AVAudioSessionInterruptionReasonKey, "reason"), (AVAudioSessionRouteChangeReasonKey, "routeReason")] {
                        if let value = note.userInfo?[key] as? NSNumber { fields[field] = .number(value.doubleValue) }
                    }
                    let audio = AVAudioSession.sharedInstance()
                    fields["category"] = .text(audio.category.rawValue)
                    fields["mode"] = .text(audio.mode.rawValue)
                    fields["outputPorts"] = .text(audio.currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ","))
                    self.recordDiagnostic("audio.notification", values: fields.merging(["notification": .text(name.rawValue)]) { _, new in new })
                }
            }
        }
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

/// A WebKit callback may arrive after the deadline. Resolve exactly once.
/// Command dispatch never confirms that media has stopped on a timeout.
@MainActor
private final class MediaCommandResult {
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
