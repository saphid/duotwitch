**Verdict: pass, 8.5/10 for source quality only.** I found no High or Medium findings. This is not a product parity score.

## Provenance
- **Reviewer:** Anthropic Claude Opus 5.5 (`claude-opus-5-5`), running in the Claude Code harness under T3 Code. I can't see my own effort setting or T3 task ID, so I can't confirm xhigh.
- **Read-only:** I made no repo edits, builds, device or UI actions, and touched no accounts, secrets or messages. I did not re-delegate. The only network action was a public HTTPS GET of the player page. I wrote two scratch files under `/tmp`.
- **Freeze:** `source-review-fixes5-sha256.json` hashes to `2f0e8101…81d0`, and all 44 files match.
  - 9 files changed since freeze 4: AppModel, WatchView, TwitchAuth, ChatSession, PlaybackSession, PlayerProbeView, and the Auth, ChatSession and PlaybackSession tests.
  - Every file in the source folders is in the freeze.
- **`CODING_STANDARDS.md`:** there is none, and this repo has only one worktree. No rules are cited.
- **Evidence checks out:**
  - Suite counts are 15+3+13+3+17+4 = 55, and the log ends with `** TEST SUCCEEDED **`.
  - No frozen file is newer than the log (14:02:51).
  - There are no `warning:` or `error:` lines, and `runtimeWarnings` is empty.
  - The log has `TWITCH_PLAYER_HOST` set.
  - All 10 entries in the bundle manifest, including `DuoTwitch.debug.dylib`, match `build/review5-simulator/DuoTwitch.app`.
  - The host page returns 200 with no redirect, and its SHA-256 (`6e86e8e1…331f`) matches `web-player/index.html`.

## Native pause race
I traced `pauseWithDeadline` and `MediaPauseResult` at `PlaybackSession.swift:219-232, 398-413`, and they are correct.
- The body runs on the main actor, and `onFinish` is set before either task can run.
- The result resolves exactly once, and cleanup cancels the other task.
- If the caller is cancelled, the wait is still capped at 2 s.
- Stale results are blocked correctly: switches use the bridge session plus `isCancelled`, and overlapping pauses use `pauseTransaction`.
- The only leftover: if WebKit never calls back, the cancelled operation task keeps the web view alive. That's harmless for an app-lifetime player.

## Findings, most severe first

**1. Low (plausible): after leaving the watch view, a late `PLAYING` event is still accepted.**
- **Where:** `AppModel.swift:71-78` pauses but never marks the player hidden, so `videoFits` stays true. The hidden-player guard at `PlaybackSession.swift:359-367` therefore doesn't apply.
- **Trigger:** tap Play in the iframe, then tap Back during buffering, or the Twitch player restarts itself after the external pause.
- **Result:** audio turns on and the status says "Video playing", but the Library shows no player control.
- **Fix:** mark the player not fitting when the watch view goes away (for example `videoAreaChanged(fits: false, …)` from `leaveWatch` or `onDisappear`), or gate `PLAYING` on `webView.window != nil`. Reopening restores fit through the existing `.task`.
- **Test to add:** leave the watch view, emit `PLAYING`, and expect no audio activation plus one pause.

**2. Low: a stale "did not respond to Pause" failure is never cleared.**
- **Where:** `:196-203` and `:368`.
- **Trigger:** a pause times out. Then a newer `pause()` confirms, or a host `PAUSE` event arrives.
- **Result:** playback is off and audio is released, but the status still says the player didn't respond. Retry is still shown and does an unneeded reload.
- **Fix:** track the timeout failure separately from other failures, and clear only that one when a pause is confirmed.

**3. Nit: a late pause completion after refitting brings back "too small".**
- **Where:** `:203` writes the captured `reason`, not the current `pauseReason`.
- **Trigger:** fold, then unfold before WebKit confirms the pause. If no `PAUSE` event follows, the status wrongly asks the user to expand a view that already fits.
- **Test gap:** `PlaybackSessionTests.swift:176-178` emits `PAUSE` after the refit, which hides this case.
- **Fix:** `status = pauseReason ?? reason`.

**4. Nit: Retry after a switch timeout goes back through the same pause gate (`:93`, `:118-129`).**
- If the web content process stays unresponsive, every switch fails the same way.
- This is not a regression, because before this change it waited silently forever.
- **Optional fix:** after a second timeout, load anyway (navigating away stops the old page's media) and keep audio active until the new page reports.

**5. Nit: the old channel's page can show for a moment under the new channel's title (`WatchView.swift:57`).**
- The `hasCurrentPage` check doesn't compare `session.channel == channel.login`, unlike the footer at `:88`.
- The old page can show until `.task` calls `open(B)`, which is about one frame during the push.

## Test quality
- **Possible flaky test:** `testOlderPauseTimeoutCannotOverwriteANewerSuccessfulPause` (`:206-222`) has about 20 ms of slack.
  - The older 30 ms timer can fire before the newer `pause()` starts, because `waitUntil` sleeps in 10 ms steps.
  - If it does, the failure sticks (finding 2) and the assertions fail.
  - This is the same kind of timing problem as the watchdog margin that was just fixed.
- **Untested:**
  - the channel-switch timeout branch (`:124-129`): retryable failure, `needsLoad` kept, no request sent, then recovery by Retry or refit;
  - empty-path normalization (`:294`);
  - a signed-in reopen in AppModel using exactly one socket (`AppModel.swift:59` with `resume() -> Bool`);
  - `fail()` pausing and then releasing audio.
- **Fixed:** the device-code cancel test now awaits real completion (`AuthTests.swift:292-299`), and the watchdog test now allows 5 s (`ChatSessionTests.swift:168`).

## Review 4 findings

| # | Status |
|---|---|
| 1 Pause during switch leaves channel unloaded | Fixed and tested, including the late completion |
| 2 Hidden playback before `PLAYING` | Fixed for shrinking; leaving the watch view is finding 1 |
| 3 Pause had no time limit | Fixed: 2 s deadline, audio kept, tested. Retry limitation is finding 4 |
| Status after refit | Fixed, except the race in finding 3 |
| Retry button 44 pt | Fixed (`WatchView.swift:96`) |
| Double connection on reopen | Fixed (`ChatSession.swift:111-117,185`); not tested in AppModel |
| Host URL with empty path | Fixed (`:294`); not tested |
| Auth after code approval, 429, network error list | Still open, not claimed |
| Over-cautious send warning; extra 401 refreshes; leftover `connectTask`; unused code | Still open, not claimed |
| Status doc saying the host wasn't deployed | Fixed |

## Objections to the claims
- **"Late `PLAYING` while hidden is rejected":** true only when the view is too small, not after leaving the watch view (finding 1).
- **"Refit updates the explanation":** except after a late pause completion (finding 3).
- **"Retryable failure":** Retry goes back through the same pause gate (finding 4).
- **"`hasCurrentPage` hides the stale browser":** only once `open(B)` has run (finding 5).
- **"Hidden-startup addressed" (`IMPLEMENTATION_STATUS.md:213-215`):** only partly.
- **Accurate claims:** no auth bypass in the debug launch option (it only seeds the probe channel and needs `-DuoTwitchProbe`), cross-origin and off-screen pause stated as a runtime expectation, `loadCount` counting only sent requests, and `cancelSignIn` returning the cancelled task.

These findings stay separate from the product gaps you listed, which I didn't score. Runtime pause behaviour, live playback and folding are still unproven.
