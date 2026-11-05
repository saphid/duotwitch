import Foundation
import XCTest
#if canImport(DuoTwitch)
@testable import DuoTwitch
#else
@testable import PlaybackDiagnosticsCore
#endif

final class PlaybackDiagnosticUploadTests: XCTestCase {
    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var value = Date(timeIntervalSince1970: 1_794_000_000)
        func now() -> Date { lock.lock(); defer { lock.unlock() }; return value }
        func advance(_ seconds: Double) { lock.lock(); defer { lock.unlock() }; value += seconds }
    }

    private final class Transport: PlaybackDiagnosticTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var requests: [Data] = []
        private var onMain = false
        private var callbacks: [@Sendable (PlaybackDiagnosticUploadResponse) -> Void] = []
        var response = PlaybackDiagnosticUploadResponse(status: 204)
        var hold = false
        var onSend: (@Sendable () -> Void)?

        func send(_ body: Data, completion: @escaping @Sendable (PlaybackDiagnosticUploadResponse) -> Void) {
            lock.lock()
            requests.append(body)
            onMain = onMain || Thread.isMainThread
            if hold { callbacks.append(completion) }
            let held = hold
            let reply = response
            let sent = onSend
            lock.unlock()
            sent?()
            if !held { completion(reply) }
        }
        func bodies() -> [Data] { lock.lock(); defer { lock.unlock() }; return requests }
        func sentOnMain() -> Bool { lock.lock(); defer { lock.unlock() }; return onMain }
        func complete(_ response: PlaybackDiagnosticUploadResponse) {
            lock.lock()
            let callback = callbacks.removeFirst()
            lock.unlock()
            callback(response)
        }
    }

    private var directory: URL!
    private var clock: Clock!
    private var transport: Transport!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        clock = Clock()
        transport = Transport()
    }

    override func tearDown() { try? FileManager.default.removeItem(at: directory) }

    private func uploader(maximumBytes: Int = 512 * 1024, maximumRecords: Int = 512) -> PlaybackDiagnosticUploader {
        let clock = clock!
        return PlaybackDiagnosticUploader(directory: directory, transport: transport,
            maximumBytes: maximumBytes, maximumRecords: maximumRecords,
            clock: { clock.now() }, jitter: { 1 }, automaticallySchedules: false)
    }

    private func record(_ sequence: Int = 1, run: String = "ED580E20-9679-4EBD-B956-35D9DC4C0607",
                        event: String = "media.observed", values: [String: PlaybackDiagnosticValue] = [:]) -> PlaybackDiagnosticRecord {
        PlaybackDiagnosticRecord(run: run, sequence: sequence, wallTime: clock.now().timeIntervalSince1970,
                                 uptime: Double(sequence), event: event, values: values)
    }

    func testProjectionDropsUnknownEventsIdentifiersStringsAndWrongTypes() throws {
        XCTAssertNil(PlaybackDiagnosticUploadProjection.record(record(event: "chat.secret")))
        XCTAssertNil(PlaybackDiagnosticUploadProjection.record(record(run: "account-name")))
        XCTAssertNil(PlaybackDiagnosticUploadProjection.record(record(0)))
        let input = record(values: [
            "kind": .text("sample"), "time": .number(0.4), "paused": .flag(true),
            "token": .text("private-token"), "url": .text("https://secret.invalid/media"), "chat": .text("private-chat"),
            "channel": .text("private-channel"), "errorDomain": .text("private-error"),
            "category": .text("private-category"), "mode": .text("private-mode"), "outputPorts": .text("device-name"),
            "playerSession": .text("account-id"), "event": .text("private-event"), "phase": .text("private-phase"),
            "ready": .text("private-value"), "muted": .number(1), "rate": .number(.infinity),
            "width": .number(1e20), "build": .text("private-build"), "notification": .text("private-notification")
        ])
        let safe = try XCTUnwrap(PlaybackDiagnosticUploadProjection.record(input))
        XCTAssertEqual(Set(safe.values.keys), ["kind", "time", "paused"])
        let data = try JSONEncoder().encode(safe)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("private"))
    }

    func testProjectionRetainsOnlyPublicMetadataEnumsNumbersFlagsAndEphemeralUUIDs() throws {
        let safe = try XCTUnwrap(PlaybackDiagnosticUploadProjection.record(record(event: "audio.notification", values: [
            "version": .text("0.1.0"), "build": .text("202611052215"), "os": .text("27.1"),
            "source": .text("systemIdle"), "phase": .text("background"), "cause": .text("audioInterruption"),
            "category": .text("AVAudioSessionCategoryPlayback"), "mode": .text("AVAudioSessionModeMoviePlayback"),
            "notification": .text("AVAudioSessionInterruptionNotification"), "outputPorts": .text("BuiltInSpeaker,AirPlay"),
            "command": .text(UUID().uuidString), "appearance": .text(UUID().uuidString),
            "errorDomain": .text("NSOSStatusErrorDomain"), "errorCode": .number(-50), "systemSource": .flag(true)
        ])))
        XCTAssertEqual(safe.values.count, 15)
    }

    func testBoundedBatchOffMainAndOnlyLoki204Acknowledges() async throws {
        let uploader = uploader()
        for sequence in 1...40 { uploader.enqueue(record(sequence, values: ["kind": .text("sample")])) }
        await uploader.flush()
        XCTAssertEqual(transport.bodies().count, 0, "The initial 30-second collection window batches records")
        clock.advance(30)
        await uploader.flush()
        let bodies = transport.bodies()
        XCTAssertEqual(bodies.count, 1)
        XCTAssertFalse(transport.sentOnMain())
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: bodies[0]) as? [String: Any])
        let streams = try XCTUnwrap(payload["streams"] as? [[String: Any]])
        let values = try XCTUnwrap(streams.first?["values"] as? [[String]])
        XCTAssertEqual(values.count, 32)
        XCTAssertEqual(Set((streams[0]["stream"] as! [String: String]).keys), ["app", "component", "run"])
        XCTAssertLessThanOrEqual(bodies[0].count, 64 * 1024)
        let snapshot = await uploader.snapshot()
        XCTAssertEqual(snapshot.pending, 8)
        XCTAssertEqual(snapshot.failures, 0)
        await uploader.flush()
        XCTAssertEqual(transport.bodies().count, 1, "Success must not drain backlog in a tight loop")
        clock.advance(30)
        transport.response = PlaybackDiagnosticUploadResponse(status: 200)
        await uploader.flush()
        let final = await uploader.snapshot()
        XCTAssertEqual(final.pending, 0, "A permanent wrong response is dropped, never called an acknowledgement")
        XCTAssertFalse(PlaybackDiagnosticUploadResponse(status: 200).accepted)
    }

    func testRetriesHaveStablePayloadAndPersistentBackoffAcrossRelaunch() async throws {
        transport.response = PlaybackDiagnosticUploadResponse(status: 500)
        let first = uploader()
        first.enqueue(record(values: ["kind": .text("pause")]))
        clock.advance(30)
        // Synchronize enqueue before advancing the clock's collection window.
        _ = await first.snapshot()
        clock.advance(30)
        await first.flush()
        XCTAssertEqual(transport.bodies().count, 1)
        let failed = await first.snapshot()
        XCTAssertEqual(failed.failures, 1)
        XCTAssertEqual(failed.nextAttempt, clock.now().timeIntervalSince1970 + 60)
        let second = uploader()
        second.enqueue(record(values: ["kind": .text("pause")])) // Same run/sequence cannot duplicate pending entry.
        let restored = await second.snapshot()
        XCTAssertEqual(restored.pending, 1)
        await second.flush()
        XCTAssertEqual(transport.bodies().count, 1)
        clock.advance(60)
        await second.flush()
        XCTAssertEqual(transport.bodies().count, 2)
        XCTAssertEqual(transport.bodies()[0], transport.bodies()[1])
        let retried = await second.snapshot()
        XCTAssertEqual(retried.failures, 2)
        XCTAssertEqual(retried.nextAttempt, clock.now().timeIntervalSince1970 + 120)
    }

    func testRateLimitHonorsBoundedRetryAfterAndNetworkFailureRetries() async throws {
        transport.response = PlaybackDiagnosticUploadResponse(status: 429, retryAfter: 9000)
        let uploader = uploader()
        uploader.enqueue(record())
        _ = await uploader.snapshot()
        clock.advance(30)
        await uploader.flush()
        let rateLimited = await uploader.snapshot()
        XCTAssertEqual(rateLimited.nextAttempt, clock.now().timeIntervalSince1970 + 3600)
        clock.advance(3599)
        await uploader.flush()
        XCTAssertEqual(transport.bodies().count, 1)
        clock.advance(1)
        transport.response = PlaybackDiagnosticUploadResponse(status: nil)
        await uploader.flush()
        let offline = await uploader.snapshot()
        XCTAssertEqual(offline.pending, 1)
        XCTAssertEqual(offline.failures, 2)
    }

    func testCountBytesAndAgeBoundTheQueueAndCorruptionNeverUploads() async throws {
        let uploader = uploader(maximumBytes: 4096, maximumRecords: 3)
        for sequence in 1...20 { uploader.enqueue(record(sequence)) }
        let bounded = await uploader.snapshot()
        XCTAssertEqual(bounded.pending, 3)
        XCTAssertLessThanOrEqual(bounded.bytes, 4096)
        let file = directory.appendingPathComponent("upload-queue.json")
        XCTAssertLessThanOrEqual(try Data(contentsOf: file).count, 2 * 1024 * 1024)
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        clock.advance(86400)
        await uploader.flush()
        let aged = await uploader.snapshot()
        XCTAssertEqual(aged.pending, 0)
        XCTAssertEqual(transport.bodies().count, 0)
        try Data("broken JSON private-token".utf8).write(to: file)
        let recreated = self.uploader()
        let corrupt = await recreated.snapshot()
        XCTAssertEqual(corrupt.pending, 0)
        XCTAssertTrue(corrupt.persistenceFailed)
        await recreated.flush()
        XCTAssertEqual(transport.bodies().count, 0)
    }

    func testByteEvictionAndPoisonedRestoredRecordsAreNeverSent() async throws {
        let uploader = uploader(maximumBytes: 4096)
        for sequence in 1...40 {
            uploader.enqueue(record(sequence, values: ["command": .text(UUID().uuidString), "appearance": .text(UUID().uuidString)]))
        }
        let bounded = await uploader.snapshot()
        XCTAssertLessThan(bounded.pending, 40)
        XCTAssertLessThanOrEqual(bounded.bytes, 4096)
        let file = directory.appendingPathComponent("upload-queue.json")
        var state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var entries = try XCTUnwrap(state["entries"] as? [[String: Any]])
        entries[0]["line"] = "private-token"
        state["entries"] = entries
        try JSONSerialization.data(withJSONObject: state).write(to: file)
        let restored = self.uploader()
        let clean = await restored.snapshot()
        XCTAssertEqual(clean.pending, bounded.pending - 1)
        clock.advance(30)
        await restored.flush()
        XCTAssertFalse(transport.bodies().contains { String(decoding: $0, as: UTF8.self).contains("private-token") })
    }

    func testInFlightEnqueueAndOverlappingFlushDoNotDuplicateOrDeleteNewEvents() async throws {
        transport.hold = true
        let sent = expectation(description: "first batch sent")
        transport.onSend = { sent.fulfill() }
        let uploader = uploader()
        uploader.enqueue(record())
        _ = await uploader.snapshot()
        clock.advance(30)
        let first = Task { await uploader.flush() }
        await fulfillment(of: [sent], timeout: 5)
        uploader.enqueue(record(2))
        await uploader.flush()
        XCTAssertEqual(transport.bodies().count, 1)
        transport.complete(PlaybackDiagnosticUploadResponse(status: 204))
        await first.value
        let remaining = await uploader.snapshot()
        XCTAssertEqual(remaining.pending, 1)
        XCTAssertFalse(remaining.inFlight)
    }

    func testEightAttemptBudgetSurvivesCrashAndPreventsUnboundedDuplicates() async throws {
        transport.response = PlaybackDiagnosticUploadResponse(status: 503)
        let uploader = uploader()
        uploader.enqueue(record())
        _ = await uploader.snapshot()
        clock.advance(30)
        for attempt in 1...8 {
            await uploader.flush()
            XCTAssertEqual(transport.bodies().count, attempt)
            let snapshot = await uploader.snapshot()
            clock.advance(max(0, snapshot.nextAttempt - clock.now().timeIntervalSince1970))
        }
        let final = await uploader.snapshot()
        XCTAssertEqual(final.pending, 0)

        // Simulate a crash after reserving the final attempt but before its response.
        let file = directory.appendingPathComponent("upload-queue.json")
        uploader.enqueue(record(2))
        _ = await uploader.snapshot()
        var state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        state["failures"] = 8
        state["nextAttempt"] = clock.now().timeIntervalSince1970
        try JSONSerialization.data(withJSONObject: state).write(to: file)
        let restored = self.uploader()
        await restored.flush()
        XCTAssertEqual(transport.bodies().count, 8)
        let exhausted = await restored.snapshot()
        XCTAssertEqual(exhausted.pending, 0)
    }

    func testPersistenceFailureNeverSendsAnUnrecoverableBatch() async throws {
        try Data("not a directory".utf8).write(to: directory)
        let uploader = uploader()
        uploader.enqueue(record())
        let failed = await uploader.snapshot()
        XCTAssertTrue(failed.persistenceFailed)
        clock.advance(30)
        await uploader.flush()
        XCTAssertEqual(transport.bodies().count, 0)
        let after = await uploader.snapshot()
        XCTAssertTrue(after.persistenceFailed)
        XCTAssertGreaterThan(after.nextAttempt, clock.now().timeIntervalSince1970)
    }

    func testRelaunchAutomaticallySchedulesPendingUploadWithoutFlushOrUserAction() async throws {
        let first = uploader()
        first.enqueue(record())
        _ = await first.snapshot()
        let file = directory.appendingPathComponent("upload-queue.json")
        var state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        state["nextAttempt"] = clock.now().timeIntervalSince1970
        try JSONSerialization.data(withJSONObject: state).write(to: file)
        let sent = expectation(description: "restored upload scheduled automatically")
        transport.onSend = { sent.fulfill() }
        let clock = clock!
        let restored = PlaybackDiagnosticUploader(directory: directory, transport: transport,
            clock: { clock.now() }, jitter: { 1 })
        await fulfillment(of: [sent], timeout: 5)
        XCTAssertEqual(transport.bodies().count, 1)
        _ = await restored.snapshot() // Keep the owner alive through its scheduled request.
    }

    func testOversizedSpoolIsRejectedBeforeDecodingOrSending() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 32, count: 2 * 1024 * 1024 + 1)
            .write(to: directory.appendingPathComponent("upload-queue.json"))
        let uploader = uploader()
        let snapshot = await uploader.snapshot()
        XCTAssertEqual(snapshot.pending, 0)
        XCTAssertTrue(snapshot.persistenceFailed)
        await uploader.flush()
        XCTAssertTrue(transport.bodies().isEmpty)
    }
}
