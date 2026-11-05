**Verdict: pass on source quality, with no High findings. I score the source 8/10.** This is not a product-readiness or parity score.

Review 2's three Medium findings are fixed. Two of them now have tests; the maintenance loop is fixed by reading the code but has no test. The async code is careful. What remains is one plausible Medium, a handful of Lows, and test gaps around `AppModel`, `LibraryModel` and device sign-in.

## Provenance
- **Reviewer:** Anthropic Claude Opus 5.5 (`claude-opus-5-5`), Claude Code harness under T3 Code. xhigh was requested, but I can't see my own effort setting or T3 task ID.
- **Read-only:** no edits, builds, UI, account access, secrets, messages or re-delegation. I did read the Xcode 27.2 SDK headers.
- **Manifest:** it hashes to `971f02b7…1aef` as expected. All 44 of 44 files match (0 missing, 0 different).
- **`CODING_STANDARDS.md`:** there isn't one in the repo, and `git worktree list` shows only this worktree. No rules are cited.
- **Test evidence matches the claim:**
  - `review3-final3-summary.json`: 44 passed, 0 failed, 0 skipped, no runtime warnings.
  - The log shows class counts 12/3/11/3/11/4 and `** TEST SUCCEEDED **`.
  - Every frozen file was last changed before the final log (13:22:26).
  - The two Release logs show the script ran under `/usr/bin/sandbox-exec`: missing config failed with the expected errors, synthetic config built successfully.

## Findings, most severe first

**1. Medium (plausible): when the video area gets too small, the player is hidden but keeps playing.**
- **Where:** `App/WatchView.swift:54-72`.
- **Trigger:** watch on the Duo open, then fold it closed. In compact layouts the video pane is always under 400×300, so `PlayerHost` is removed.
- **What the code does:** nothing pauses. `isPlaying` stays true, the status still says "Video playing", and the audio session stays active.
- **Why it matters:** the only Pause button was inside the removed iframe, so if WebKit keeps audio going (not checked at runtime), there is no way to stop it except leaving the screen.
- **Related:** a channel opened in a layout that doesn't fit shows the previous channel's status (`:87`). Its "Retry player" button (`:89`) loads the new channel off-screen.
- **Fix:** pause and say so when `fits` turns false, or add a native play/pause control. Only show the status when `session.channel == channel.login`.

**2. Low: an old error stays in the Account sheet after the session recovers.**
- **Where:** `Auth/TwitchAuth.swift:296-302` never clears `errorMessage` on success. It is only cleared at `:94`, `:105` and `:189`. `AccountView.swift:51` shows it even when signed in.
- **Trigger:** the device is offline when the hourly validation runs, then the network comes back.

**3. Low (plausible): device-code sign-in gives up on any temporary error.**
- **Where:** `TwitchAuth.swift:131` (network errors are thrown) and `:154` (`requireSuccess` throws on 5xx).
- **Trigger:** the user taps "Continue on Twitch" and the app is suspended while a poll is in flight. On return the request can fail (for example error -1005), and sign-in fails even though the user approved it on Twitch.
- **Fix:** keep polling through temporary errors until the code's deadline.

**4. Low: reopening the same channel after leaving it shows no gap notice.**
- **Where:** `AppModel.swift:58` calls `start()`, not `resume()` (`ChatSession.swift:110-115`).
- **Trigger:** watch A, go back, browse for a few minutes, reopen A. Chat was paused the whole time, but the old messages appear with no "messages may be missing" notice.

**5. Low: some unclear send results tell the user to try again, which can post the message twice.**
- **Where:** `ChatSession.swift:153`.
- **What happens:** a 5xx (`.serviceUnavailable`) shows "Please try again". A 2xx whose body is empty or can't be read (`TwitchAPI.swift:51`, `:93`) shows `.invalidResponse` ("…Please try again"). Only non-`TwitchError` failures get "check chat before sending again".
- **Trigger:** a gateway returns 502/504 after Twitch already posted the message, and the user resends.

**6. Low: review-2 #10 is only partly fixed.**
- **Channel switch:** `PlaybackSession.swift:83` still releases audio before the old page stops. The SDK says that from iOS 26, deactivating while audio is still running succeeds silently (`AVAudioSession.h:255-262`). With `.notifyOthersOnDeactivation`, other apps are told they can resume while the old stream is still playing.
- **Failed pause:** if the pause JavaScript fails, `fail()` (`:128-132`) releases audio even though the pause was never confirmed.

**7. Low (test): the watchdog test has the same kind of race as the timeout test you already fixed.**
- **Where:** `Tests/ChatSessionTests.swift:155-156`. The test waits for `original.cancelled`, then checks `.reconnecting` straight away. The receive loop's error handling runs on a later main-actor turn.
- **Timing:** `:157` allows 3 s, while the run needs a 2 s backoff plus four stubbed calls of about 60 ms each.
- **Fix:** wait for `.reconnecting` instead.

**8. Nit: the "Audio interrupted" status is easily overwritten.**
- **Where:** `PlaybackSession.swift:68-69` and `:280`.
- **What happens:** the iframe's PAUSE event that follows replaces it with "Paused". It also isn't tied to the current channel, so a channel switch during the await at `:68` can replace "Loading…".

**Other nits:**
- **Player URL check covers only the site, not the page:** `allowsPlayerOrigin` (`:210-215`) checks scheme, host and port, not the path. Every page on saphid.app shares one origin.
- **Extra refreshes:** a 401 forces a refresh at `TwitchAPI.swift:85` even if the token was already rotated, so concurrent 401s use up extra refresh tokens.
- **Leftover `connectTask`:** the early returns at `ChatSession.swift:187`, `:190` and `:197` leave it set. This relies on `AppModel` stopping chat when the account changes.
- **Unused code from review 2 is still there:** `FoldState.swift:9-19`, `TwitchAPI.swift:36-44`, `Models.swift:20` and `:73-77`.
- **Misleading message:** `CredentialStore.swift:36-37` reports a failure to *read* the saved sign-in as "could not be saved".

## Review 2 findings

| # | Status |
|---|---|
| 1 Audio deactivation by the app itself | Fixed and tested |
| 2 Maintenance read a stale `scenePhase` | Fixed (`.task(id: phase)`), no test |
| 3 Missing tests | Mostly fixed. Still missing: the final-error list, rate-limit backoff, closing the old socket after draining, the navigation-delegate branches, `AppModel` |
| 4 Library reset on return | Fixed, no test |
| 5 "cancelled" shown as an error | Fixed, no test |
| 6 Validation 401 / late 401 | Fixed, 2 tests |
| 7 Chat-send 401 | Fixed, tested at the API layer |
| 8 Sent message back as a draft after a channel switch | Fixed. The `ChatSession` part is tested; `AppModel`'s draft handling is not |
| 9 Bridge host case | Fixed and tested |
| 10 Audio released before pause | Partly fixed (finding 6) |
| 11 HTTP error overwritten by error 102 | Fixed and tested |
| 12 Reconnect drain | Fixed with a 5 s limit. Messages after the welcome are tested; closing at the end of the window is not |
| 13 "Retry connection" where it can't help | Fixed (`canRetryRestore`) |
| 14 Keychain save failure blocks the app | Fixed and tested |

Of the earlier objections, the Release sandbox concern is resolved by the logs. The "player hidden while playing" objection is still open (finding 1).

## Missing tests that matter
1. **Device-code sign-in:** pending, slow_down, declined, expired and temporary errors. It has no tests and it is the way into the app.
2. **`AppModel`:** `watch`/`leaveWatch` and the send-result handling that reconciles drafts. It isn't injectable today.
3. **`LibraryModel`:** keeping results on return, and the cancellation mapping.
4. **`ChatSession`:** final errors leading to `.failed` with no retry, `rateLimited(until:)` backoff, and closing the old socket after the drain (the 5 s isn't injectable).
5. **Player:** the `decidePolicyFor navigationAction` and `createWebViewWith` branches themselves, and what happens when `fits` turns false while playing.

## Objections to the claims
- **"Final run also covers explicit clear/start in AppModel channel switching":** `ChatSessionTests.swift:62-79` replays that call order on `ChatSession` directly. No test refers to `AppModel`.
- **"Normal pause releases audio on its player event":** true for `pause()`, but not for a channel switch or a failure (finding 6).
- **"Player tests cover navigation origins":** they cover the `allowsPlayerOrigin` helper only, not the delegate's branches.
- **Fold continuity:** I agree the mounted tests don't prove it. The specific risk is still the `onDisappear` → `leaveWatch` pause (`WatchView.swift:43`, `AppModel.swift:69-76`) if `NavigationSplitView` rebuilds the detail view.
- **Release logs:** they predate the `AppModel`/`ChatSession` edits, as disclosed. That doesn't matter for the config check.

## Can `web-player/index.html` be deployed?
**Yes, it is safe and correct as the minimal host for the official embed.**
- **Input:** the channel name is checked against `^[a-z0-9_]{1,25}$` and passed to the player as an option, never inserted as HTML.
- **Embed setup:** the page requires HTTPS, and `parent: [location.hostname]` gives `saphid.app`, which is correct for a top-level page in WKWebView.
- **No leaks:** the referrer policy stops the session value going to Twitch in the Referer header, and the page holds no secrets.
- **Ordinary browsers:** `window.webkit` doesn't exist there, so the page just shows a plain embed.
- **Event names:** all seven are Twitch Embed constants.
- **Config:** the planned URL has no query or fragment, so it passes `validate-release-config.sh`. In `Local.xcconfig` it would be written `https:/$()/saphid.app/apps/duotwitch/player/index.html`.

Two hardening steps, neither blocking:
- **Report script-load failure:** if `v1.js` fails to load, nothing is reported. The app's `didFinish` then shows "Twitch player loaded. Tap its Play control to start." over a black page. A `typeof Twitch === 'undefined'` check could post a failure event so the app shows Retry.
- **Optional:** add a CSP meta tag, and pin the page path in `allowsPlayerOrigin`.

Publishing is an outward action and your decision. Deploying the page doesn't prove playback: own-origin playback, native sign-in and chat, PiP and TestFlight are all still unproven.

No files were changed.
