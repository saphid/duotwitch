# Native Play ordering fix — 5 November 2026

The 67-test runtime candidate confirmed changing production video over 12.665
seconds, a stable paused video interior over 19.299 seconds, and resumed changing
video over 29.383 seconds. Official mute was independently verified before
further playback after Alex's silence constraint arrived. Earlier playback had
no verified silent route. Future runtime must verify mute before every playback
session, including after page/channel replacement. No global Mac output changed.
See `build/proof/native-play/REPORT.md` and its audio-silence receipt.

The same run verified category search/open and preserved authentication. Actual
hinge sampling failed, so fold continuity is unverified. Full video left a blank
pane after the unverified fold request; source intentionally avoids an active
division even in video-only mode, but the runtime cause/posture is unresolved.
PiP remains unavailable. These limits belong in the internal beta notes.

Sol's fresh source review found a Medium ordering defect: refitting could enable
native Play while an older Pause remained pending, and that Pause could clear
the new playing state. The new focused regression reproduced it on the original
source (1 test, 3 assertion failures; command exit 65), without real playback.
Evidence: `build/verification/native-play-ordering-red-20261105.{log,exit,xcresult}`.
Given that concrete review trace and deterministic failing seam, no speculative
multi-hypothesis instrumentation was needed.

The fix keeps native Play disabled until both WebKit's actual pause callback and
the surrounding Pause state updates finish. A timeout does not cancel WebKit's
pending operation, so clearing a timeout via PAUSE still cannot enable native
Play before the actual callback. Two regressions cover normal refit ordering and
the timeout/PAUSE/late-callback path. Category search now says Categories matching
instead of Channels matching. The observed full-video/hinge behavior is recorded
as unresolved rather than changed from an unknown Simulator posture.

Full signed Simulator verification: **69 passed, zero failed/skipped**, command
exit **0**, xcresult runtime warnings empty, no Swift compiler diagnostics;
strict deep signature verification exits 0. Tests use injected controls and do
not start a real stream. Wrapper-owned temporary build roots were removed.

- Result: `build/verification/native-play-ordering-20261105.xcresult`
- Summary and receipt: `build/verification/native-play-ordering-{summary,receipt}.json`
- Source: `docs/council/source-native-play-ordering-sha256.json` (44 entries)
- App: `build/native-play-ordering-simulator/DuoTwitch.app`
- Bundle: `build/verification/native-play-ordering-bundle-sha256.json` (12 files)

The source manifest SHA-256 is
`b8a4f3b12099672b02f16f1eeb7c1d0c8970cf7df1ae4e4e638a9a937505310c`;
debug dylib is `1de7dd25359989b80d86b6edee6a00a84c45844ca2b379a27e4e852a77104df1`.
Fresh Codex / GPT-6.1 Sol high review completed with no actionable findings;
see `source-native-play-ordering-review-sol.md`. This is independent-session
review without model diversity. The 67-test video captures do not become
69-test runtime evidence. No final product council pass, fold/PiP completion,
processed TestFlight build, tester access or Discord delivery is claimed here.
