Task ID: `node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A8ae49bb9-747a-4389-bfd6-a25ce2454344`

Provider: `claudeAgent`; model: `claude-opus-5-5`; status: `completed`.

# DuoTwitch source review: fresh quality gate after tests

**Verdict: 6/10 at this source checkpoint.** The code is well structured, with careful cancellation and a sound security posture. But there is one High auth bug, and five Medium issues (four bugs plus missing tests). None of the auth, playback, chat or fold behaviour is runtime-proven, so this is a score for the source only, not for product readiness.

- **Reviewer:** Anthropic Claude Opus 5.5 (`claude-opus-5-5`), in the Claude Code harness under T3 Code. I can't see my own T3 task ID. Sol wrote the change, so Opus is the right reviewer under the review policy.
- **What I did:** read-only. I did no re-delegation, edits, compiler or Simulator runs, or account actions. I did read a few public Twitch docs pages and SDK headers.
- **Frozen files:** the manifest hashes to `05d5560814888ab7d23d2939bc2577566078bb7e31f0f85fc06e8d21b35b1ba3`, and all 39 listed files match it.
- **CODING_STANDARDS.md:** none exists in this worktree, which is the repo's only worktree. No rules are cited.
- **Tests:** `tests-audio3-20261105.log` shows 13 passed, 0 failed, `** TEST SUCCEEDED **`. All app sources were recompiled in that run with `SWIFT_STRICT_CONCURRENCY=complete` and produced no warnings. The only warnings are in `Tests/AuthTests.swift:29,106-108`. They are warnings because the project builds in Swift 5 mode, and they would become errors in Swift 6.
- **Doc and SDK checks:**
  - Twitch's device-flow docs say refresh tokens are one-time use and expire after 30 days of inactivity. Reusing one returns 400 `{"message":"Invalid refresh token"}`.
  - The async `AVAudioSession.activate(options:completionHandler:)` exists from iOS 27.0, and the deployment target is 27.1.
  - The async `evaluateJavaScript` returns an optional (`WK_NULLABLE_RESULT`), so `pause()` returning `undefined` is safe.

## Findings

**1. High: a refresh that returns 400 never counts as an expired session.**
- **Where:** `Twitch/TwitchHTTP.swift:65` maps 400 to `.invalidResponse`. The refresh call is at `Auth/TwitchAuth.swift:203`. Only `.unauthorized` clears the session (`TwitchAuth.swift:87`, `:241`).
- **What happens:** an expired, reused or revoked refresh token returns 400.
  - At launch, the user sees "Twitch returned an unexpected response" on every launch, and the dead Keychain record is kept.
  - During a session, the account stays signed in, but every Helix call fails. `ChatSession.swift:261-268` treats `.invalidResponse` as a temporary error, so chat reconnects every 30 seconds or less forever. Each attempt opens a new socket and sends another refresh POST.
- **Fix:** in the refresh path, map 400 and 401 to `.unauthorized` (or a new `.sessionExpired`), then clear the Keychain and the account. Make chat treat that error as final.

**2. Medium: the rotated refresh token is saved only after a second network call.**
- **Where:** `TwitchAuth.swift:200-210` runs refresh POST, then `/validate`, then a cancellation check, then a generation check, and only then saves.
- **What happens:** the server has already used up the old one-time token. If `/validate` times out or returns 5xx, the app is suspended, or `cancelSignIn` runs, the new token pair is thrown away. `cancelSignIn` can run during restore because the sign-in button is still enabled then (`App/AccountView.swift:45`). The next refresh then hits finding 1.
- **Fix:** save the new tokens immediately after the 2xx refresh response, keeping the existing userId, login and scopes, then validate. Only sign-out should discard a rotation the server accepted. Add a test where the token request returns 200 and validate returns 500, and assert the new refresh token was stored.

**3. Medium: a message's send result is lost whenever chat reconnects.**
- **Where:** `Chat/ChatSession.swift:105`, `:114` and `:125` tie the send to the socket generation. The generation changes on every reconnect (`:252`) and on background suspend (`:61-63`).
- **What happens:** say the network blips or the user backgrounds the app while a send is in flight. Twitch reports `is_sent: true`, but the result is dropped. The draft and reply stay, no error shows, and the send button re-enables after reconnect, so the user is likely to send a duplicate. If Twitch drops the message (`is_sent: false`), the reason is never shown. This contradicts the claim of "authoritative send results".
- **Fix:** scope sends to channel and account identity instead. That identity should change only on `stop(clear: true)`. Don't reset `sendTransaction` or `isSending` on a plain `stop()`.

**4. Medium: the player can't recover if WebKit's content process dies.**
- **Where:** `Player/PlaybackSession.swift:147-159` has no `webViewWebContentProcessDidTerminate`. Reopening the same channel does nothing (`:60`), and Retry only appears when the status text contains "failed" or "Could not" (`App/WatchView.swift:88`).
- **What happens:** iOS jettisons the content process under memory pressure. The player goes blank, the status still says something like "Video playing", there is no Retry button, and reopening the channel does nothing.
- **Fix:** implement that delegate method to reset `isPlaying`, set an explicit failed state, and reload. Drive Retry from that state instead of matching status strings.

**5. Medium: the release player host gets cut off, and an empty config ships silently.**
- **Where:** `Config/App.xcconfig:3-4`, `Player/PlayerConfiguration.swift:8-10`.
- **What happens:** following the status doc's step 3 and writing `TWITCH_PLAYER_HOST = https://host/` in `Config/Local.xcconfig` breaks, because `//` starts a comment in xcconfig files. The value becomes `https:`, it fails validation, and the build shows "Video isn't connected yet" with no build error. Separately, a machine without the git-ignored `Local.xcconfig` archives a build with an empty client ID and host.
- **Fix:** write the URL as `https:/$()/host/path`, or store just the host name and add `https://` in code. Add a Release-only build check that fails when either value is empty or invalid.

**6. Medium: restore runs only once at startup, so a temporary failure signs the user out for the whole session.**
- **Where:** `App/MainView.swift:55-60`, `TwitchAuth.swift:73-93`. `validateIfNeeded` returns early when there's no account (`:236`).
- **What happens:** on an offline launch or a Twitch 5xx, the user sees the Connect screen until they relaunch, even though their credentials are in the Keychain.
- **Fix:** call `restore()` again on becoming active and in the 60-second loop whenever there's no account and a saved record exists. `restore()` already guards against overlapping runs.

**7. Medium (test coverage): `ChatSession` has no tests.**
- At 314 lines it is the riskiest file. Migration, the watchdog, generation guards, send outcome, revocation and backoff are all untested.
- There are also no tests for refresh failure leading to sign-out, validate failing after a refresh, or restore being retried.
- `transport.webSocketTask` gives no way to inject a fake socket. A small socket protocol would let tests feed in frames.

**8. Low: your migration suspicion is confirmed, but it's bounded.**
- **Where:** the replacement socket and its timeout task are local and unstructured (`ChatSession.swift:207-218`). `stop()` and `connectionFailed` cancel only `migrationTask` and the current socket, which is still the old one (`:66`, `:69`, `:259`).
- **Why it lingers:** the async `URLSessionWebSocketTask.receive()` (bridged from a completion handler) ignores Task cancellation.
- **How long:**
  - Usually under a second: when Twitch's welcome arrives, the guard at `:221` closes the socket.
  - At most 25 seconds: only when no welcome ever arrives.
- **Impact:** the generation guard means the stale socket is never adopted. Twitch says reconnect-URL sockets don't count towards its 3-connection limit.
- **Fix:** keep a `pendingSocket` property that `stop()` and `connectionFailed` also close, or wrap the receive in `withTaskCancellationHandler` with an `onCancel` that closes the replacement.

**9. Low: messages can be dropped during the reconnect handoff.**
- **Where:** `ChatSession.swift:177-179` discards a frame the old loop already received once the socket has been swapped. `:224-227` closes the old socket immediately, losing anything still unread.
- **Why it matters:** Twitch says the old connection keeps receiving events until the new one's welcome arrives, and that following the reconnect flow means "no messages are dropped".
- **Fix:** let the old loop finish processing what it has, checking only the generation. Deduplication by message ID already exists.

**10. Low: "Chat resumed…" appears on every inactive→active transition.**
- **Where:** `MainView.swift:67-73`; `resume()` at `ChatSession.swift:85-90` doesn't check `suspended`.
- **What happens:** pulling down Notification Center or Control Center shows the gap notice even though the socket never stopped.
- **Fix:** guard on `suspended` in `resume()`.

**11. Low: after sign-out, the chat header still shows a green "Connected" dot.**
- **Where:** `App/AppModel.swift:53-57` stops chat but never resets `connection`; `NativeChatView.swift:16-17` draws the dot.
- **Fix:** set `.signedOut` when the account becomes nil.

**12. Low: one undecodable notification tears down the whole socket.**
- **Where:** `ChatSession.swift:191`, `:279-298`, `:196-198`.
- **What happens:** the app reconnects and shows a gap notice. The event ID was already added to the dedupe set before decoding, so any redelivery is skipped too.
- **Fix:** skip the bad event instead of failing the socket.

**13. Low: the player's navigation and bridge need hardening.**
- **Where:** `PlaybackSession.swift:162-166` checks only the origin's host, not its protocol or port. There's no `decidePolicyFor` and no `WKUIDelegate`.
- **What happens:** the main frame can be navigated away from the owned host, and `target=_blank` links inside the embed silently do nothing. The bridge only sets status strings, so the impact is limited to UX.
- **Fix:** allow only `https://<configured host>` in the main frame, open other links externally, and also check protocol and port.

**14. Low: player status can go stale.**
- **Where:** the `ONLINE` event is ignored (`PlaybackSession.swift:167-175`, `web-player/index.html:31`), and `didFinish` (`:147-149`) can overwrite an earlier status.
- **What happens:** a channel that goes from offline to live still says "This channel is offline". A host page that returns 404 shows as "loaded".

**15. Low: audio is activated when the player loads, before the user presses Play.**
- **Where:** `PlaybackSession.swift:82`, `:85-96`.
- **What happens:** the non-mixable `.playback` session interrupts the user's music as soon as the player loads. It is never deactivated with `.notifyOthersOnDeactivation`, and the `audioReady` flag never resets, so interruptions aren't handled. The API usage itself is correct, and the continuation resumes exactly once on every path.
- **Fix:** activate on PLAYING, deactivate when leaving the watch view, and observe audio interruptions.

**16. Low: the search field in a category view does nothing.**
- **Where:** `App/LibraryView.swift:24-28`, `App/LibraryModel.swift:37-46`.
- **What happens:** typing reloads the same streams (the list flashes empty) and the query is ignored.

**17. Low, plausible but not verified at runtime: Full video mode can leave a focused composer typing into a hidden field.**
- **Where:** `App/WatchView.swift:15-18`.
- **Fix:** clear focus when the mode becomes `.video`.

**18. Low: `block(userId:)` is unused and needs a scope the app never requests.**
- **Where:** `Twitch/TwitchAPI.swift:69-71`; the app doesn't request `user:manage:blocked_users`.
- **What happens if it's wired up as is:** the 401 forces a refresh (`:88-93`), using up a one-time refresh token. The retry then fails with a misleading "session expired" message.

## Known gaps (not counted as defects, and not runtime-proven)
- There's no client ID and no owned host, so auth, playback and chat are unproven live. PiP is disabled.
- The 400×300 gate is sharper than the docs suggest. In the default "Video & chat" layout, a compact iPhone's video area is about 210–225 pt tall after the details strip, so the player never shows. Only Full video shows it, and only on screens at least 400 pt wide. On narrower screens, no mode can show the player.
- "Slim chat" is identical to the default layout in compact width, and it isn't an overlay.
- Inline emotes and badges aren't rendered, and VOD, report/block and moderation UX are missing. `isMature` is decoded but never used.
- Browsing requires sign-in. That's a genuine platform limit, since app tokens need a client secret, and it should be documented.

## Objections to the docs and the brief
- **"Atomic Keychain refresh-token rotation":** the Keychain write is atomic, but the rotation isn't durable (finding 2).
- **"Authoritative send results":** not true across reconnects (finding 3).
- **"Saved per channel" drafts:** they live only in memory and are wiped when the account changes.
- **Unverified:** whether a subscribe call made after migration with the original session ID still works. Twitch's docs don't say whether the session ID survives a reconnect.
- **Score:** 6/10 for this source checkpoint. I estimate about 7.5 once findings 1–7 are fixed. This says nothing about official-app parity.
