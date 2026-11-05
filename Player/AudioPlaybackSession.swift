import AVFAudio
import Foundation

enum AudioDeactivation: Sendable { case app, system, systemIdle }

enum AudioPlaybackSession {
    static func inactivityEvents() -> AsyncStream<AudioDeactivation> {
        AsyncStream { continuation in
            let task = Task {
                for await notification in NotificationCenter.default.notifications(named: AVAudioSession.didBecomeInactiveNotification) {
                    guard !Task.isCancelled else { return }
                    guard let context = notification.userInfo?[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext else { continue }
                    continuation.yield(deactivationEvent(isSystem: context.source == .system,
                                                        wasInterrupted: context.interruptionContext != nil))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func deactivationEvent(isSystem: Bool, wasInterrupted: Bool) -> AudioDeactivation {
        // System inactivity alone is not an interruption. In particular,
        // WebKit may own media playback while the native session is idle.
        guard isSystem else { return .app }
        return wasInterrupted ? .system : .systemIdle
    }

    // Observation only: WebKit controls its own audio category and activation.
}
