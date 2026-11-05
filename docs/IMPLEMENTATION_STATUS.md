# Current implementation checkpoint — 5 November 2026

The latest frozen source passes **74 signed Simulator tests**, zero failed or skipped,
command exit 0, with no xcresult runtime warnings. The AccountView presentation-anchor
fallback has a disclosed compiler deprecation; this is not a warning-free build claim.
All 44 source entries and all 12 candidate files are frozen in
`docs/council/playback-account-delivery-source-sha256.json` and
`build/verification/playback-account-delivery-bundle-sha256.json`.
A fresh Codex / GPT-6.1 Sol high independent-session review found no actionable
P0–P3 findings; see [review 3](council/playback-account-review3-sol.md).
The reviewer used the same model as the implementation author; no model diversity is claimed.

The source now distinguishes ordinary system audio inactivity from genuine
interruption, instead of pausing on every system deactivation. A recorded failing
regression and the current green run cover this path, including a real interruption
following inactivity. This is a demonstrated source defect and correction, **not a
confirmed diagnosis or resolution of the physical Duo OPEN-mode one-second-stop**.
Nonsecret native command/audio/host-event logs support the next runtime check.

Account connection uses a non-ephemeral system Twitch approval browser, the
provider-returned prefilled activation link when available, resumable cancellation,
and progressive code fallback. Validation after exchange has a separate retry window
from the consumed device code. Runtime on the earlier 73-test candidate verified
handoff/prefill/cancel/reopen, but not successful new approval or credential persistence.

Playback controls stay visible, channel metadata moves to a details sheet, and
portrait layout reserves the supported 400×300 embed plus its native rail where
sufficient room exists. Mounted tests include all production controls and require
all 20 tested sizes to play, using synthetic events and 150 ms observation. They
remain default-text-size layout tests, not sustained live playback/fold proof.

The earlier 73-test runtime recorded about 70 seconds of changing content and stable
Pause UI, but sustained resume failed. An unintended external Safari handoff means
that entire historical run cannot be certified silent. Its report remains
`build/proof/playback-account/REPORT.md`; it must not be relabeled as current evidence.
The current muted runtime verified native controls and portrait eligibility, but nearly static real-content captures did not demonstrate sustained motion or resume. No native automatic Pause/audio event followed Play. An alternative-channel check stopped before Play when mute could not be verified. Physical fold continuity,
PiP, background recovery and the complete accessibility journey remain unproven.

Internal TestFlight **0.1.0 (202611051233)** now contains archived source 679bdf0. Apple API readback verifies VALID, INTERNAL_ONLY, IN_BETA_TESTING and explicit Alex/t3crew/DuoCrew relationships. [DELIVERY.md](../DELIVERY.md) is the current delivery authority. The physical Duo fix remains unconfirmed.

## Historical checkpoints

The earlier dated material below is retained for provenance. Current source, test,
account-configuration and delivery statements above supersede its old blockers.

# Earlier implementation checkpoint — 5 November 2026

This is a compiled development candidate. It is not an official-app parity
pass and has not been uploaded to TestFlight.

Latest signed Simulator checkpoint: **69 tests passed**, with no failures,
skipped tests, Swift compiler diagnostics or xcresult runtime warnings. A real
Keychain read failed in the unsigned verification build and passed with Xcode
ad-hoc signing; no saved credentials were cleared. The new regression guards
this real application boundary. See `docs/council/signed-simulator-checkpoint.md`.
The registered public Client ID and deployed player host remain configured.
The preceding unsigned Release Simulator build passed its sandboxed config
guard; it is not a signed device archive.

The current candidate adds accessible native **Play video** through the official
Twitch embed `play()` method. It waits for READY, rejects hidden/undersized
video, bounds an unresponsive command to two seconds, and retains Pause and
channel-switch ordering. Only the production PLAYING event marks playback or
activates audio. The deployed host is unchanged. Five new regressions pass;
actual production Play/Pause/resume was verified on the preceding 67-test binary. The earlier 62-test
runtime proof below remains attributed to its original binary. See
`docs/council/native-play-checkpoint.md`.

The preceding 57-test binary passed the owned-origin live player flow: host events
**ONLINE → PLAYING → PAUSE → PLAYING**, native Pause and official resume, with
one player load. All 10 bundle files and 44 frozen source entries matched
before and after. See `build/proof/host-events-current/REPORT.md`.

That historical runtime check used the DEBUG player probe. The current signed
62-test candidate has now passed real native OAuth as `saphid`, populated Live
discovery, production WatchView opening and changing received native chat.
Account restored after process termination/relaunch without reauthorization.
All 44 source entries and all 12 candidate/installed bundle files matched at
both boundaries. See `build/proof/native-ssh/REPORT.md`.

A second bounded check verified chat left/right, Full/Slim modes and a real
keyboard-entered unsent draft surviving mode changes, Back/reopen and chat-side
changes. No message was sent. See `build/proof/native-ssh-followup/REPORT.md`.
The draft was discarded by terminating only the owned app process; saved
credentials were preserved. These checks used Alex's explicit SSH-control
exception after the repeated Device observation failure.

The 67-test production native Play path now has verified changing gameplay,
native Pause with stable pixels and native resume. The official player was
muted before further playback after Alex requested silence. See
`build/proof/native-play/REPORT.md`. The 69-test ordering fix has fresh test
evidence; those runtime frames remain attributed to the 67-test binary. The follow-up did not repeat failed Play pixel attempts. Actual fold/compact continuity, audible output, background recovery, PiP and
TestFlight remain unverified. The historical product judgment remains WITHHOLD;
its authentication/discovery/receive-chat blockers are superseded by this new
evidence, not its playback or delivery gates.

After Claude rate limiting stopped the source-review attempt,
Alex authorized a fresh Sol high review. That review passes at 8.5/10 with no
new actionable findings; see docs/council/source-configured-review-sol.md.
It is independent-session review without model diversity, and is a source
score only and belongs to the preceding 61-test source. The 62-test delta adds
only the real Keychain read regression; application code remains unchanged.
A fresh Sol high review of that signed checkpoint also passes at 8.5/10,
with no actionable findings. It retains the same runtime limits; see
docs/council/source-signed-keychain-review-sol.md.

Sol's product checkpoint **withholds sign-off**, with high confidence. It
independently verified all 44 source entries, all 10 bundle files and the actual
61-test xcresult, and inspected all eight official references and 28 candidate
screenshots. It assigned no overall current-product score. Authenticated
discovery/chat, current production WatchView, compact supported playback,
fold continuity, PiP and delivery remain unmet or unproven. The other final
council judges remain deferred under REQUIREMENTS.md. Full assessment:
`docs/council/product-checkpoint-7-sol.md` (Codex / gpt-6.1-sol, xhigh,
completed).

## Account recovery update — 05:59 UTC

The user-authorized MacBook Pro/Air recovery completed Apple sign-in using a
fresh Apple SMS. The supported ASC UI created app `6831008730` (DuoTwitch,
`com.saphid.duotwitch`, SKU `duotwitch-ios`, en-US, iOS). Live UI and complete
direct/exact API readbacks verified identity; no upload or invitation occurred.
This supersedes the earlier Apple 2FA/app-record blocker, not the product
assessment's other gaps. The unchanged source still has 61 passing tests.

Twitch's one fresh resend returned the same SMS-delivery error, with no new
code. The preserved challenge has no verified public client. The Air was
locked, so no GUI/session access was attempted there; no machine was unlocked
or woken. The recovery changed only delivery documentation and sanitized
receipts. T3 task
`node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3Aduotwitch-air-pro-cua-auth-recovery-20261105`
completed as Codex / gpt-6-astra, high. Receipt:
`build/mac-auth-recovery-20261105.json`; see DELIVERY.md for the access-save
warning and verified resulting access state.

## Implemented in source

- Native SwiftUI discovery for live/followed streams, categories and channel
  search; pagination, cancellation, empty/error states and native navigation.
- Public-client device authorization, immediate Keychain persistence of rotated tokens,
  single-flight refresh, startup/hourly validation and explicit sign-out errors.
- One retained WebKit player, an owned-origin official player host page and a
  nonce-scoped main-frame bridge. No private Twitch playback-token extraction.
- EventSub WebSocket native chat, reconnect handoff, keepalive detection,
  bounded/coalesced messages, moderation removal, reply and authoritative send
  results across transport reconnects. Drafts survive viewing-mode changes and
  are kept per channel in memory for this account session.
- Stable video/chat hosts through compact, split, left/right, slim and full-video
  preferences; active system fold regions keep video away from the division.
- Native quiet live chat, Dynamic Type, labeled controls and Reduce Motion
  handling for emotes. Emotes currently appear as a preview strip after text,
  not at their inline text positions; badge artwork is not rendered yet.
- Separate app identity, XcodeGen configuration and opaque 1024×1024 app icon.

## Verification actually performed

- Xcode 27.2 Swift syntax parse: exit 0 for all app and test Swift sources.
- XcodeGen project generation: exit 0 after the native screens were added.
- Icon metadata: 1024×1024, no alpha.
- Full Simulator build: exit 0 with Xcode 27.2 after storage recovered. The
  initial build had been deferred with exit 75 for insufficient space.
- Initial source type-check: exit 1, ENOSPC while importing AudioToolbox. Its
  task-owned 50 MB cache was removed; the later full build supersedes it.
- Unit tests: 13 passed, 0 failed on the owned iPhone 17 Pro / iOS 27.2
  Simulator. Result: `build/verification/tests-audio3-20261105.xcresult`, test
  command exit 0. Cover auth refresh rotation and sign-out
  failures, chat bounds/moderation, reconnect URL validation, fold geometry and
  retained player identity without real network navigation.
- The initial test run exposed synchronous audio activation warnings. The
  current candidate configures audio off the main thread and activates it
  asynchronously. Unit tests inject audio activation rather than touch the
  Simulator's real audio session.
- Review fixes: 27 tests passed, 0 failed, 0 skipped, no runtime warnings;
  command exit 0 on the owned Duo Simulator. Evidence:
  `build/verification/review-fixes3-20261105.xcresult` and matching `.log`.
  Seven ChatSession tests cover send success/drop across suspension/reconnect,
  old-channel acknowledgements, migration cancellation, malformed-event
  recovery/deduplication, revocation and inactive/active gap behavior.
  Auth tests now cover expired refresh 400, durable rotation despite validate
  500, and transient restore retry. Mounted ArrangementView tests measure
  synthetic book/tabletop divisions, either chat side and retained pane views.
  These mounted probes do not prove native composer focus or a physical hinge.
  One test-only UIWindow initializer deprecation remains; app sources compile
  without compiler warnings. AppIntents metadata emits the tool's usual skip note.
- The earlier audio3 binary was tested on iPhone by Astra. Real public LofiGirl
  playback advanced from 30.944 to 47.998 seconds with visible distinct frames.
  This is DEBUG direct-player feasibility evidence, not production embedding.
  App fullscreen preserved playback/load count. Native fullscreen return went
  black; background restoration did not prove visible playback recovery.
  System PiP was unavailable. Full evidence: `build/proof/iphone/REPORT.txt`.
  Its screenshots apply to the older binary, not the later review fixes.
- Current source also hides search when signed out or inside a category, gives
  toolbar controls explicit 44-point minimums, and removes the decorative
  sidebar symbol from its accessibility name. Updated UI proof is pending.
- Release builds now reject empty/invalid public client and player-host config.
  The configuration guard passed four direct cases. No archive, upload,
  authenticated feed/chat integration or parity comparison has passed.

## Required next evidence

1. Preserve sufficient build headroom. Storage recovered externally to 73 GiB
   before the successful build; this task deleted no additional data.
2. Complete mounted UI and live integration checks on the owned Xcode 27.2
   Simulator destinations. The 13 unit tests do not prove fold runtime or PiP.
3. Register/configure a Twitch public client. The reviewed player is deployed
   at `https://saphid.app/apps/duotwitch/player/index.html`. Put the public ID and host in ignored
   `Config/Local.xcconfig`; never put a client secret in this app.
   Use `Config/Local.xcconfig.example`: URLs require the xcconfig spelling
   `https:/$()/host/path` to avoid comment truncation. Visible Chrome is
   authorized and accepted the saved password, but Twitch requires an SMS code
   sent to the phone ending 20. The private code request closed without a code;
   no public client has been registered. Existing Cloudflare CLI access failed
   with invalid access token 9109; existing GitHub Pages hosting subsequently
   provided the verified player deployment.
4. Prove production own-origin Twitch playback, fullscreen, background/restore
   and real system Picture in Picture. The DEBUG probe found PiP unavailable
   and a native fullscreen return rendering failure. PiP/chat focus remains disabled until supported behavior
   is demonstrated. DEBUG probe code is diagnostic only.
5. Verify compact sizing: Twitch documents a 400×300 embedded-player minimum.
   This candidate offers an external Twitch link when the video area is too
   small. That limitation remains a material gap from the requested product.
6. Run mounted geometry, keyboard/selection continuity, VoiceOver, busy-chat
   soak, disconnect, moderation, send-failure and restricted-content checks.
   Mature-content gating, report/block flows, inline badges/emotes and VOD/clip
   support remain unfinished.
7. Capture matched official/candidate views, obtain Sol product judging and
   then the final council on one frozen candidate.
8. Create the App Store Connect app, archive and upload, then assign the exact
   verified Alex + T3 crew audience and read back beta availability.

The player-host deployment is complete. No account registration, invitation,
app-source commit or TestFlight upload has been made. See `DELIVERY.md` for the
audience inventory.

## SMS access follow-up

Alex explicitly directed use of PA-Agent for SMS retrieval. Its existing
`sms.imessage` adapter reaches the dedicated Air successfully. A bounded
read-only freshness comparison found that `immutable=1` omits uncheckpointed
Messages WAL changes. Keeping `mode=ro` and adding `PRAGMA query_only=ON` let a
one-shot in-memory use of the PA adapter find the original Twitch SMS. No
PA-Agent source, message database, index, or service configuration was changed.
No SMS body or verification code was printed or written to an artifact.

The original code was too old for the private paste helper's five-minute
freshness limit. Astra requested one normal resend in the already-authorized
visible Chrome window. Twitch displayed “Error encountered when sending SMS.
Please try again.” Three bounded private receipt checks and one later metadata
check found no fresh Twitch SMS. No code was submitted and no public client
was registered. Clipboard was cleared; the owned verification window remains
open. Sanitized receipt: `/tmp/duotwitch-visible-chrome-registration.json`.
Do not loop resends or request another private-entry card automatically.

## Latest source checkpoint

After source review 2 (Opus 5.5 xhigh, completed, 7/10 source quality), the
current candidate fixes app/system audio-inactivity handling, active-scene
maintenance, stale-validation races, nonblocking Keychain persistence retries,
library return context, and authoritative chat 401 refresh/retry. Pending
channel sends survive AppModel's explicit clear/start sequence; saved drafts
and drop reasons reconcile when their outcomes arrive. Handoff drains the old
socket for a bounded five seconds. Details: `docs/council/review-fixes-3.md`.

Final regression: **44 passed, 0 failed, 0 skipped**, command exit 0, no
xcresult runtime warnings on the owned Duo / iOS 27.2 Simulator.
Evidence: `build/verification/review3-final3-20261105.xcresult`, matching log
and `review3-final3-summary.json`. Owned temporary DerivedData cleanup completed.
The previous 44-test run exposed a test scheduling race, corrected by waiting
for async timeout cleanup; the following run and this strengthened regression
passed. App/test Swift compilation emitted no compiler warnings.

The mounted test now exercises the real native composer, retaining instance,
draft, selection and focus through synthetic divisions, slim mode and chat-side
changes; full video clears focus. This supersedes the earlier probe-only
limitation, but does not prove production NavigationSplitView fold continuity
or real hinge hardware behavior.

Unsigned Release Simulator checks ran through the real build-script sandbox:
missing config failed as intended (exit 65); synthetic public config passed
(exit 0). Those synthetic values are not operational credentials or hosting.
Logs: `build/verification/release-missing-20261105.log` and
`build/verification/release-synthetic-20261105.log`. No signed archive exists.

Read-only REST queries verified existing public GitHub Pages hosting in
`saphid/saphid.github.io`, main branch/root, HTTPS enforced at `saphid.app`.
The player URL is
`https://saphid.app/apps/duotwitch/player/index.html`; it is now published, as
recorded below. This is verified hosting, not live playback evidence.

The source review and product/delivery constraints remain separate. No public
Twitch client, production playback/chat proof, system PiP pass, official-app
parity verdict, TestFlight upload or invitation has been completed.

## Published host and checkpoint 4

The unchanged player page approved by Opus review 3 is now deployed to
`https://saphid.app/apps/duotwitch/player/index.html`. HTTPS GET returned 200
with byte-for-byte equality. See `docs/PLAYER_HOST.md` for commit and receipts.
This supersedes the earlier unpublished-host notes; it does not prove playback.

Current tests: **51 passed, 0 failed/skipped**, command exit 0, no Swift compiler
warnings or xcresult runtime warnings. Result:
`build/verification/review4-final-20261105.xcresult`. This development binary
uses the real public host and an empty Client ID. The source freezes and full
app-bundle hashes are retained for fresh source and UI checks.

Video shrinking now pauses through WebKit's public media API; audio release
and channel loads follow pause completion. Native pause remains accessible,
stale channel footer state is hidden, and navigation pins the host page path.
Device-code polling recovers from temporary network/server failures; explicit
tests cover its meaningful outcomes. New direct AppModel tests cover saved
draft reconciliation. Details and remaining caveats:
`docs/council/review-fixes-4.md`. No live auth/chat or TestFlight claim follows
from these tests. Source review 3 passed at 8/10; checkpoint 4 needs fresh review.

## Current-binary UI evidence

Astra high completed the bounded own-origin Simulator check without source
changes. All 10 installed bundle files matched on both owned devices, including
the debug dylib. The tested signed-out welcome, Account and navigation screens
were readable, without visible clipping or signed-out search. Accessibility
was partial: the Duo back control exposed a generic `BackButton` label; a full
VoiceOver journey was not performed.

The real host rendered Monstercat's official offline player and reported
`This channel is offline.` This proves the iframe/offline path, not video.
Changing to LofiGirl failed twice with `TEXT_ENTRY_MISMATCH` (the second attempt
used the prescribed slower retry). Astra stopped under the device-tool failure
rule. Moving video, native pause, fullscreen return, background recovery and
PiP remain untested on this candidate. No fresh result supersedes the old
fullscreen rendering failure. The Duo showed its inner display after an open
request, but the tool could not verify a hinge-angle sample.

Report: `build/proof/own-origin-current/REPORT.md`; sanitized command/identity
receipts and screenshots are alongside it. Both owned Device/app sessions
were closed, with no Simulator shutdown. T3 task
`node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A5a867cae-98a7-4aa0-8aaa-689c07ae7234`
completed as Codex / `gpt-6-astra`, high. The source review of this frozen
candidate is still pending; no executable files changed during the UI check.

## Checkpoint 5

Source review 4 passed at **8.5/10**, with no High or Medium findings. Its
remaining channel-switch cancellation, hidden-startup and pause-timeout issues
are addressed in checkpoint 5, together with direct regressions. The current
source also prevents an older pause result overriding a newer one, avoids a
duplicate chat reconnect on reopen, and has a DEBUG launch channel option for
playback checks without the failed text-entry operation.

Final owned Duo regression: **55 passed, 0 failed/skipped**, command exit 0,
no Swift compiler diagnostics or xcresult runtime warnings. Result:
`build/verification/review5-final2-20261105.xcresult`; source and complete
bundle manifests freeze this exact candidate. Temporary DerivedData cleanup
completed. See `docs/council/review-fixes-5.md` for changes and test scope.
Cross-origin/offscreen pause is still a runtime expectation to verify, not a
claim established by injected tests or the WebKit header.

Twitch registration is still blocked by the SMS delivery error. The host is
deployed; native live authentication/chat, current live playback, PiP, parity
and TestFlight delivery remain unproven. No source commit or invitation made.

A single later authorized visible-Chrome SMS resend again returned Twitch's
“Error encountered when sending SMS. Please try again.” Astra stopped: no
sign-in, client registration or public metadata file. Clipboard was cleared;
the owned verification window was preserved. No further SMS retry is queued.
Sanitized receipt: `/tmp/duotwitch-visible-chrome-registration.json`.
Task `node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A1791e748-e68f-4060-b437-c249ef4ff4c5`
completed as Codex / gpt-6-astra high. Source review 5 meanwhile passed at
8.5/10 with no High or Medium findings; source remains frozen during the
pending live playback check. Its two Low findings are recorded in
`docs/council/source-review-5-opus.md` and remain to be considered after UI work.

## Live playback milestone — 55-test frozen candidate

Astra's seeded-channel runtime check verified all 10 installed bundle hashes
and all 44 source hashes against checkpoint 5. LofiGirl played through the
deployed owned-origin page: real stream pixels changed across 10.622 seconds.
The actual native Pause control stopped the stream, with unchanged scene
pixels across 20.618 seconds; official Play resumed it. App fullscreen returned
to inline video. Native fullscreen exited while paused, then official Play
restored live video without a black screen. Load count remained 1. This is
rendering recovery after a paused native exit, not uninterrupted exit playback.

The production host ONLINE bridge path was observed. PLAYING attribution is
incomplete because the DEBUG observer shares its status label. Backgrounding
was not verified: the tool's Home command left the app foreground. No system
PiP affordance was demonstrated. Audio audibility, full WatchView folding,
native auth/chat, parity and TestFlight are not proven by this diagnostic.
Report: `build/proof/own-origin-seeded/REPORT.md`, with original PNGs, timed
pixel comparisons and complete identity receipts. Both owned sessions closed;
the Simulator remained running.

The separate Apple prerequisite registered and read back bundle identifier
`com.saphid.duotwitch`, ID `BXXWR6ZCZ7`. Apple returned UNIVERSAL despite an IOS
request; no further capability/platform change was made. The app record is
still absent. The first bounded Apple preflight stopped at the preview login
page; a saved-account/existing-browser path must be checked before declaring
human sign-in necessary. See DELIVERY.md and the sanitized receipt.

After this frozen runtime proof, source fixes address leaving-watch hidden
playback, clearing only recovered pause-timeout failures, and the late-refit
message. The DEBUG probe also separates host event telemetry from observer
state. These changes are undergoing fresh verification and do not alter the
identity or scope of the already-captured 55-test proof.

Checkpoint 6 verification completed: **57 passed, 0 failed/skipped**, command
exit 0, no Swift compiler diagnostics or xcresult runtime warnings. Result:
`build/verification/review6-fixes-20261105.xcresult`. Source/bundle manifests
freeze this candidate for independent review; its Host event diagnostic still
needs runtime readback. See `docs/council/review-fixes-6.md`.

The saved Apple password was accepted in the follow-up ASC sign-in. Apple then
required a code sent to trusted devices; no code was available. This is a
confirmed 2FA blocker, superseding the earlier preflight-only login boundary.
The final exact app query at 03:28:32 UTC still reported zero records. The owned
ASC window closed; original tabs and Twitch window were preserved and clipboard
cleared. No app creation, uploads or invitations occurred.

A private Apple trusted-device code card was opened once and timed out without
a value. No secret file/reference was delivered and no further card is queued.
Apple app creation therefore remains blocked at verified 2FA; this does not
affect the already-verified bundle registration or live playback evidence.

## Current production bridge runtime evidence — 57-test candidate

Astra high completed task
`node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A8388a8b6-8e7c-44d7-8f91-73cea4fc157e`
as Codex / `gpt-6-astra`, high reasoning. Its separate Host event label is
assigned only by accepted production bridge events, so this closes the earlier
DEBUG-observer ambiguity for this bounded flow. Real stream pixels changed
over 16.753 seconds; after native Pause, the paused scene stayed identical over
20.401 seconds. Official Play restored live video and the production PLAYING
event, with player loads still 1.

All 10 candidate/installed bundle files and 44 source entries matched at both
boundaries. Debug dylib SHA256:
`3f712f56c1848768d91f2281af147ca5adbd170ed9e59507ce7227b8d5587251`.
Report, full identity receipt, action readbacks and original screenshots are in
`build/proof/host-events-current/`. The owned app and Device session closed;
the Simulator remained running. No source, account, chat or delivery changes
were made by this check. Full WatchView, fold, leave-Watch, timeout recovery,
background, audible output and PiP were outside its scope.
