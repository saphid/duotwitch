import Foundation
import SwiftUI
import UIKit

/// All disk work is serialized off the main actor. Four bounded JSONL files
/// survive relaunch. A separate bounded uploader receives only projected records.
final class PlaybackDiagnosticStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.saphid.duotwitch.playback-diagnostics", qos: .utility)
    private let directory: URL
    private let maximumBytes: Int
    private let fileCount: Int
    private let uploader: PlaybackDiagnosticUploader?
    private var writeFailed = false

    init(directory: URL, maximumBytes: Int = 256 * 1024, fileCount: Int = 4,
         uploader: PlaybackDiagnosticUploader? = nil) {
        self.directory = directory
        self.uploader = uploader
        self.maximumBytes = max(1024, maximumBytes)
        self.fileCount = max(1, min(8, fileCount))
    }

    private func file(_ index: Int) -> URL { directory.appendingPathComponent("playback-\(index).jsonl") }

    func append(_ record: PlaybackDiagnosticRecord) {
        queue.async { [self] in
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .sortedKeys
                var data = try encoder.encode(record)
                data.append(0x0a)
                guard data.count <= maximumBytes else { throw CocoaError(.fileWriteOutOfSpace) }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
                var url = directory
                var attributes = URLResourceValues()
                attributes.isExcludedFromBackup = true
                try url.setResourceValues(attributes)
                let size = (try? FileManager.default.attributesOfItem(atPath: file(0).path)[.size] as? NSNumber)?.intValue ?? 0
                if size + data.count > maximumBytes {
                    try? FileManager.default.removeItem(at: file(fileCount - 1))
                    if fileCount > 1 {
                        for index in stride(from: fileCount - 2, through: 0, by: -1) {
                            if FileManager.default.fileExists(atPath: file(index).path) {
                                try FileManager.default.moveItem(at: file(index), to: file(index + 1))
                            }
                        }
                    }
                }
                if !FileManager.default.fileExists(atPath: file(0).path) {
                    try data.write(to: file(0), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                } else {
                    let handle = try FileHandle(forWritingTo: file(0))
                    defer { try? handle.close() }
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                }
            } catch { writeFailed = true }
            uploader?.enqueue(record)
        }
    }

    /// Queued after prior appends, so export includes the event that requested it.
    func export() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    guard !writeFailed else { throw CocoaError(.fileWriteUnknown) }
                    var data = Data()
                    for index in (0..<fileCount).reversed() {
                        let url = file(index)
                        if FileManager.default.fileExists(atPath: url.path) { data.append(try Data(contentsOf: url)) }
                    }
                    guard !data.isEmpty else { throw CocoaError(.fileReadNoSuchFile) }
                    let folder = directory.appendingPathComponent("Export", isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let url = folder.appendingPathComponent("DuoTwitch-playback.jsonl")
                    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                    continuation.resume(returning: url)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}

@MainActor
final class PlaybackDiagnostics {
    static let shared: PlaybackDiagnostics = {
        let directory = URL.applicationSupportDirectory.appendingPathComponent("PlaybackDiagnostics", isDirectory: true)
        // Hosted unit tests must never send synthetic app events to the receiver.
        let testing = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil || NSClassFromString("XCTest.XCTestCase") != nil
        let uploader = testing ? nil : PlaybackDiagnosticUploader(directory: directory.appendingPathComponent("Upload", isDirectory: true))
        return PlaybackDiagnostics(store: PlaybackDiagnosticStore(directory: directory, uploader: uploader))
    }()
    private let store: PlaybackDiagnosticStore
    private let run = UUID().uuidString
    private let runStartedAt = ProcessInfo.processInfo.systemUptime
    private var sequence = 0

    init(store: PlaybackDiagnosticStore) {
        self.store = store
        record("app.launch", [
            "version": .text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"),
            "build": .text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"),
            "os": .text(UIDevice.current.systemVersion)
        ])
    }

    func record(_ event: String, _ values: [String: PlaybackDiagnosticValue] = [:]) {
        sequence += 1
        store.append(PlaybackDiagnosticRecord(run: run, sequence: sequence,
            wallTime: Date().timeIntervalSince1970, uptime: max(0, ProcessInfo.processInfo.systemUptime - runStartedAt),
            event: event, values: values))
    }

    func export() async throws -> URL {
        record("diagnostics.export")
        return try await store.export()
    }
}

struct PlaybackDiagnosticsView: View {
    let diagnostics: PlaybackDiagnostics
    @State private var preparing = false
    @State private var export: Export?
    @State private var failed = false

    private struct Export: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        Form {
            Section {
                Text("Playback diagnostics are saved automatically. You can also share a local copy to help trace a playback stop.")
                Button {
                    preparing = true
                    Task {
                        defer { preparing = false }
                        do { export = Export(url: try await diagnostics.export()) }
                        catch { failed = true }
                    }
                } label: {
                    Label(preparing ? "Preparing logs…" : "Share playback logs", systemImage: "square.and.arrow.up")
                        .frame(minHeight: 44)
                }.disabled(preparing)
            } footer: {
                Text("Automatic upload is enabled by default to \(PlaybackDiagnosticDestination.disclosure). Your phone needs access to Alex’s Tailscale network; uploads wait and retry when the receiver is unavailable. Logs also stay on this phone across relaunch. They include playback timing, video progress, layout and audio events, but exclude credentials, account and channel identity, chat, media URLs and full errors. The upload queue is bounded and expires after 24 hours; sharing the rolling local logs remains available.")
            }
        }
        .navigationTitle("Playback diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $export) { item in DiagnosticShareSheet(url: item.url) }
        .alert("Couldn’t prepare playback logs", isPresented: $failed) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please try again. The diagnostic files could not be read or saved.") }
    }
}

private struct DiagnosticShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
