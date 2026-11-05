# Physical playback trace and WebKit audio ownership candidate

The user's private export from TestFlight 0.1.0 (202611052215), iOS 27.2,
contains 242 records and two play-to-pause attempts. The raw attachment is not
included in the repository or uploaded as a test. This report uses relative
app-launch time and fixed event/state classifications only.

| Event | First attempt (seconds) | Second attempt (seconds) |
| --- | ---: | ---: |
| HTML video reports playing | 12.145 | 18.696 |
| Host PLAYING received | 12.368 | 18.719 |
| Native audio activation begins | 12.368 | 18.719 |
| HTML video reports pause | 13.270 | 19.723 |
| Host PAUSE received | 13.293 | 19.742 |
| Native audio activation completes | 13.413 | 19.758 |

The video clock advanced about 0.708 and 0.600 seconds respectively. In both
windows the app was active, the WebView attached, and the player large enough
(528 by 489 points). No native Pause request, geometry change, media error, or
system interruption precedes either pause. Later geometry changes and share /
background transitions are separate events. The genuine interruption reported
after the second pause cannot explain that pause's start.

Three hypotheses were compared: competing native audio activation (matches both
windows), layout/lifecycle pausing (absent before the stops), and provider error
or system interruption (no preceding diagnostic evidence). The first is the
strongest lead, but temporal correlation alone does not establish causation.

The candidate removes the app's AVAudioSession category, activation and
deactivation writes. WebKit owns its media audio. Production PLAYING/PAUSE still
update transport state, media Pause still waits for a bounded WebKit result,
and genuine system interruption observation still pauses playing video. Idle
system deactivation remains observation only. Logs explicitly mark the audio
owner as WebKit, including the automatic-upload projection.

A hosted regression replays both PLAYING/PAUSE boundaries using the production
PlaybackSession with request/media stubs and no live media. Before the fix it
fails because PLAYING starts native audio transitions (actual test exit 65).
The candidate additionally asserts unchanged native category/mode and no native
transition records. This establishes the source boundary, not a physical-device
resolution or audible-output behavior. Physical sustained playback and resume
must be checked on the updated phone build.

Automatic collection is integrated from worker commit c112961 as parent commit
05926fe. It defaults to a typed, allowlisted, bounded persistent upload queue;
manual local export remains available. See ../automatic-playback-diagnostics.md
for the receiver, retention and network contract. No private attachment is used
for endpoint verification.

## Frozen combined target

- Parent base before collector: 24ee4a4; collector integration HEAD: 05926fe.
- Source manifest: `webkit-audio-upload-source-sha256.json`, 54 files, SHA256
  `a8c42fb808ed1dbed92bc07e7a18e1e91487428f8f7a45ce6fd5cfe9568698cd`.
- Candidate: `build/webkit-audio-ownership-final-simulator/DuoTwitch.app`.
- Complete bundle manifest: `build/verification/webkit-audio-upload-bundle-sha256.json`,
  12 regular files; strict/deep signature verification exit 0.
- Final actual xcresult `build/verification/webkit-audio-ownership-final.xcresult`
  and extracted summary: 98 passed, zero failed/skipped, runtimeWarnings empty.
  Matching log and numeric exit receipt record success and exit 0.
- Foundation-only isolated uploader suite: 15 passed, zero failures, exit 0;
  evidence `build/verification/automatic-upload-integrated.*`.
- Earlier first green attempt failed compilation on test-only argument-label
  typos (exit 65). The corrected green2 passed before the final assertion cleanup.
  Final tests cover the current frozen source. The existing AccountView compiler
  deprecation and AppIntents/Simulator console noise remain.
- No audible media was started by these synthetic tests. No native audio-session
  category/activation/deactivation writes remain in the application source.
