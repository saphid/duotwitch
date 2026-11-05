# DuoTwitch delivery

Owning work: [personal-ops #208](https://github.com/saphid/personal-ops/issues/208).

User-authorized target: a native Swift iPhone/iPhone Duo app in TestFlight, with an invitation for Alex and the T3 crew group included. Production App Store submission and public beta links are outside this request.

Latest explicit instruction: playback verification must be inaudible to Alex.
Before playback, verify a per-player mute or a supported silent Simulator audio
route; do not infer headphones are inaudible or change global Mac audio for
unrelated applications. This requirement was sent to the active Astra runtime
worker immediately. No current silent-routing success is claimed yet.

Alex also explicitly authorizes sharing the verified TestFlight details and
Git repository in `#txt` on the T3Code dev Discord server. Resolve the exact
channel, send only after real build/audience/repository readback, and retain a
message receipt. No broad mentions or public TestFlight link are authorized.


## Identity and tooling

- Product/display name: DuoTwitch.
- Separate bundle identifier: `com.saphid.duotwitch`.
- Existing Apple team from the reference app: `NJZUMEA4BN`; verify the actual archive's signing team before upload.
- Use `/Applications/Xcode-27.2.0.app/Contents/Developer` explicitly as `DEVELOPER_DIR`.
- Existing protected ASC credential config: `~/.appstoreconnect/frame-control.json`. Never commit, print or copy credential values.
- The reference app's scripts in `/Users/saphid/.t3/projects/duocord-native/scripts` demonstrate signing and release readback; changes to that source are out of scope.
- Dedicated Simulator IDs live in ignored `build/devices/duo-id` and `build/devices/iphone-id`. They belong to this work. Do not operate another project's Simulator.

## Prerequisite evidence, 5 November 2026

**Current prerequisite status:** Apple app `6831008730` and Twitch's dedicated
PUBLIC client are both created and verified. The Twitch registration name is
Saphid Duo Viewer; the native app remains DuoTwitch. Public Client ID:
`xuaoegs6v9yy1dw86gemt4gyuqtf1o`. See [public-client evidence](docs/PUBLIC_CLIENT.md).
The source now contains the public configuration; 62 signed Simulator tests
and the preceding unsigned Release Simulator build pass. Native OAuth, Live discovery, received production chat and authenticated relaunch
are verified on the signed 62-test candidate. Full/Slim and chat-side changes
retain a real unsent draft across Back/reopen. Production moving video,
fold continuity, PiP and product/delivery gates remain open. Reports:
`build/proof/native-ssh/REPORT.md` and
`build/proof/native-ssh-followup/REPORT.md`. No message was sent. The account-recovery attempts below are historical.

At 2026-11-05 03:19 UTC, the dedicated bundle identifier `com.saphid.duotwitch` was registered as `DuoTwitch`, record `BXXWR6ZCZ7`, using the existing configuration for team `NJZUMEA4BN`. Fresh exact bundle and app queries first returned HTTP 200, total zero, with no next page. Registration returned HTTP 201; direct GET and a complete exact query then returned the matching bundle identity. The POST requested platform `IOS`; Apple returned `UNIVERSAL`. That discrepancy is recorded without further platform or capability changes.

The App Store Connect prerequisite is now complete. On 5 November 2026 at 05:54:42 UTC, the supported New App UI created [DuoTwitch](https://appstoreconnect.apple.com/apps/6831008730/distribution/info), Apple app ID `6831008730`, for `com.saphid.duotwitch`, SKU `duotwitch-ios`, primary locale `en-US`, and iOS. Live App Information readback and HTTP 200 direct/exact app queries verified these persisted values. The exact query returned one record with no next page. The initial iOS 1.0 version is `PREPARE_FOR_SUBMISSION`; this is not a build upload, TestFlight availability or public submission.

The Pro's existing ASC session expired when the New App form opened. Saved-account sign-in then succeeded using one fresh Apple SMS obtained through the authorized PA read-only route; the browser trust prompt was declined with “Not Now.” The Pro's System Settings confirmed it is trusted, but the inspected surfaces offered no Get Verification Code control and no sign-in notification was observed. The Air was locked, so its GUI and browser sessions were not accessed. No machine was unlocked or woken. No account security settings changed.

The form selected Full Access. Apple displayed “Your user access settings could not be saved,” together with explicit confirmation that DuoTwitch was created and all users currently have access. That observed access outcome matches the requested Full Access; no subsequent access changes were made. The existing bundle remains `UNIVERSAL`, with team seed `NJZUMEA4BN`; no bundle or capability changes occurred.

Twitch remains blocked by its live “Error encountered when sending SMS. Please try again.” response. The single permitted fresh Twitch resend was attempted at 05:55:29 UTC, and two bounded, fresh-challenge-scoped SMS checks returned zero results. No further resends or old codes were used. The original Twitch challenge remains in Chrome window `22966`, tab “Log In - Twitch”; its unrelated selected tab was restored. No dedicated public client or Client ID has been created or verified.

Sanitized receipts: `build/asc-app-record-prerequisite.json` and `build/mac-auth-recovery-20261105.json` (ignored). Prior attempts remain in the prerequisite receipt's history. This recovery ran personally as OpenAI `gpt-6-astra`, high reasoning, through Codex/T3 Code with no delegation. The owned System Settings window was closed and its absence verified. Existing ASC and Twitch tabs and unrelated windows/profiles were preserved, original selected tabs restored, and the owned secret clipboard cleared conditionally and verified. Only this delivery note and sanitized receipts were edited. No app source, builds, Simulator, uploads, invitations, publication, or other app changes occurred. The app still needs its Twitch public client and native auth/chat/live playback/PiP/parity evidence before TestFlight delivery.

After Alex confirmed the Air was unlocked, fresh session metadata showed an
active console login without a locked flag. Scoped CUA checks still found no
usable Air driver. The existing Screen Sharing service responded, but required
the Air's macOS login password; scoped 1Password metadata checks found no
matching credential. Astra cancelled the owned connection and verified zero
remaining Screen Sharing windows. No browser session, credentials or SMS were
accessed in this attempt. Receipt:
`build/mac-air-twitch-recovery-20261105.json`. A subsequent parent-issued
private Mac login password card timed out without a value or secret file.
No further credential card is queued. The current Air blocker is Screen
Sharing authentication, superseding its earlier locked-screen boundary.

Narrow 1Password title scans found the existing `saphid` Twitch account in the Games vault; they did not identify an existing developer registration in Common Web, Domains and Cloud stuff, Apps or Games. This is not an exhaustive claim of absence. `pa-memory` returned unrelated/older account integration references; that is incomplete evidence.

Twitch registration is now verified under `saphid` as Saphid Duo Viewer,
PUBLIC, Application Integration, with development redirect
`https://saphid.app/apps/duotwitch/oauth-callback`. The console rejected the two
earlier DuoTwitch-containing names; no precise cause was established. Reloaded
Manage details and an inventory of exactly one application confirmed the
saved public client. No secret was created and no callback implementation is
claimed. Use the supported public-client Device Code Flow; never embed a client
secret or reuse another application's Client ID. Twitch describes Client IDs
as public configuration: [Register an app](https://dev.twitch.tv/docs/authentication/register-app/).

An authenticated, complete group listing found the exact `t3crew` internal group on Duocord. Its related tester collection returned three testers, reported total three, with no next page: Nikolas Kitsios, Alex Jankowiak and Julius M. Alex is already part of the requested crew audience. Preserve those existing tester identities when preparing DuoTwitch's own internal group. Private tester IDs and membership readback are in ignored `build/t3crew-audience.json`; the sanitized group inventory is in `build/testflight-audience-preflight.json`. No invitations or membership changes have been sent.

## Delivery preparation after renewed TestFlight instruction

A fresh exact app build query returned HTTP 200 with no builds. GitHub lookup
for `saphid/duotwitch` returned not found, and this checkout has no remote;
repository creation/push is still pending reviewed source. Alex explicitly selected public visibility for Discord source access. The
repository is created at https://github.com/saphid/duotwitch; push is pending
fresh source review.

Created DuoTwitch's own internal `t3crew` group after a complete app-scoped list
returned zero groups. Apple returned HTTP 201; group ID
`d5e47889-3cb9-4199-9164-2ab484f9a3f2`. The source `t3crew` group's fresh complete
membership still contains exactly the same three existing testers. Adding
those identities to the new group returned HTTP 409, `STATE_ERROR`,
"Tester(s) cannot be assigned". Readback confirms zero members. Do not claim
crew access or repeat the same mutation without resolving its prerequisite.
Ignored receipts: `build/duotwitch-t3crew-group.json` and associated
`duotwitch-t3crew-*`/`duotwitch-group-members-readback.txt` files. No invitations
or build assignments have succeeded.

Beeper lookup succeeded when scoped to the Discord account after an initial
unscoped 500. It found one `#txt` chat (Beeper chat `1116`, underlying room
`!d8plVzrUmOEsSKa6IHRR:beeper.local`). Recent context includes the T3 Code dev
participants, but exact Discord server identity still needs corroboration.
The newest observed sort key is `282816`. No announcement has been sent.
The Discord-history archive fallback returned `operation_failed`; no direct
Discord fetcher or limiter bypass was used. Use Beeper and a fresh duplicate
check before the authorized final message. Keep conversation content private.

## Verification and delivery sequence

1. Initial council assessment; native implementation; focused tests, Simulator layout and live integration evidence; Sol judging until competitive with the official reference; final council on the same candidate.
2. Obtain fresh independent read-only source review after focused tests. Preserve actual model/provider/task IDs and results.
3. Register the separate bundle and app, using existing team identity. Verify app record and signing prerequisites. Keep the original Duocord app untouched.
4. Archive with a strictly increasing UTC timestamp build number. Verify archived bundle, display name, build number and signing team; export and upload through Xcode.
5. Read back Apple processing for that exact build. `VALID` alone is not TestFlight availability.
6. Resolve Alex and the T3 crew audience from existing records. Do not guess addresses, add unrelated testers, or silently substitute a different group. An external crew group can require Beta App Review; distinguish submission from approval/availability.
7. Assign the exact build to the authorized audience and send only the requested TestFlight invitation. Verify the persisted group/tester membership, invitation outcome and testing state.
8. Preserve signed artifact location, release notes, source manifest, real command exits, readback receipts and remaining limitations. Claim available only when the intended audience can actually test the build.
