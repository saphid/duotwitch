# Source review fix checkpoint 3 — 5 November 2026

Prior review: `source-review-2-opus.md`, Claude Opus 5.5 xhigh through T3,
completed, 7/10 source quality. No product or parity score is implied.

## Changes

- Audio inactivity distinguishes app-requested deactivation from a system
  interruption. Only active playback reacts to a system interruption; offline
  and failure states survive. Audio transitions are serialized, including a
  pause during activation; normal pause releases audio on its player event.
- Session maintenance uses `.task(id: phase)`, so backgrounding cancels its
  minute loop and activation starts a current one.
- Successful library loads retain their key and pages on return from watching.
  Explicit refresh still reloads. Cancelled URLSession requests become
  CancellationError when their owning task was cancelled.
- Validation 401 shares refresh work before expiring credentials. Late
  responses for an older token cannot erase its replacement. Failed Keychain
  persistence warns visibly and retries while preserving a usable in-memory
  token. Account retry controls distinguish restoration and persistence.
- Chat sends refresh and retry once on an authoritative HTTP 401. Ambiguous
  outcomes are not resent. Pending sends retain account/channel identity across
  transport stops and channel switches, including AppModel's explicit clear.
  Results reconcile saved drafts/drop reasons even after the channel changes.
- Successful socket migration drains the previous socket for up to five seconds
  through deduplication, then closes it. Stop/failure closes both sockets.
  This is bounded draining, not proof of zero loss in every network condition.
  Reconnect backoff respects Twitch's rate-limit reset time.
- Player tests cover navigation origins, bridge origin/port/nonce/frame checks,
  uppercase host names, HTTP failure preservation, ONLINE and didFinish state,
  audio source/serialization, and content-process termination.
- Mounted layout tests now use the real native composer: synthetic book,
  tabletop, chat-side and slim-mode changes retain its instance, draft, selected
  text and first responder. Full video removes focus and keeps the draft.

## Verification

The 41-test and 43-test intermediate checkpoints passed. A later 44-test run
exposed a test scheduling race: pending-socket cancellation was observable
before its async cleanup changed the active connection. The timeout test now
waits for both cleanup and reconnect state. The following 44-test run passed,
with command exit 0 and no xcresult runtime warnings:
`build/verification/review3-final2-20261105.xcresult`.

One additional source fix and a stronger existing regression then preserved
pending-send account identity through AppModel's explicit clear/start sequence.
The final run passed all 44 tests with exit 0, no skipped tests and no xcresult
runtime warnings: `build/verification/review3-final3-20261105.xcresult`.
Owned temporary DerivedData cleanup completed. No app/test Swift warnings.

Real unsigned Release Simulator builds exercised the configuration guard under
the actual build-script sandbox. Missing configuration failed with expected
exit 65 and clear errors; synthetic public configuration passed with exit 0.
Logs: `build/verification/release-{missing,synthetic}-20261105.log`.
Synthetic values are not a registered client or deployed player host.

## Product constraints remain

No Twitch public client is registered. Twitch's authorized visible-browser SMS
resend failed; bounded private PA-Agent checks found no new code. No retry loop
or security-setting change was made.

Read-only GitHub REST checks found existing HTTPS Pages hosting at saphid.app
in saphid/saphid.github.io, main branch/root. The proposed deployment is only
`web-player/index.html` at `/apps/duotwitch/player/index.html`; no content has
been published yet. This offers a host path despite invalid Cloudflare access.

Live native auth/chat and production own-origin playback remain unverified.
The older DEBUG probe found unavailable system PiP and black rendering after
native fullscreen return. Compact embed minimum sizing, production
NavigationSplitView fold continuity, inline emotes/badges, mature/report/block,
VOD/clip and busy-chat soak remain open. No TestFlight upload, invitations,
final product council or official-app parity claim is appropriate yet.
