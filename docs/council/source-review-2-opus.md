# DuoTwitch source review 2: independent check after the fix-2 checkpoint

**Score: 7/10 for source quality.** This is not a product or parity score. I found no High bugs. Most of the fixes from review 1 are real and tested. But one fix brings in a new Medium bug, another fix rests on a loop that can't see the app's state, and the player and successful-migration paths still have no tests. I estimate about 8/10 once findings 1–3 below are fixed.

## Provenance
- **Reviewer:** Anthropic Claude Opus 5.5 (`claude-opus-5-5`), running in the Claude Code harness under T3 Code. I can't see my own T3 task ID. Sol 6.1 wrote the change, so Opus reviewing it follows the policy.
- **What I did:** read-only. No edits, builds, Simulator or account actions, re-delegation or messages. I did read the Xcode 27.2 iOS SDK headers and Swift interfaces (AVFAudio, UIKit, SwiftUICore).
- **Frozen files:** the manifest hashes to `63b4c4a977add3ed08d3db09c76f0ec7a7c26d6ab42433d368a9cf0a6d143d36` as expected, and all **41 of 41** listed files match it (0 missing, 0 different). The only other files are docs, `README.md`, `DELIVERY.md`, `assets/icon.svg` and the shared scheme/workspace files.
- **CODING_STANDARDS.md:** none in this repo. `git worktree list` shows this is the only (primary) worktree, so no rules are cited.
- **Test log:** `review-fixes3-20261105.log` shows "Executed 27 tests, with 0 failures" and `** TEST SUCCEEDED **`. The only compiler warning is `Tests/MountedWatchLayoutTests.swift:90` (`UIWindow(frame:)` deprecated). The 27 tests are 7 auth, 7 ChatSession, 4 playback, 2 mounted layout, 4 geometry and 3 chat buffer.
- **SDK facts checked:**
  - `AVAudioSession.didBecomeInactiveNotification` is iOS 27.0, and its `DeactivationSource` includes `.app = 1 // App requested deactivation` (`AVAudioSessionTypes.h:316`, `:689-692`).
  - `reservedRegions(kind:)` is iOS 27.1. Its frame is "in the view's coordinate space", and inactive regions are excluded by default.
  - `ArrangementView` is in SwiftUICore with `anyAppleOS 27.1`.
  - SwiftUI's `Environment` stores its value inline (`case value(Value)`).

## Findings, most severe first

**1. Medium: the iOS 27 audio-inactivity handler also fires when the app deactivates its own audio.**
- **Where:** `Player/PlaybackSession.swift:60-66`.
- **What happens:** every deactivation the app makes posts this notification with source `.app`. The handler always runs `pause()` and sets the status to "Audio interrupted. Tap Play to continue." So after any of these while video is playing, the status is wrong:
  - the user pauses (`:248`)
  - the channel goes offline (`:250`) or the broadcast ends (`:252`)
  - the player fails (`fail()`, `:123-127`, for example after the web process dies)
  - the user leaves the watch view (`App/AppModel.swift:64`)
  - the user switches channel (`:78`)
- **Impact:** "This channel is offline", "This broadcast has ended" and "The video player stopped" are all replaced by "Audio interrupted". The extra JavaScript pause can also fight a quick re-Play.
- **Fix:** read `userInfo[AVAudioSession.deactivationContextKey] as? AVAudioSession.DeactivationContext`. Act only when `source == .system` (or `interruptionContext != nil`) and audio was actually active. Never overwrite a failure or offline status. Make the notification source injectable and add a test.

**2. Medium: the one-minute session maintenance loop reads a frozen `scenePhase`.**
- **Where:** `App/MainView.swift:56-62`.
- **Why:** `@Environment` keeps its value inside the view struct. A running `.task` keeps the copy of `self` from the first body, so `phase == .active` at `:60` never changes while the task runs.
- **What happens:**
  - If the first body saw `.inactive` (likely while the scene connects, but not checked at runtime), the one-minute restore retry and the hourly `/validate` for idle sessions never run. Only the `.active` transition handler at `:70-74` does.
  - If it saw `.active`, the loop keeps running during background audio.
- **Impact:** the fix-2 claim "retries … every minute" depends on this loop.
- **Fix:** use `.task(id: phase)` and loop only while active, or read `UIApplication.shared.applicationState`.
- **Confidence:** the mechanism is confirmed from the SDK. The value at launch is plausible, not proven.

**3. Medium (test coverage): several claimed fixes have no tests.**
- **Player:** none of these are tested:
  - navigation policy (`PlaybackSession.swift:199-230`)
  - bridge origin, port and nonce rejection (`:237-256`)
  - ONLINE and `didFinish` status handling (`:179-183`, `:249`)
  - error responses that aren't 2xx (`:217-224`)
  - audio serialization, including a pause during activation (`:101-121`)
  - the inactivity handler from finding 1

  The only audio test is "no activation on load" (`PlaybackSessionTests.swift:43-50`).
- **Chat:** these paths are untested:
  - a successful migration: socket swap, no re-subscribe, frames read from the new socket, and the old loop finishing its frame. Only stopping during migration is tested (`ChatSessionTests.swift:66-76`).
  - watchdog timeout leading to a reconnect
  - migration timeout or failure
  - the final-error list (`ChatSession.swift:270`)
- **Auth:** these paths are untested:
  - a failed Keychain save and the `pendingPersistence` retry (`TwitchAuth.swift:204`, `:230-232`). `MemoryCredentialStore` can't fail a save.
  - Helix 401 leading to a forced refresh and retry (`TwitchAPI.swift:84-89`)
  - sign-out while a refresh is in flight
- **Fake socket doesn't match the real one:** `FakeChatSocket.cancel()` (`ChatSessionTests.swift:149`) throws `CancellationError`. The real `URLSessionWebSocketTask.receive()` throws an `NSError` after cancel, so production takes the generic `catch` (`ChatSession.swift:172-176`, `:203-206`). A watchdog test written with this fake would wrongly see no reconnect. Throw `URLError(.cancelled)` instead.

**4. Low: the browse list resets every time you come back from a channel.**
- **Where:** `App/LibraryView.swift:26-30` and `App/LibraryModel.swift:20-24`.
- **What happens:** pushing a `WatchView` cancels `.task(id:)`, and popping back restarts it. `reload()` then clears the list and fetches page 1 again, so loaded pages and scroll position are lost after each watch.
- **Fix:** skip the reload when the key is unchanged and results already exist.

**5. Low: a cancelled load shows "cancelled" as an error.**
- **Where:** `App/LibraryModel.swift:52-53`.
- **What happens:** when its task is cancelled, `URLSession.data(for:)` throws `URLError(.cancelled)`, not `CancellationError`. A replaced load (typing during the 300 ms debounce at `LibraryView.swift:28`, switching section, or opening a channel while loading) passes the generation check and shows "Couldn't load Twitch – cancelled".
- **Fix:** in `TwitchHTTP.perform`, turn `URLError.cancelled` into `CancellationError` when `Task.isCancelled`.

**6. Low: a 401 from `/validate` signs the user out without trying the refresh token, and can wipe a newer token pair.**
- **Where:** `TwitchAuth.swift:253-257`, then `:195-197`.
- **What happens:**
  - A Helix 401 tries a refresh first (`TwitchAPI.swift:84-85`), but a 401 from validation expires the session straight away.
  - The expiry check only compares `generation`, and a refresh doesn't change it. So if a validation of the old token was already in flight when a forced refresh succeeded, its 401 clears the Keychain record that now holds the new, valid pair.
- **Fix:** try one shared refresh before expiring. Expire only if `credentials` still holds the token that failed.

**7. Low: a 401 when sending chat says "session expired" while the user is still signed in, and doesn't recover.**
- **Where:** `TwitchAPI.swift:50` (`retryUnauthorized: false`) and `ChatSession.swift:134`.
- **What happens:** a 401 means Twitch didn't process the message, so retrying can't send it twice. Instead the next send reuses the same cached token (`TwitchAuth.swift:253-260`) and fails again.
- **Fix:** allow one refresh-and-retry for sends.

**8. Low: a message that was being sent comes back as a draft after a channel switch.**
- **Where:** `AppModel.swift:45`, `:50` and `ChatSession.swift:122`.
- **What happens:** switching channel saves the text being sent into `drafts[previous]`, and the send result is then thrown away. Coming back to that channel fills the composer with a message that was already sent, so the user may send it twice. A drop reason (`is_sent: false`) is never shown either.

**9. Low: the player bridge compares host names case-sensitively.**
- **Where:** `PlaybackSession.swift:238-239`.
- **What happens:** WebKit lowercases `securityOrigin.host`. Navigation lowercases both sides (`:202`), but the bridge doesn't, and the Release check doesn't reject upper-case hosts.
- **Impact:** with a host like `Player.Example.com`, the page loads but every bridge event is dropped. The status sticks, audio never activates, and Retry never appears.

**10. Low (plausible): audio is deactivated before the video actually pauses.**
- **Where:** `pause()` (`:136-142`) and the channel switch in `open()` (`:78`).
- **What happens:** the audio session is released, and other apps are told they can resume, while the stream may still be playing. Deactivating after the PAUSE event fixes this.

**11. Low (plausible): the HTTP error message for the host page gets overwritten.**
- **Where:** `PlaybackSession.swift:217-224`, then `:185-188`.
- **What happens:** cancelling the response normally makes WebKit report error 102 ("Frame load interrupted"). That isn't filtered out, so it replaces "The video service returned an error (404)".

**12. Low: reconnect handoff still drops unread messages on the old socket.**
- **Where:** `ChatSession.swift:235`.
- **What happens:** a frame the old loop already received now finishes processing (`:186`). But the old socket is closed as soon as the new one is welcomed, so frames that are buffered but not yet read are still lost. Prior finding 9 is only partly fixed.

**13. Low: "Retry connection" shows up where it can't help.**
- **Where:** `AccountView.swift:54-56`.
- **What happens:** it appears after an expired session (saved credentials already removed), a declined or expired sign-in code, or a build with no client ID. In all of these, `restore()` returns immediately (`TwitchAuth.swift:81`).

**14. Low: a failed Keychain write blocks every API call even though a valid token is in memory.**
- **Where:** `TwitchAuth.swift:204`.
- **What happens:** blocking makes nothing more durable, it just stops the app working. Retry the save in the background and keep using the token.

**Nits:**
- **Unused code:**
  - `FoldState` division helpers and `hingeAngle`. Their 0.25/0.75 thresholds also differ from the 0.2/0.8 used in `WatchArrangement.swift`.
  - `TwitchAPI.user` and `currentStream`
  - `WatchedChannel.init(user:)`
  - `isMature`
- **Rate limits:** `connectionFailed` ignores the `rateLimited(until:)` time.
- **Stale refresh task:** a successful sign-in doesn't clear an old `refreshTask` (`TwitchAuth.swift:136`). Nothing reaches this today.

## Review 1 findings: what I checked in the source
- **Fixed and tested:**
  - **1** – refresh 400/401 now ends the session (`TwitchAuth.swift:218`, `:276-288`; chat treats it as final at `ChatSession.swift:270`).
  - **2** – the new tokens are saved before validation (`:225-233`).
  - **3** – a send is tied to the account and channel, not the socket (`ChatSession.swift:64-83`, `:113-122`).
  - **8** – the pending migration socket is closed on stop or failure (`:72`, `:265`).
  - **10** – resume only acts after a real suspension (`:94`).
  - **12** – a malformed event is skipped before it's recorded as seen.
- **Fixed in source:**
  - **4** – a dead web process shows a failure with a manual Retry, keyed on `failure` (`WatchView.swift:88`). This one is tested.
  - **11** – sign-out resets chat to signed out (`:79`).
  - **14** – ONLINE is handled and `didFinish` no longer overwrites status.
  - **16** – search is hidden inside a category.
  - **17** – switching to Full video clears composer focus (`NativeChatView.swift:38`). Not checked at runtime.
  - **18** – the unused block API is removed.
- **Mostly fixed:**
  - **5** – the Release check and escaped example are in place, but they were tested only by 4 direct runs of the script.
  - **13** – navigation and bridge are hardened. Findings 9 and 11 above remain.
- **Partly fixed:**
  - **6** – retry on becoming active works and is tested. The one-minute loop has finding 2.
  - **7** – much better, with the gaps in finding 3.
  - **9** – see finding 12.
  - **15** – audio now starts on PLAYING, but brings in findings 1 and 10.

## Objections to the docs and brief
- **"Retries … every minute"** and **"pauses on iOS 27 audio-session inactivity"** don't hold as written (findings 2 and 1).
- **"Release builds reject invalid config":** true by reading the code. But no real Release build or archive has run with `ENABLE_USER_SCRIPT_SANDBOXING=YES`. If `/usr/bin/python3` can't run inside that sandbox, the build fails. It wouldn't ship a bad config, but it would block the archive.
- **Fold continuity isn't tested:** `WatchView.swift:43` (`onDisappear → leaveWatch`) pauses the player and suspends chat. If `NavigationSplitView` rebuilds the detail view when the size class changes on fold or unfold, playback would pause every time. The mounted tests skip `NavigationSplitView`, so this needs a Simulator check.
- **Player hidden while playing:** when `fits` becomes false (`WatchView.swift:54-57`), the web view is removed from the window without a pause, and `isPlaying` stays true. Whether audio keeps playing off-screen hasn't been checked.
- **"Authoritative send results across reconnects":** true for reconnect and suspend, but not across a channel switch (finding 8).
- I agree with your caveats on the mounted tests, the different candidate in the iPhone report, and the lack of live auth, chat, an owned host or TestFlight.

No source files were changed.
