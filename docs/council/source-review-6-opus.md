T3 task: `node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A360aac59-c81d-468b-89d7-6c95411a9297`
Actual orchestrator metadata: claudeAgent / claude-opus-5-5, effort xhigh, status completed.

**Verdict: pass, 8.5/10 for source quality only.** There are no High or Medium findings: one confirmed Low regression, one plausible Low and one nit. This is not a parity score.

## Who reviewed and what I checked
- **Reviewer:** Anthropic Claude Opus 5.5 (`claude-opus-5-5`), in the Claude Code harness under T3 Code. I can't see my effort setting or T3 task ID, so I can't confirm xhigh.
- **Read-only:** I made no edits, builds, or device, browser, account, secret or message actions, and did not re-delegate. I used no network and wrote no files. I only hashed files, ran `strings` on the frozen dylibs and read the xcresult.
- **Freeze:** `source-review-fixes6-sha256.json` hashes to `b0404dd8…4c3e`, and all 44 files match.
  - Versus fixes5, exactly 5 files changed: `AppModel`, `WatchView`, `PlaybackSession`, `PlayerProbeView` and `PlaybackSessionTests`. None were added or removed.
  - Every Swift source file is in the freeze.
- **`CODING_STANDARDS.md`:** there is none, and the repo has one worktree, so no rules are cited.
- **Test evidence:**
  - Suites add up to 15+3+13+3+19+4 = 57, and the xcresult shows 57 passed.
  - The log ends with `** TEST SUCCEEDED **` and has 0 `file.swift:line: warning/error` lines. The other `warning:`/`error:` lines are runtime and AppIntents noise.
  - `runtimeWarnings` is empty, and no frozen file is newer than the log.
- **Bundle:** all 10 manifest entries match `build/review6-simulator/DuoTwitch.app`. The debug dylib is `3f712f56…7251`.
- **New copy:** the string "Video paused. Reopen the channel to continue." is in the 57-test dylib but not in the 55-test one, so it is new in this delta.

## Findings, most severe first

**1. Low (confirmed by trace): after a channel-switch timeout, a successful Pause removes the only Retry, and the new channel stays unloaded.**
- **Where:** `PlaybackSession.swift:128-131` records the switch timeout as `pauseTimedOut` while `needsLoad` stays true. Then `:205-206` calls `clearPauseTimeout()` (`:226-230`), which sets `failure = nil`.
- **Trigger:**
  1. WebKit doesn't answer the switch pause within 2 s. This happens during `open(B)` while `isPlaying` is still true, for example because the leave pause was still in flight or had timed out.
  2. The footer shows both "Pause video" (because `isPlaying`) and Retry.
  3. WebKit recovers, and the user taps "Pause video".
- **Result:**
  - Status becomes "Paused" and Retry disappears, because it is gated on `failure != nil` (`WatchView.swift:94`).
  - `hasCurrentPage` is still false, so the panel shows "Open this channel" with only a "Watch in Twitch" link.
  - Nothing calls `open(B)` again: the video panel's task id is unchanged, and old-page `PAUSE` events fail the session check.
  - Recovery needs Back and reopen, or a fold or size change.
- **Why it's a regression:** in fixes5 the timeout failure was sticky, so Retry stayed. In this branch, the timeout failure also meant "this channel still needs loading".
- **Fix:** in `clearPauseTimeout()`, when `needsLoad` is true, replace the failure with the existing "Channel opening paused. Retry to open this channel." instead of clearing it. Alternatively, finish the pending load once the pause is confirmed.
- **Test to add:** open A, emit `PLAYING`, then `open(B)` with a 30 ms timeout and an unresponsive first pause. Then call a confirmed `pause()`. Expect a non-nil failure or a second request.

**2. Low (plausible; depends on SwiftUI ordering I couldn't verify): a late `onDisappear` from an old view of the same channel now blocks playback until a refit.**
- **Where:**
  - `leaveWatch` (`AppModel.swift:71-78`) only checks `selectedChannel`.
  - `hideVideo()` sets `videoFits = false` (`PlaybackSession.swift:211`), and that stays false.
  - Only the video panel's `.task(id: "\(fits)|\(login)")` (`WatchView.swift:71-74`) sets it back to true.
- **Trigger:** `NavigationSplitView` switches between compact and regular on fold and delivers the old WatchView's `onDisappear` after the replacement's tasks have run.
- **Result:**
  - Every `PLAYING` while the video is visible is paused again with the "too small" message (`:386-391`) until the fit changes or the user leaves.
  - Chat suspension and `isWatching = false` in the same case are pre-existing; reviews 2 and 3 flagged them. The delta makes the playback block sticky.
- **Fix:** give each WatchView appearance a token, and ignore `leaveWatch` unless the token matches the latest `watch`. Prove fold continuity at runtime.

**3. Nit (confirmed, new copy): the new hide message is only visible where it is wrong.**
- **Where:** `:215` sets "Video paused. Reopen the channel to continue." while the Library is showing. When the channel is reopened, `videoAreaChanged(fits: true)` rewrites only the insufficient-space reason (`:235-238`), and `open` returns early.
- **Trigger:** play, tap Back, reopen the same channel.
- **Result:** the footer tells the user to reopen the channel they just reopened.
- **Inconsistency:** if a late `PLAYING` arrived while away, the reason is "too small" instead, which does get rewritten to "Tap Play to continue."
- **Fix:** use "Video paused. Tap Play to continue." as the hide reason, or rewrite both hidden reasons on refit.

## Review 5 items

| # | Status |
|---|---|
| L1: late `PLAYING` after leaving turns audio on | **Fixed.** The new `AppModel` test would fail on the old code, which activates audio once. Remaining risk is finding 2. |
| L2: stale timeout failure never cleared | **Fixed** for `pause()` and tested. The `PAUSE` path is untested. Introduced regression is finding 1. |
| N3: late completion after refit says "too small" | **Fixed and tested** (`:207`, test `:247-256`). The new hide reason isn't rewritten (finding 3). |
| N4: Retry after a switch timeout goes through the same pause gate | Unchanged and not claimed. |
| N5: old page shown under the new channel's title | **Fixed** (`WatchView.swift:57`). No view-level test. |
| Timing-sensitive overlap test | **Fixed** (250 ms, `:221`). The remaining 30 ms test is deterministic, because the operation task is queued before the timer. |
| Review 4 auth and chat leftovers | Those files are unchanged, so these remain open as previously reported. |

## Real test gaps
- **Channel-switch timeout branch (`:128-131`):** still untested, and it now contains finding 1.
- **`PAUSE` event (`:394`):** nothing tests it clearing a timeout failure, or keeping a different failure. That is half of the "pause or `PAUSE` clears only timeout" claim.
- **Leave then reopen the same channel:** neither the status after reopening nor the restored fit is tested. A test here would catch finding 3.
- **WatchView channel check:** untested.
- **Carried from review 5:** empty-path normalization, a signed-in reopen using one socket, and `fail()` pausing then releasing audio.

## Objections to the claims
- **"Late `PLAYING` can't activate audio after Back":** true for the host bridge.
  - Exception: finding 2.
  - The DEBUG observer path (`:371`) bypasses the check. It applies only when the app starts in PlayerProbeView (`DuoTwitchApp.swift:17-21`), so this doesn't matter in practice.
- **"Only the timeout failure is cleared":** I traced every place that sets a failure: `fail()`, `open()`, the pending-switch failure at `:190-193`, and the guard at `:220`.
  - The rule holds except for finding 1.
  - `PLAYING` clears `failure` without resetting `pauseTimedOut`. I couldn't find a way for this to clear a different failure today, so it is only tidiness.
- **"Host event is separate and written only after a known event":** accurate.
  - A `PLAYING` that arrives while hidden is accepted but returns at `:391`, before it is recorded at `:401`.
  - The property is also written in Release builds; only the DEBUG probe shows it.
  - The probe never hides the player, so `PLAYING` attribution there is unaffected.
- **"Reopening restores fit through the video panel's task":** true from reading the code for a new view, but untested.
- **Accurate as stated:**
  - the production view checks the selected channel;
  - a late completion uses the current pause reason;
  - the overlap test now allows 250 ms;
  - the docs don't relabel the 55-test runtime proof as covering this 57-test binary.

I didn't score the product constraints you listed: Twitch SMS and Client ID, Apple two-factor sign-in and the missing app record, TestFlight, background and Picture in Picture, and fold, auth, chat and parity. Runtime behaviour of the 57-test binary is unproven.
