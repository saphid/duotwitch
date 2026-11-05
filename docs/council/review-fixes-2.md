# Source review fix checkpoint 2 — 5 November 2026

Prior review: `source-review-1-opus.md`, Opus 5.5 via T3, 6/10 source-only.
This checkpoint has no new parity score.

## Changes awaiting fresh independent review

- Refresh 400/401 expires the account and clears saved credentials; both
  restore and sign-out reset the restoration state. Refresh work is cleared
  on invalidation. Authorization cancellation has a separate identity from
  account/refresh transactions.
- A successful refresh saves its rotated credentials before validation;
  failed saves preserve the replacement in memory for a later persistence
  retry. Validation failures retain the new token pair. Refresh remains
  single-flight even after an in-memory rotation updates the expiry date.
- Session maintenance retries transient restoration failures on activation
  and every minute. Account offers Retry connection.
- Chat send transactions survive socket generation changes, suspend and
  reconnect. Account/channel clear invalidates them. No automatic resend.
- Injectable ChatSocket wrapper enables direct session tests. Stop/failure
  closes pending migration sockets. A frame already received by the old loop
  can finish processing during handoff. Malformed notifications are skipped
  before dedupe insertion. Resume requires an actual suspension; clear resets
  the connection to signedOut. Expired/missing-scope errors do not reconnect.
- Player process termination, navigation errors and HTTP errors have explicit
  retryable failure state. Retry no longer matches localized status strings.
  Production bridge checks scheme/host/port/nonce. Main-frame navigation stays
  on the configured HTTPS origin; external user links open outside the player.
  ONLINE clears stale offline wording; didFinish preserves bridge status.
- Audio activates on PLAYING, is serialized with deactivation, releases on
  leaving the watch view, and pauses on iOS 27 audio-session inactivity.
- Release configuration guard rejects missing/invalid config. The example
  shows xcconfig-safe URL escaping. Unused unsupported block API removed.
- Search is hidden in a category and while signed out. Full-video change
  removes composer focus. Toolbar controls have explicit minimums and the
  decorative sidebar symbol has a meaningful single accessibility name.

## Real verification

27 tests passed, 0 failed/skipped, command exit 0; xcresult runtimeWarnings empty.
`build/verification/review-fixes3-20261105.xcresult`, matching `.log`.
Mounted tests use probe UIView hosts and synthetic divisions: they establish
pane geometry and pane identity, not keyboard or real hinge continuity.
Compiler note: one test-only UIWindow(frame:) deprecation; no app-source warnings.
Release guard: four direct positive/negative cases passed.

## Product objections still open

No registered public Twitch client or deployed owned player origin. The old
DEBUG binary visibly played LofiGirl, but PiP was unavailable and native
fullscreen return went black. Minimum embed size blocks common compact modes.
No live native chat/auth, moderation UX, inline emote/badge parity, VOD/clip,
physical-device hinge, busy-chat soak or TestFlight proof. No final council
or official-app parity claim is appropriate yet.
