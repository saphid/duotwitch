import Foundation

/// Serialized disk/network coordination, entirely off the main actor. The local
/// export is independent: upload eviction or acknowledgement never erases it.
final class PlaybackDiagnosticUploader: @unchecked Sendable {
    struct Snapshot: Sendable {
        let pending: Int
        let bytes: Int
        let failures: Int
        let nextAttempt: Double
        let inFlight: Bool
        let persistenceFailed: Bool
    }

    private struct Entry: Codable {
        let record: PlaybackDiagnosticRecord
        let line: String
        let timestamp: String
        let enqueued: Double
        var identity: String { record.identity }
    }

    private struct State: Codable {
        var entries: [Entry] = []
        var failures = 0
        var nextAttempt: Double = 0
    }

    private let queue = DispatchQueue(label: "com.saphid.duotwitch.diagnostic-upload", qos: .utility)
    private let file: URL
    private let transport: any PlaybackDiagnosticTransport
    private let clock: @Sendable () -> Date
    private let jitter: @Sendable () -> Double
    private let automaticallySchedules: Bool
    private let maximumBytes: Int
    private let maximumRecords: Int
    private let interval: TimeInterval = 30
    private var state = State()
    private var inFlight = false
    private var persistenceFailed = false
    private var scheduled: DispatchWorkItem?
    private var scheduledAt: Double?
    private var stopped = false

    init(directory: URL, transport: any PlaybackDiagnosticTransport = PlaybackDiagnosticHTTPTransport(),
         maximumBytes: Int = 512 * 1024, maximumRecords: Int = 512,
         clock: @escaping @Sendable () -> Date = { Date() },
         jitter: @escaping @Sendable () -> Double = { Double.random(in: 0.8...1.2) },
         automaticallySchedules: Bool = true) {
        file = directory.appendingPathComponent("upload-queue.json")
        self.transport = transport
        self.maximumBytes = max(4096, min(512 * 1024, maximumBytes))
        self.maximumRecords = max(1, min(512, maximumRecords))
        self.clock = clock
        self.jitter = jitter
        self.automaticallySchedules = automaticallySchedules
        queue.async { [self] in
            load()
            schedule()
        }
    }

    deinit { scheduled?.cancel() }

    func enqueue(_ input: PlaybackDiagnosticRecord) {
        queue.async { [self] in
            guard !stopped, let record = PlaybackDiagnosticUploadProjection.record(input),
                  !state.entries.contains(where: { $0.identity == record.identity }),
                  let data = try? Self.encoder.encode(record), data.count <= 4096,
                  let line = String(data: data, encoding: .utf8) else { return }
            let now = clock().timeIntervalSince1970
            // Keep wire timestamps stable across retry/relaunch. The ephemeral
            // run label separates concurrently used phones and application runs.
            let timestamp = String(Int64(record.wallTime * 1_000_000_000))
            state.entries.append(Entry(record: record, line: line, timestamp: timestamp, enqueued: now))
            trim(now: now)
            if state.nextAttempt == 0 { state.nextAttempt = now + interval }
            persist()
            schedule()
        }
    }

    /// Permanently stop this uploader. A later opt-in creates a fresh instance.
    func cancelAndDiscard(completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            stopped = true
            scheduled?.cancel()
            scheduled = nil
            scheduledAt = nil
            transport.cancel()
            inFlight = false
            state = State()
            do {
                if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
                completion(true)
            } catch { completion(false) }
        }
    }

    func snapshot() async -> Snapshot {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                continuation.resume(returning: Snapshot(pending: state.entries.count, bytes: bytes,
                    failures: state.failures, nextAttempt: state.nextAttempt, inFlight: inFlight,
                    persistenceFailed: persistenceFailed))
            }
        }
    }

    /// Respects persisted pacing and the single-flight guard, including when
    /// called at startup or by a test. Does not wait for a network connection.
    func flush() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in attempt { continuation.resume() } }
        }
    }

    private var bytes: Int { state.entries.reduce(0) { $0 + $1.line.utf8.count } }
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    private func trim(now: Double) {
        // A retry never extends retention. The export's separate rolling files
        // remain available after upload records age out or exceed capacity.
        state.entries.removeAll { now - $0.enqueued >= 86_400 || $0.enqueued > now + 3600 }
        var size = bytes
        while state.entries.count > maximumRecords || size > maximumBytes {
            size -= state.entries.removeFirst().line.utf8.count
        }
    }

    private func load() {
        do {
            guard FileManager.default.fileExists(atPath: file.path) else { return }
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= 2 * 1024 * 1024 else { throw CocoaError(.fileReadCorruptFile) }
            let loaded = try JSONDecoder().decode(State.self, from: Data(contentsOf: file))
            let now = clock().timeIntervalSince1970
            var identities = Set<String>()
            state.entries = loaded.entries.compactMap { entry in
                guard let record = PlaybackDiagnosticUploadProjection.record(entry.record),
                      let data = try? Self.encoder.encode(record), data.count <= 4096,
                      let line = String(data: data, encoding: .utf8), entry.line == line,
                      entry.timestamp == String(Int64(record.wallTime * 1_000_000_000)),
                      entry.enqueued.isFinite, identities.insert(record.identity).inserted else { return nil }
                return entry
            }
            state.failures = max(0, min(8, loaded.failures))
            state.nextAttempt = loaded.nextAttempt.isFinite ? min(now + 3600, max(now, loaded.nextAttempt)) : now + interval
            trim(now: now)
            persist()
        } catch {
            // Corrupt/unsafe spool is never sent. Retain local export independently.
            state = State()
            persistenceFailed = true
        }
    }

    private func persist() {
        do {
            let directory = file.deletingLastPathComponent()
            #if os(iOS)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            #else
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #endif
            var url = directory
            var resources = URLResourceValues()
            resources.isExcludedFromBackup = true
            try url.setResourceValues(resources)
            let data = try Self.encoder.encode(state)
            #if os(iOS)
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try data.write(to: file, options: .atomic)
            #endif
            persistenceFailed = false
        } catch { persistenceFailed = true }
    }

    private func schedule() {
        guard !stopped, automaticallySchedules, !inFlight, !state.entries.isEmpty else { return }
        let now = clock().timeIntervalSince1970
        let deadline = max(now + 1, state.nextAttempt)
        // New high-frequency records must not postpone an existing flush.
        if let scheduledAt, scheduledAt <= deadline { return }
        scheduled?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.scheduled = nil
            self.scheduledAt = nil
            self.attempt { }
        }
        scheduled = work
        scheduledAt = deadline
        queue.asyncAfter(deadline: .now() + max(1, deadline - now), execute: work)
    }

    private struct DiagnosticPayload: Encodable {
        struct Stream: Encodable {
            let stream: [String: String]
            let values: [[String]]
        }
        let streams: [Stream]
    }

    private func attempt(completion: @escaping @Sendable () -> Void) {
        guard !stopped else { completion(); return }
        let now = clock().timeIntervalSince1970
        guard !inFlight else { completion(); return }
        let count = state.entries.count
        trim(now: now)
        if count != state.entries.count { persist() }
        guard !state.entries.isEmpty, now >= state.nextAttempt else { schedule(); completion(); return }
        var batch: [Entry] = []
        var batchBytes = 0
        for entry in state.entries.prefix(32) {
            guard batchBytes + entry.line.utf8.count <= 24 * 1024 else { break }
            batch.append(entry)
            batchBytes += entry.line.utf8.count
        }
        if state.failures >= 8 {
            let exhausted = Set(batch.map(\.identity))
            state.entries.removeAll { exhausted.contains($0.identity) }
            state.failures = 0
            state.nextAttempt = now + interval
            persist()
            schedule()
            completion()
            return
        }
        let runs = Dictionary(grouping: batch, by: { $0.record.run })
        let payload = DiagnosticPayload(streams: runs.keys.sorted().map { run in
            DiagnosticPayload.Stream(stream: ["app": "duotwitch", "component": "playback", "run": run],
                               values: runs[run]!.map { [$0.timestamp, $0.line] })
        })
        guard let body = try? Self.encoder.encode(payload), body.count <= 64 * 1024 else {
            completion(); return
        }
        // Write the attempt budget BEFORE sending. A crash or relaunch cannot
        // reset pacing/attempt count or send an in-memory-only record.
        state.failures += 1
        let backoff = min(3600, 60 * pow(2, Double(min(6, state.failures - 1))))
        state.nextAttempt = now + min(3600, max(interval, backoff * min(1.2, max(0.8, jitter()))))
        persist()
        guard !persistenceFailed else { schedule(); completion(); return }
        inFlight = true
        let identities = Set(batch.map(\.identity))
        transport.send(body) { [self] response in
            queue.async { [self] in
                guard !stopped else { completion(); return }
                inFlight = false
                let finished = clock().timeIntervalSince1970
                if response.accepted || !response.retryable || state.failures >= 8 {
                    state.entries.removeAll { identities.contains($0.identity) }
                    state.failures = 0
                    state.nextAttempt = finished + interval
                } else if let retry = response.retryAfter, retry.isFinite {
                    state.nextAttempt = max(state.nextAttempt, finished + min(3600, max(interval, retry)))
                }
                trim(now: finished)
                persist()
                schedule()
                completion()
            }
        }
    }
}
