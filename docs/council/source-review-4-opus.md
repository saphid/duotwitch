I scored the source at **8.5/10 and it passes**. I found no High or Medium findings. This is a source-quality score only, not product parity or readiness.

## Provenance
- **Reviewer:** Anthropic Claude Opus 5.5 (`claude-opus-5-5`), Claude Code harness under T3 Code. I can't see my own effort setting or T3 task ID, so I can't confirm xhigh.
- **Read-only:** no edits, builds, devices, browsers, accounts, secrets, messages or re-delegation. The one network action was a public HTTPS GET of the player page.
- **Manifest:** `source-review-fixes4-sha256.json` hashes to `720f9dab…87de11` as expected. All 44 of 44 files match.
- **Changed since review3 (10 files):** AppModel, WatchView, TwitchAuth, ChatSession, PlaybackSession, PlayerProbeView, TwitchHTTP, and the Auth, ChatSession and PlaybackSession tests.
- **`CODING_STANDARDS.md`:** none in the repo, and this is the only worktree. No rules are cited.
- **Test evidence matches the claim:**
  - `review4-final-summary.json`: 51 passed, 0 failed, 0 skipped, no runtime warnings.
  - The log shows suite counts 15+3+13+3+13+4 = 51, matching the test functions in source, and `** TEST SUCCEEDED **`.
  - No frozen file is newer than the log (13:44:25).
  - The only "warning" lines are the usual AppIntents skip notes.
  - The log shows `TWITCH_PLAYER_HOST=https://saphid.app/apps/duotwitch/player/index.html`.
  - The bundle manifest includes `DuoTwitch.debug.dylib`.
- **Host page:** HTTPS 200, served at the same URL with no redirect. Its SHA-256 is `6e86e8e1…331f`, byte-identical to `web-player/index.html`.

## Findings, most severe first

**1. Low (logic bug, narrow timing): pausing during a channel switch leaves the new channel never loaded, and reopening it doesn't fix it.**
- **Where:** `Player/PlaybackSession.swift`.
  - `open()` sets `channel = login` at `:88` before the pause-first `loadTask` (`:110-119`) sends the request.
  - `pause()` cancels that task at `:166-167`.
  - After that, `open(sameChannel)` returns early at `:84`, and Retry only appears when `failure != nil`.
- **Trigger:** watching A, switch to B. Before WebKit confirms the pause, any of these happens:
  - the video area stops fitting (`videoAreaChanged` pauses because `loadTask != nil`, `:179`);
  - the user taps the native Pause, which is still visible because `isPlaying` is true and `session.channel == "b"` (`WatchView.swift:90`);
  - the user backs out (`AppModel.swift:78`);
  - a system audio interruption arrives.
- **Result:**
  - A's paused page stays on screen under B's title.
  - A's events carry the old session value, so they're rejected. If the user plays it, there's no status, no native Pause and no audio-session handling.
  - Refitting or reopening B does nothing. Only opening a different channel recovers.
- **Fix:** when `pause()` cancels a pending load, clear the loaded identity (or set a needs-load flag) so the next `open` reloads. Alternatively, don't cancel the load: the host page uses `autoplay: false`.
- **Test to add:** pause during a pending switch, then refit or reopen, and expect a second request.

**2. Low (plausible): the player can still play while hidden if the user folds before the `PLAYING` event arrives.**
- **Where:** `PlaybackSession.swift:179` only pauses when `isPlaying || loadTask != nil`. `:309` accepts `PLAYING` whatever the layout.
- **Trigger:** tap Play in the Twitch player while it fits, then fold during startup buffering.
  - Nothing pauses. `PLAYING` then turns audio on with status "Video playing" while `PlayerHost` is removed.
  - The new native Pause button does appear, which is why this is Low and no longer review3's Medium.
- **Fix:**
  - When the video doesn't fit, call `pause` without the gate. `pauseAllMediaPlayback` is safe to repeat.
  - Or keep a `fits` flag and pause when `PLAYING` arrives while hidden.
  - Optionally use `setAllMediaPlaybackSuspended(true)` while hidden. The SDK says this blocks restarts by the page or user; what happens on un-suspend needs a runtime check.

**3. Low (plausible): channel switching and audio release now wait on a WebKit completion with no time limit.**
- **Where:** `PlaybackSession.swift:114` and `:171`.
- **Trigger:** the web content process is busy, unresponsive or suspended when the pause is sent.
- **Result:** B never loads (status stays "Loading Twitch player…") and the audio session stays active. Before this change, a switch didn't wait on WebKit at all.
- **Fix:** give the pause a short timeout (1–2 s), then continue, or fail with Retry.

**Nits**
- **Misleading status after refit:** "Video paused because this view is too small. Expand it to continue." stays after the view fits again (`:180`, and `:310` keeps it on the PAUSE event).
- **Small Retry button:** "Retry player" (`WatchView.swift:95`) has no 44-pt minimum, unlike Pause at `:92`.
- **Two connection attempts on reopen:** `AppModel.swift:59-60` calls `resume()` and then `start()`, which schedules a connection twice.
  - The first task is cancelled, but it still calls `makeSocket` before its generation check (`ChatSession.swift:183-184`).
  - That wastes one socket object. A signed-in AppModel test using `FakeChatSocket` would use up one extra socket per reopen.
- **Host URL with no path:** the path check compares raw paths (`PlaybackSession.swift:244`). A host configured as `https://host` (empty path) will probably be compared against WebKit's `/` and cancelled. `validate-release-config.sh` doesn't require a path. The current configured URL is unaffected.
- **Sign-in after the code is approved:** in `TwitchAuth.swift:148`, a temporary error during validation right after the token exchange still ends sign-in. The device code is already used, so the user must start again.
  - A 429 while polling is not treated like `slow_down`.
  - The list of retried network errors leaves out `.secureConnectionFailed`, `.dataNotAllowed` and `.internationalRoamingOff`.
- **Over-cautious send warning:** "Check chat before sending again" also appears for failures that definitely didn't send: a 400 (mapped to `.invalidResponse`) and a network failure during token validation before the POST (`ChatSession.swift:157-158`). That's safe, just more cautious than needed.

## Test-quality notes
- **Device-code cancel test can't fail:** `AuthTests.swift:293-299` checks `polls.count == 0` after a single `Task.yield()`. The stub only counts a request after a 60 ms async delay, so the check passes even if polling continued.
- **Watchdog test timing:** the race is fixed, but the run took 2.604 s against a 3 s wait limit with a fixed 2 s backoff (`ChatSessionTests.swift:168`). Under load it could flake.
- **Untested claims:**
  - the interruption reason surviving the later PAUSE event (`:158-168` never sends PAUSE);
  - stale pause completions being ignored after a switch;
  - `fail()` pausing and then releasing audio;
  - `validateIfNeeded` clearing the error while signed in;
  - AppModel's signed-in same-channel reopen showing the gap notice;
  - pausing during a pending load (this test would have caught finding 1).
- **Still untested from review3:** `LibraryModel`; `ChatSession` final errors leading to `.failed` and rate-limit backoff; the navigation-delegate branches themselves.

## Review 3 findings

| # | Status |
|---|---|
| 1 Medium: hidden player keeps playing | Fixed in source for the main trigger (pause on shrink, native Pause, footer tied to the current channel, Retry only when it fits). The narrower case remains as finding 2. Not proven at runtime. |
| 2 Old account error stays after recovery | Fixed (`TwitchAuth.swift:312`), no test on this path |
| 3 Device-code sign-in gives up on temporary errors | Fixed and tested |
| 4 No gap notice on same-channel reopen | Fixed (`AppModel.swift:59`), not tested in AppModel; adds the double-connection nit |
| 5 Unclear send results invite a resend | Fixed and tested (502, malformed 200) |
| 6 Audio released before pause | Fixed; switch ordering is tested, the failure path isn't. New edge cases in findings 1 and 3 |
| 7 Watchdog test race | Fixed; timing margin is still tight |
| 8 "Audio interrupted" status overwritten | Fixed, not tested for the PAUSE event |
| Other nits | Path check fixed. Keychain message fixed (`TwitchHTTP.swift:29`). Still open: extra 401 refreshes (`TwitchAPI.swift:84-85`), leftover `connectTask` (`ChatSession.swift:193`), unused code (`FoldState` division helpers, `currentStream`) |

## Objections to the claims
- **What the SDK says:** the comment at `PlaybackSession.swift:169-170` ("pauses media in all frames… including when… the iframe is no longer visible") goes beyond the Xcode 27.2 header. The header only says it "Pauses media playback in WKWebView" and that the page or user can restart it. Pausing the cross-origin `player.twitch.tv` iframe while the player is off-screen is a runtime expectation for Astra to check.
- **"Insufficient space auto-pauses":** only when the bridge has already reported playback or a load is pending (finding 2).
- **"Native Pause available during playback":** only while `isPlaying` is true, so not before `PLAYING` and not in finding 1's stuck state.
- **"No hidden new-channel load":** true, but cancelling that load causes finding 1.
- **Docs:** `IMPLEMENTATION_STATUS.md` still says, in step 3 of required next evidence and at `:100` and `:155`, that the host isn't deployed. The later supersession note at `:162-167` covers this, but a reader skimming the earlier sections will be misled.
- **Accurate claims:** the AppModel-test distinction, no automatic resend (only 401 is retried, at `TwitchAPI.swift:84`), the device-flow test outcomes, the pinned path and the host deployment all check out.

None of this affects the product gaps you listed, which I kept separate. Runtime WebKit pause behaviour, folding and own-origin playback are still unproven here.

No files were changed.
