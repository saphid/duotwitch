# Source checkpoint 4 — 5 November 2026

Source review 3 passed at 8/10, with no High findings. T3 task
`node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A56eb816c-667d-4353-85dc-c3938a708d26`
completed as `claudeAgent` / `claude-opus-5-5`; orchestrator readback confirms
the requested `effort=xhigh`. Its full report is source-review-3-opus.md.

## Changes after that frozen review

- Video becoming too small calls WebKit's public pause-all-media API, which
  completes before audio is released. A native Pause video control remains
  available during playback. Footer status/retry is scoped to the current
  channel and retry requires enough room. No hidden new-channel load occurs
  when its video area is too small.
- Channel switches pause existing media before loading the new page or
  releasing audio. Failures pause through WebKit too. This avoids relying on a
  working host script for pause. Async transitions use the bridge session to
  reject stale work; interruption pause reasons survive the resulting event.
- Navigation pins the configured page path as well as its HTTPS origin.
- Successful session validation clears a stale account error.
- Device authorization keeps polling through transient network errors and
  server 5xx, checks cancellation/deadline, and honors pending/slow-down/final
  refusal outcomes. The polling sleeper is injectable for bounded tests.
- AppModel accepts injected dependencies. Reopening a suspended same-channel
  chat resumes with a missing-messages notice. A direct AppModel test covers
  saved-draft reconciliation for confirmed sends and drops across channels.
- Uncertain sends, including gateway failures and malformed successful
  responses, tell the user to check chat before resending. They are not
  automatically retried. The watchdog test awaits async reconnect cleanup.
- Keychain access errors no longer misleadingly describe every failure as a
  save error. The diagnostic player screen has a native Pause control.

## Verification

Final owned Duo Simulator run: **51 passed, 0 failed, 0 skipped**, command exit
0, no xcresult runtime warnings, no Swift compiler warnings.
`build/verification/review4-final-20261105.xcresult`, matching log and
`review4-final-summary.json`. Owned temporary DerivedData cleanup completed.

This adds device-flow pending/slow-down/transient failure/success, final
decline/expiry and cancellation tests; direct AppModel draft tests; native
pause-before-audio/load ordering; insufficient-space behavior; ambiguous sends.
The tests inject media pause and do not prove real WebKit playback or folding.

The exact unchanged host page approved by review 3 is published and verified
at https://saphid.app/apps/duotwitch/player/index.html (HTTPS 200, identical
bytes). See ../PLAYER_HOST.md. No full app source was published.
This test build supplies that public host via its build setting, with an empty
Twitch Client ID. It is not a working authenticated build or a Release archive.

No Twitch registration, live native auth/chat, real PiP, parity pass or
TestFlight delivery is claimed. The older probe's fullscreen black-rendering
failure remains open until retested on this owned-origin build. Compact embed
size, production NavigationSplitView fold continuity and the other documented
product gaps still need work. Review 3 correctly noted that the prior chat
test replayed AppModel's call order, rather than testing AppModel itself; only
the new direct model test supports an AppModel claim.
