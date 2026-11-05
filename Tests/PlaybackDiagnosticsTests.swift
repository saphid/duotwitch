import XCTest
import JavaScriptCore
import WebKit
@testable import DuoTwitch

@MainActor
final class PlaybackDiagnosticsTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
        try await super.tearDown()
    }

    func testExportPersistsAcrossRecorderRecreationWithOrderedSubsecondRecords() async throws {
        let first = PlaybackDiagnostics(store: PlaybackDiagnosticStore(directory: directory))
        first.record("native.play.requested", ["allowed": .flag(true)])
        let initial = try await rows(first)
        let second = PlaybackDiagnostics(store: PlaybackDiagnosticStore(directory: directory))
        second.record("host.received", ["event": .text("PAUSE")])
        let result = try await rows(second)
        XCTAssertEqual(Array(result.prefix(initial.count)).map { $0["event"] as? String }, initial.map { $0["event"] as? String })
        XCTAssertEqual(result.map { $0["event"] as! String }, ["app.launch", "native.play.requested", "diagnostics.export", "app.launch", "host.received", "diagnostics.export"])
        XCTAssertNotEqual(result[0]["run"] as? String, result[3]["run"] as? String)
        XCTAssertEqual(result[2]["sequence"] as? Int, 3)
        let time = try XCTUnwrap(result[0]["wallTime"] as? Double)
        XCTAssertNotEqual(time, time.rounded())
        XCTAssertGreaterThan(result[0]["uptime"] as? Double ?? 0, 0)
        let values = try XCTUnwrap(result[1]["values"] as? [String: Any])
        XCTAssertEqual(values["allowed"] as? Bool, true)
    }

    func testRotationBoundsFilesAndPreservesCompleteChronologicalJSONLines() async throws {
        let store = PlaybackDiagnosticStore(directory: directory, maximumBytes: 1024, fileCount: 3)
        for sequence in 0..<80 {
            store.append(PlaybackDiagnosticRecord(run: "test", sequence: sequence, wallTime: Double(sequence),
                uptime: Double(sequence), event: "sample", values: ["padding": .text(String(repeating: "x", count: 80))]))
        }
        let result = try readRows(try await store.export())
        let sequences = result.map { $0["sequence"] as! Int }
        XCTAssertEqual(sequences, Array(sequences.first!...79))
        XCTAssertGreaterThan(sequences.first!, 0)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]).filter { $0.pathExtension == "jsonl" }
        XCTAssertEqual(files.count, 3)
        for file in files { XCTAssertLessThanOrEqual(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize!, 1024) }
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testWriteFailureCannotProduceAFalseSuccessfulExport() async throws {
        try Data("not a directory".utf8).write(to: directory)
        let recorder = PlaybackDiagnostics(store: PlaybackDiagnosticStore(directory: directory))
        do { _ = try await recorder.export(); XCTFail("Export must surface failed writes") }
        catch { /* Expected; the UI gives a generic retry message. */ }
    }

    func testUntrustedAndStaleMediaMessagesAreRejectedAndPayloadIsAllowlisted() async throws {
        let recorder = PlaybackDiagnostics(store: PlaybackDiagnosticStore(directory: directory))
        let (session, nonce) = makeSession(recorder)
        var payload: [String: Any] = ["session": nonce, "kind": "sample", "time": 0.4,
            "paused": true, "muted": true, "decoded": 12, "dropped": 0,
            "volume": true, "rate": Double.infinity, "width": Double.nan,
            "height": 1e20, "ready": "secret", "ended": 1,
            "url": "https://private.invalid/token", "token": "sensitive", "text": "chat message"]
        for (scheme, host, port) in [("http", "player.twitch.tv", 443), ("https", "evil.invalid", 443), ("https", "player.twitch.tv", 8443)] {
            XCTAssertFalse(session.handleDiagnosticMessage(payload, scheme: scheme, host: host, port: port))
        }
        payload["session"] = "old"
        XCTAssertFalse(session.handleDiagnosticMessage(payload, scheme: "https", host: "player.twitch.tv", port: 443))
        payload["session"] = nonce
        XCTAssertTrue(session.handleDiagnosticMessage(payload, scheme: "https", host: "player.twitch.tv", port: 443))
        XCTAssertFalse(session.isPlaying, "Telemetry must not control playback")
        let result = try await rows(recorder).filter { $0["event"] as? String == "media.observed" }
        XCTAssertEqual(result.count, 1)
        let values = try XCTUnwrap(result.first?["values"] as? [String: Any])
        XCTAssertEqual(values["time"] as? Double, 0.4)
        XCTAssertEqual(values["decoded"] as? Int, 12)
        XCTAssertEqual(values["paused"] as? Bool, true)
        for field in ["volume", "rate", "width", "height", "ended", "ready", "url", "token", "text"] { XCTAssertNil(values[field]) }
        XCTAssertEqual(values["hostReady"] as? Bool, false)
        let exported = try await recorder.export()
        XCTAssertFalse(try String(contentsOf: exported, encoding: .utf8).contains("sensitive"))
    }

    func testTraceDistinguishesAppLayoutPauseFromAProviderPause() async throws {
        let recorder = PlaybackDiagnostics(store: PlaybackDiagnosticStore(directory: directory))
        let (session, nonce) = makeSession(recorder)
        func emit(_ event: String) {
            XCTAssertTrue(session.handleHostMessage(["event": event, "session": nonce], scheme: "https", host: "player.example.org", port: 443, isMainFrame: true))
        }
        emit("READY")
        await session.play()
        emit("PLAYING")
        session.recordVideoGeometry(CGSize(width: 600, height: 299))
        await session.videoAreaChanged(fits: false, channel: "example")
        emit("PAUSE")
        let result = try await rows(recorder)
        let events = result.map { $0["event"] as! String }
        XCTAssertLessThan(try XCTUnwrap(events.firstIndex(of: "native.play.requested")), try XCTUnwrap(events.firstIndex(of: "native.pause.requested")))
        for name in ["native.pause.requested", "media.pause.begin", "media.pause.callback"] {
            let row = try XCTUnwrap(result.first { $0["event"] as? String == name })
            XCTAssertEqual((row["values"] as? [String: Any])?["cause"] as? String, "insufficientSpace")
        }
        let provider = result.filter { $0["event"] as? String == "host.received" }.last!
        XCTAssertEqual((provider["values"] as? [String: Any])?["event"] as? String, "PAUSE")
        XCTAssertFalse(session.isPlaying)
        XCTAssertEqual(session.loadCount, 1)
        XCTAssertEqual(session.webView.configuration.userContentController.userScripts.filter { $0.source.contains("playbackDiagnostic") }.count, 1)
    }

    func testTimedOutPauseAndLateCallbackHaveTheSameDiagnosticCommandID() async throws {
        let recorder = PlaybackDiagnostics(store: PlaybackDiagnosticStore(directory: directory))
        var completion: CheckedContinuation<Void, Never>?
        var returned = false
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, _ in }, inactivityEvents: AsyncStream { $0.finish() }, pauseMedia: { _ in
                await withCheckedContinuation { completion = $0 }
                returned = true
            }, pauseTimeout: .milliseconds(30), diagnostics: recorder)
        session.open(channel: "example")
        await session.pause()
        XCTAssertNotNil(session.failure)
        let before = try await rows(recorder)
        let begin = try XCTUnwrap(before.first { $0["event"] as? String == "media.pause.begin" }?["values"] as? [String: Any])
        let result = try XCTUnwrap(before.first { $0["event"] as? String == "media.pause.result" }?["values"] as? [String: Any])
        XCTAssertEqual(result["confirmed"] as? Bool, false)
        XCTAssertEqual(begin["command"] as? String, result["command"] as? String)
        XCTAssertFalse(before.contains { $0["event"] as? String == "media.pause.callback" })
        try XCTUnwrap(completion).resume()
        for _ in 0..<1000 where !returned { await Task.yield() }
        XCTAssertTrue(returned)
        let after = try await rows(recorder)
        let callback = try XCTUnwrap(after.first { $0["event"] as? String == "media.pause.callback" }?["values"] as? [String: Any])
        XCTAssertEqual(begin["command"] as? String, callback["command"] as? String)
    }

    func testPassiveScriptReportsSubsecondProgressEventsAndDetachmentWithoutMediaCommands() throws {
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript(Self.fixture)
        context.evaluateScript(PlaybackDiagnosticScript.source(session: "nonce'\\\""))
        XCTAssertNil(context.exception)
        context.evaluateScript("v.currentTime=0.25; v.frames=6; tick(); v.currentTime=0.5; v.frames=12; tick(); listeners.pause(); v.isConnected=false; tick();")
        XCTAssertNil(context.exception)
        let output = try XCTUnwrap(context.objectForKeyedSubscript("reports").toArray() as? [[String: Any]])
        XCTAssertEqual(output.map { $0["kind"] as! String }, ["observerReady", "attached", "sample", "sample", "pause", "detached"])
        XCTAssertEqual(output[3]["time"] as? Double, 0.5)
        XCTAssertEqual(output[3]["decoded"] as? Int, 12)
        XCTAssertEqual(output[0]["session"] as? String, "nonce'\\\"")
        XCTAssertTrue(context.objectForKeyedSubscript("cleared").toBool())
        XCTAssertTrue(context.objectForKeyedSubscript("removedVisibility").toBool())
        XCTAssertFalse(context.objectForKeyedSubscript("commandCalled").toBool())
    }

    func testReusedVideoRestartsSamplingWithoutDuplicatingListeners() throws {
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript(Self.fixture)
        context.evaluateScript(PlaybackDiagnosticScript.source(session: "nonce"))
        context.evaluateScript("v.isConnected=false; tick(); v.isConnected=true; documentListeners.loadstart({target:v}); v.currentTime=0.75; tick();")
        XCTAssertNil(context.exception)
        var output = try XCTUnwrap(context.objectForKeyedSubscript("reports").toArray() as? [[String: Any]])
        XCTAssertEqual(output.map { $0["kind"] as! String }, ["observerReady", "attached", "detached", "attached", "sample"])
        XCTAssertEqual(output.last?["time"] as? Double, 0.75)
        XCTAssertEqual(output[1]["video"] as? Int, output.last?["video"] as? Int)
        context.evaluateScript("documentListeners.loadstart({target:v}); v.isConnected=false; tick(); v.isConnected=true; listeners.playing(); tick();")
        output = try XCTUnwrap(context.objectForKeyedSubscript("reports").toArray() as? [[String: Any]])
        XCTAssertEqual(Array(output.suffix(4)).map { $0["kind"] as! String }, ["detached", "attached", "playing", "sample"])
        XCTAssertEqual(context.objectForKeyedSubscript("listenerCounts").objectForKeyedSubscript("pause").toInt32(), 1)
        XCTAssertEqual(context.objectForKeyedSubscript("intervalCount").toInt32(), 3)
        XCTAssertFalse(context.objectForKeyedSubscript("commandCalled").toBool())
    }

    func testPassiveScriptSkipsOtherOriginsAndFindsDynamicVideoOnce() throws {
        let context = try XCTUnwrap(JSContext())
        context.evaluateScript(Self.fixture + "location.hostname='elsewhere.invalid';")
        context.evaluateScript(PlaybackDiagnosticScript.source(session: "nonce"))
        XCTAssertEqual(context.objectForKeyedSubscript("reports").toArray()?.count, 0)
        context.evaluateScript("location.hostname='player.twitch.tv'; document.querySelectorAll=()=>[];")
        context.evaluateScript(PlaybackDiagnosticScript.source(session: "nonce"))
        context.evaluateScript("documentListeners.loadstart({target:v}); documentListeners.loadstart({target:v});")
        XCTAssertNil(context.exception)
        XCTAssertEqual(context.objectForKeyedSubscript("reports").toArray()?.count, 2)
    }

    private func makeSession(_ recorder: PlaybackDiagnostics) -> (PlaybackSession, String) {
        var url: URL?
        let session = PlaybackSession(configuration: PlayerConfiguration(hostURL: URL(string: "https://player.example.org/player"), probeEnabled: false),
            loadRequest: { _, request in url = request.url }, inactivityEvents: AsyncStream { $0.finish() }, pauseMedia: { _ in }, requestPlay: { _, _ in true }, diagnostics: recorder)
        session.open(channel: "example")
        let nonce = URLComponents(url: url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "session" }!.value!
        return (session, nonce)
    }

    private func rows(_ recorder: PlaybackDiagnostics) async throws -> [[String: Any]] { try readRows(try await recorder.export()) }
    private func readRows(_ url: URL) throws -> [[String: Any]] {
        try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map {
            try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
        }
    }

    private static let fixture = """
    var reports=[], listeners={}, listenerCounts={}, documentListeners={}, tick, intervalCount=0, cleared=false, removedVisibility=false, commandCalled=false;
    var location={protocol:'https:',hostname:'player.twitch.tv',port:''};
    class HTMLVideoElement {}
    var v=new HTMLVideoElement();
    Object.assign(v,{currentTime:0,paused:true,ended:false,muted:true,volume:0,readyState:4,networkState:2,
      playbackRate:1,videoWidth:1280,videoHeight:720,isConnected:true,frames:0,
      addEventListener:(k,f)=>{listeners[k]=f;listenerCounts[k]=(listenerCounts[k]||0)+1}, getVideoPlaybackQuality:()=>({totalVideoFrames:v.frames,droppedVideoFrames:0}),
      play:()=>{commandCalled=true}, pause:()=>{commandCalled=true}});
    var document={hidden:false, querySelectorAll:()=>[v], addEventListener:(k,f)=>documentListeners[k]=f,
      removeEventListener:(k,f)=>{removedVisibility=(k==='visibilitychange')}};
    var window={webkit:{messageHandlers:{playbackDiagnostic:{postMessage:p=>reports.push(p)}}},addEventListener:()=>{}};
    function setInterval(f,ms){if(ms!==250)throw Error('not subsecond');tick=f;return ++intervalCount}
    function clearInterval(){cleared=true}
    """
}
