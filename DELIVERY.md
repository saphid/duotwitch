# DuoTwitch delivery

Owning work: [personal-ops #208](https://github.com/saphid/personal-ops/issues/208).

User-authorized target: a native Swift iPhone/iPhone Duo app in TestFlight, with an invitation for Alex and the T3 crew group included. Production App Store submission and public beta links are outside this request.

## Identity and tooling

- Product/display name: DuoTwitch.
- Separate bundle identifier: `com.saphid.duotwitch`.
- Existing Apple team from the reference app: `NJZUMEA4BN`; verify the actual archive's signing team before upload.
- Use `/Applications/Xcode-27.2.0.app/Contents/Developer` explicitly as `DEVELOPER_DIR`.
- Existing protected ASC credential config: `~/.appstoreconnect/frame-control.json`. Never commit, print or copy credential values.
- The reference app's scripts in `/Users/saphid/.t3/projects/duocord-native/scripts` demonstrate signing and release readback; changes to that source are out of scope.
- Dedicated Simulator IDs live in ignored `build/devices/duo-id` and `build/devices/iphone-id`. They belong to this work. Do not operate another project's Simulator.

## Prerequisite evidence, 5 November 2026

At 2026-11-05 03:19 UTC, the dedicated bundle identifier `com.saphid.duotwitch` was registered as `DuoTwitch`, record `BXXWR6ZCZ7`, using the existing configuration for team `NJZUMEA4BN`. Fresh exact bundle and app queries first returned HTTP 200, total zero, with no next page. Registration returned HTTP 201; direct GET and a complete exact query then returned the matching bundle identity. The POST requested platform `IOS`; Apple returned `UNIVERSAL`. That discrepancy is recorded without further platform or capability changes.

The app record remains absent: fresh exact app queries returned HTTP 200, total zero, with no next page at 03:25:39 and 03:28:32 UTC. The earlier preview login screen was only an untested authentication path, not evidence of a human-only blocker. The authorized continuation inspected existing Chrome tabs and opened its own ASC window in the existing Alex profile. That session required login. A bounded Common Web lookup found one matching saved Apple account with an iTunes Connect URL; its saved password was pasted directly into Apple's secure field and accepted. Apple then displayed **Two-Factor Authentication — “Enter the verification code sent to your Apple devices.”** The six code fields were empty, the matching saved account had no TOTP field, and no trusted-device code was available to this task. This is the confirmed blocker. No code was entered, guessed or resent; no SMS retrieval, passkey attempt, security change or legal acceptance occurred. The clipboard was cleared and verified. The owned ASC tab/window was closed and its absence verified; both pre-existing ASC tabs, the Twitch SMS-error window and unrelated tabs were preserved.

After trusted-device authentication is available, verify the web account's team is `NJZUMEA4BN`, re-query to avoid duplicates, then create the iOS app for this exact bundle with name `DuoTwitch` (authorized fallback: `DuoTwitch by Saphid`), primary language English (US), SKU `duotwitch-ios`, and Full Access if required by the form. These app attributes remain requested values, not persisted/read-back values. No app creation was attempted because authentication did not complete and the web team could not be verified. Apple's documented API explicitly does not create new apps; the App Store Connect website is the supported route. Source: [Apple Apps API](https://developer.apple.com/documentation/appstoreconnectapi/apps).

Sanitized prerequisite receipt: `build/asc-app-record-prerequisite.json` (ignored). This continuation ran directly as OpenAI `gpt-6-astra`, high reasoning, through Codex/T3 Code, with no delegation. Earlier source-freeze verification is historical only; parent source edits and tests are ongoing, and this continuation did not re-read or claim those hashes as current. Only this delivery note and the sanitized receipt were edited. No bundle, app, source, executable, configuration, archive, upload, invitation, group, provisioning-profile or production-release changes were made by this continuation. The app still needs the Twitch public client (currently blocked by Twitch's SMS delivery error) and native auth/chat/live playback/PiP/parity evidence before TestFlight delivery.

Narrow 1Password title scans found the existing `saphid` Twitch account in the Games vault; they did not identify an existing developer registration in Common Web, Domains and Cloud stuff, Apps or Games. This is not an exhaustive claim of absence. `pa-memory` returned unrelated/older account integration references; that is incomplete evidence.

Planned Twitch developer registration if none exists: DuoTwitch, public client, application integration, the existing `saphid` account. Use the supported public-client OAuth flow; never embed a client secret or reuse another application's client ID. Twitch describes Client IDs as public configuration: [Register an app](https://dev.twitch.tv/docs/authentication/register-app/). This record is a concrete plan, not a claim that registration has happened.

An authenticated, complete group listing found the exact `t3crew` internal group on Duocord. Its related tester collection returned three testers, reported total three, with no next page: Nikolas Kitsios, Alex Jankowiak and Julius M. Alex is already part of the requested crew audience. Preserve those existing tester identities when preparing DuoTwitch's own internal group. Private tester IDs and membership readback are in ignored `build/t3crew-audience.json`; the sanitized group inventory is in `build/testflight-audience-preflight.json`. No invitations or membership changes have been sent.

## Verification and delivery sequence

1. Initial council assessment; native implementation; focused tests, Simulator layout and live integration evidence; Sol judging until competitive with the official reference; final council on the same candidate.
2. Obtain fresh independent read-only source review after focused tests. Preserve actual model/provider/task IDs and results.
3. Register the separate bundle and app, using existing team identity. Verify app record and signing prerequisites. Keep the original Duocord app untouched.
4. Archive with a strictly increasing UTC timestamp build number. Verify archived bundle, display name, build number and signing team; export and upload through Xcode.
5. Read back Apple processing for that exact build. `VALID` alone is not TestFlight availability.
6. Resolve Alex and the T3 crew audience from existing records. Do not guess addresses, add unrelated testers, or silently substitute a different group. An external crew group can require Beta App Review; distinguish submission from approval/availability.
7. Assign the exact build to the authorized audience and send only the requested TestFlight invitation. Verify the persisted group/tester membership, invitation outcome and testing state.
8. Preserve signed artifact location, release notes, source manifest, real command exits, readback receipts and remaining limitations. Claim available only when the intended audience can actually test the build.
