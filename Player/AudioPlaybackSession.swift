import AVFAudio
import Foundation

enum AudioDeactivation: Sendable { case app, system }

enum AudioPlaybackSession {
    static func inactivityEvents() -> AsyncStream<AudioDeactivation> {
        AsyncStream { continuation in
            let task = Task {
                for await notification in NotificationCenter.default.notifications(named: AVAudioSession.didBecomeInactiveNotification) {
                    guard !Task.isCancelled else { return }
                    guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext else { continue }
                    continuation.yield(context.source == .system ? .system : .app)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Category changes can block too. Configure off the main thread, then use
    /// the system's asynchronous activation API instead of setActive(_:).
    static func activate() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let session = AVAudioSession.sharedInstance()
                do {
                    if session.category != .playback || session.mode != .moviePlayback {
                        try session.setCategory(.playback, mode: .moviePlayback)
                    }
                    session.activate(options: []) { activated, error in
                        if let error { continuation.resume(throwing: error) }
                        else if activated { continuation.resume() }
                        else { continuation.resume(throwing: TwitchError.serviceUnavailable) }
                    }
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    static func deactivate() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

}
