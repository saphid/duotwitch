# Native Play checkpoint — 5 November 2026

The 62-test production runtime checks completed real native OAuth as `saphid`,
Live discovery, changing received native chat, authenticated relaunch, viewing
arrangements and a real unsent draft across mode changes and Back/reopen.
Reports: `build/proof/native-ssh/REPORT.md` and
`build/proof/native-ssh-followup/REPORT.md`. No messages were sent.

The official iframe Play control had no semantic target, and its rotated
Simulator capture could not be mapped reliably to pointer input. This did not
establish an application playback defect. Instead of further blind taps, the
new candidate adds an accessible native Play control alongside native Pause.

Native Play calls `window.duoPlayer.play()` on the existing owned host using
WebKit's main-page JavaScript API. Twitch documents this public method and
READY as the event indicating the player accepts calls:
<https://dev.twitch.tv/docs/embed/video-and-clips/>. The host already exposes
that instance; no host deployment, iframe extraction, private playback API,
autoplay change or player reload is introduced.

Requests require READY and a fitting, visible current page. The JavaScript
also checks the current URL's session nonce before calling the player. A
request never claims playback or activates audio. Those still require the
production PLAYING event. Late command results cannot overwrite a newer Pause,
channel, host event or failure. WebKit command completion is bounded by the
existing two-second media deadline. A rejected/timed-out command leaves the
official controls available and the native control retryable. The native
control keeps its layout space while unavailable, avoiding fit feedback when
the button enables or a request starts.

Verification: **67 passed, zero failed/skipped**, actual command exit **0**;
xcresult `runtimeWarnings` is empty, and there are no Swift compiler
diagnostics. The initial 66-test run also passed before the bounded-command
regression and stable control row were added. Final artifacts:

- `build/verification/native-play-final-20261105.xcresult`
- `build/verification/native-play-final-summary.json`
- `build/verification/native-play-final-20261105.log` and `.exit`
- `build/verification/native-play-final-receipt.json`
- `build/native-play-final-simulator/DuoTwitch.app`
- `docs/council/source-native-play-sha256.json` (44 entries)
- `build/verification/native-play-bundle-sha256.json` (12 entries)

Xcode ad-hoc signing is enabled; `codesign --verify --deep --strict` exits 0.
The build wrapper removed its private temporary build directory. This small,
isolated build used a task-local 20 GiB reserve with approximately 25 GiB free;
no unrelated data was removed and no global reserve was changed.

Fresh Sol high source review completed with one Medium ordering finding:
refitting can enable native Play before an earlier Pause completes, and that
late Pause can overwrite the newer PLAYING state. The parent accepts this
finding; its fix and regression are pending until the current Astra runtime
check releases the source freeze. See `source-native-play-review-sol.md`.
Astra high production runtime verification remains pending. Application source
remains frozen while it runs. The previous
8.5/10 review applies to the prior candidate. This checkpoint is not a product
pass, moving-video proof, fold/PiP proof, signed device archive or TestFlight
delivery. Category/search, actual fold continuity, accessibility journeys,
audio/background behavior and the product/delivery gates remain open.
