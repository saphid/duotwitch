import Foundation

enum PlaybackDiagnosticValue: Codable, Sendable {
    case text(String), number(Double), flag(Bool)

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .text(let text): try value.encode(text)
        case .number(let number): try value.encode(number)
        case .flag(let flag): try value.encode(flag)
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if let flag = try? value.decode(Bool.self) { self = .flag(flag) }
        else if let number = try? value.decode(Double.self) { self = .number(number) }
        else { self = .text(try value.decode(String.self)) }
    }
}

struct PlaybackDiagnosticRecord: Codable, Sendable {
    let schema: Int
    let run: String
    let sequence: Int
    let wallTime: Double
    let uptime: Double
    let event: String
    let values: [String: PlaybackDiagnosticValue]

    init(run: String, sequence: Int, wallTime: Double, uptime: Double,
         event: String, values: [String: PlaybackDiagnosticValue]) {
        schema = 1
        self.run = run
        self.sequence = sequence
        self.wallTime = wallTime
        self.uptime = uptime
        self.event = event
        self.values = values
    }

    var identity: String { "\(run):\(sequence)" }
}

/// A second, closed boundary before anything can leave the phone. Never accept
/// arbitrary event names, dictionary strings, error descriptions or raw payloads.
enum PlaybackDiagnosticUploadProjection {
    private static let events: Set<String> = [
        "app.launch", "app.scene", "diagnostics.export", "player.created", "channel.open",
        "playback.state", "audio.deactivation", "audio.transition.begin", "audio.transition.complete",
        "audio.transition.failed", "native.play.requested", "native.play.result", "native.pause.requested",
        "native.pause.result", "video.hidden", "video.fit", "video.geometry", "media.pause.begin",
        "media.pause.callback", "media.pause.result", "web.navigation.finished", "web.navigation.provisionalFailed",
        "web.navigation.failed", "web.process.terminated", "host.received", "host.applied", "web.load.sent",
        "media.observed", "audio.notification", "web.window.changed", "web.host.attach", "watch.enter", "watch.leave", "watch.layout"
    ]
    private static let flags: Set<String> = [
        "playing", "requestingPlay", "audioReady", "fits", "hostReady", "needsLoad", "failed", "windowAttached",
        "forceReload", "sameChannel", "requestedPlaying", "activating", "allowed", "accepted", "stale",
        "confirmed", "newFits", "paused", "ended", "muted", "hidden", "systemSource", "hasInterruption", "compact", "hasDivision"
    ]
    private static let numbers: Set<String> = [
        "pendingPauses", "loadCount", "appState", "webWidth", "webHeight", "width", "height", "errorCode",
        "video", "time", "volume", "ready", "network", "rate", "error", "decoded", "dropped", "reason", "type", "routeReason",
        "divisionX", "divisionY", "divisionWidth", "divisionHeight"
    ]
    private static let textEnums: [String: Set<String>] = [
        "viewingMode": ["balanced", "slim", "video"],
        "source": ["app", "system", "systemIdle"],
        "audioOwner": ["webKit"],
        "phase": ["active", "inactive", "background"],
        "cause": ["user", "insufficientSpace", "watchHidden", "audioInterruption", "other"],
        "event": ["READY", "PLAYING", "PAUSE", "ONLINE", "OFFLINE", "PLAYBACK_BLOCKED", "ENDED"],
        "kind": ["observerReady", "attached", "detached", "sample", "play", "playing", "pause", "waiting", "stalled",
                 "ended", "error", "emptied", "loadedmetadata", "visibility"],
        "errorDomain": ["NSURLErrorDomain", "WKErrorDomain", "AVFoundationErrorDomain", "NSOSStatusErrorDomain", "other"],
        "notification": ["AVAudioSessionDidBecomeInactiveNotification", "AVAudioSessionInterruptionNotification",
                         "AVAudioSessionRouteChangeNotification", "AVAudioSessionMediaServicesWereLostNotification",
                         "AVAudioSessionMediaServicesWereResetNotification"],
        "category": ["AVAudioSessionCategoryAmbient", "AVAudioSessionCategorySoloAmbient", "AVAudioSessionCategoryPlayback",
                     "AVAudioSessionCategoryRecord", "AVAudioSessionCategoryPlayAndRecord", "AVAudioSessionCategoryMultiRoute"],
        "mode": ["AVAudioSessionModeDefault", "AVAudioSessionModeMoviePlayback", "AVAudioSessionModeSpokenAudio",
                 "AVAudioSessionModeVoiceChat", "AVAudioSessionModeVideoChat", "AVAudioSessionModeMeasurement",
                 "AVAudioSessionModeGameChat", "AVAudioSessionModeVideoRecording", "AVAudioSessionModeVoicePrompt"]
    ]
    private static let ports: Set<String> = [
        "Speaker", "Receiver", "MicrophoneBuiltIn", "AirPlay", "BluetoothA2DPOutput", "BluetoothHFP", "BluetoothLE", "BuiltInReceiver", "BuiltInSpeaker",
        "BuiltInMic", "CarAudio", "DisplayPort", "HDMIOutput", "Headphones", "HeadsetMic", "LineIn", "LineOut",
        "USBAudio", "Virtual", "AVB", "PCI", "FireWire", "Thunderbolt", "ContinuityCaptureMicrophone"
    ]

    static func record(_ input: PlaybackDiagnosticRecord) -> PlaybackDiagnosticRecord? {
        guard input.schema == 1, events.contains(input.event), UUID(uuidString: input.run) != nil,
              input.sequence > 0, input.wallTime.isFinite, (946_684_800...4_102_444_800).contains(input.wallTime),
              input.uptime.isFinite, (0...1e12).contains(input.uptime) else { return nil }
        var values: [String: PlaybackDiagnosticValue] = [:]
        for (key, value) in input.values {
            switch value {
            case .flag where flags.contains(key): values[key] = value
            case .number(let number) where numbers.contains(key) && number.isFinite && abs(number) <= 1e12:
                values[key] = value
            case .text(let text):
                if ["playerSession", "command", "appearance"].contains(key), UUID(uuidString: text) != nil {
                    values[key] = .text(text)
                } else if ["version", "build", "os"].contains(key), !text.isEmpty, text.utf8.count <= 32,
                          text.utf8.allSatisfy({ (48...57).contains($0) || $0 == 46 }) {
                    values[key] = .text(text)
                } else if textEnums[key]?.contains(text) == true {
                    values[key] = .text(text)
                } else if key == "outputPorts", text.utf8.count <= 256 {
                    let components = text.split(separator: ",", omittingEmptySubsequences: false)
                    if components.count <= 8, components.allSatisfy({ ports.contains(String($0)) }) {
                        values[key] = .text(text)
                    }
                }
            default: break
            }
        }
        // Earlier beta spools contained device uptime. Never transmit it,
        // including after an upgrade. Canonical spool validation rejects old
        // entries whose saved line contains that value. Wall time and sequence
        // retain event ordering; current local logs use elapsed app-run time.
        return PlaybackDiagnosticRecord(run: input.run, sequence: input.sequence, wallTime: input.wallTime,
                                        uptime: 0, event: input.event, values: values)
    }
}
