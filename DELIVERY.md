# DuoTwitch delivery

Owning work: [personal-ops #208](https://github.com/saphid/personal-ops/issues/208).

## Current internal TestFlight — 5 November 2026

**0.1.0 (202611051233)** is available for internal testing. Fresh Apple API
readback verifies `VALID`, `INTERNAL_ONLY`, and `IN_BETA_TESTING`, with explicit
build relationships to the existing internal **Alex**, **t3crew**, and **DuoCrew** groups.
This update is a test candidate; the reported physical Duo one-second-stop is
**not yet confirmed fixed**.

- [Build details](https://appstoreconnect.apple.com/apps/6831008730/testflight/ios/6e23b54b-5812-48a9-ba3f-22bc4428e10b).
- Public source: [saphid/duotwitch](https://github.com/saphid/duotwitch).
- Archived source: [679bdf0](https://github.com/saphid/duotwitch/commit/679bdf0142e604ca4ceaf4d22152ce418e29f915).
- Minimum iOS version: **27.1**.
- Alex: Alexander Southwell retains internal build access. His earlier explicit
  TestFlight invitation POST returned HTTP 201 and readback showed INVITED.
  Inbox delivery and installation on the affected Duo remain unverified.
- t3crew retains Nikolas Kitsios, Julius M, Alex Jankowiak and Alexander Southwell.
  Current tester readback has one INSTALLED and three INVITED; this does not
  establish which build is installed or that the new update reached a device.
- DuoCrew is internal, has the new build, and currently has no members while
  Andy's Apple team invitation is pending acceptance.
- No public beta, external beta review or App Store submission was created.

The new update and public repository were sent to **T3Code (dev) → #txt** at
**12:44:08 UTC**. Beeper readback verifies the complete message after HTML
normalization, the sender and absence of a reply chain. Native Discord message ID
and Discord-side placement were not independently verified. Private receipt:
`build/testflight/playback-account-discord-receipt.json`. The first-build announcement
at 10:11:06 UTC remains historical and was not duplicated verbatim.

## What changed and what is verified

The source distinguishes ordinary system audio inactivity from genuine
interruption, instead of pausing video on every system deactivation. A recorded
red regression and current green tests demonstrate this source defect and its
correction, including genuine interruption after inactivity. It does not establish
that this was the physical phone's exact trigger.

Native playback controls remain visible. Portrait video/chat reserves the
supported 400×300 player plus the native rail when space permits. Channel details
and full status are available from the info button. Twitch connection now uses a
system-hosted, non-ephemeral approval browser, prefilled activation when supplied
by Twitch, resumable cancellation and secondary manual-code fallback. Post-exchange
validation has its own retry window independent of the consumed challenge expiry.

**74 signed Simulator tests passed**, zero failed/skipped, actual exit 0 and empty
xcresult runtimeWarnings. A disclosed AccountView presentation-anchor deprecation
remains; this is not a warning-free compilation claim. The fresh Codex / GPT-6.1 Sol
high independent-session [source review](docs/council/playback-account-review3-sol.md)
completed with no actionable P0–P3 findings. Same model as the author; no model diversity.
[Source manifest](docs/council/playback-account-delivery-source-sha256.json): 44 entries.

Current runtime verified all 44 source and 12 candidate/installed bundle files at
both boundaries. Portrait video/chat, persistent controls, native Pause, Full video
and details worked. All three Play actions had fresh official Unmute readback.
However, real captured imagery was nearly static: sustained changing video and
resume remain **unproven**. Logs captured no native automatic Pause/audio event
after Play; brief provider PAUSE events recovered to PLAYING. PLAYING alone is not
proof of usable moving video. Report: `build/proof/playback-account-delivery/REPORT.md`.

A second-channel differential found Monstercat offline and ESLCS online, but could
not reliably verify the official Unmute label after muting. It stopped **before
Play**, preserving the silence requirement. Report:
`build/proof/playback-account-motion-differential/REPORT.md`.

The preceding 73-test runtime verified prefilled Twitch handoff, cancellation and
reopening the same challenge, plus about 70 seconds of moving content and stable
Pause UI; sustained resume failed. Its accidental Safari handoff means that entire
historical run cannot be certified silent. It remains attributed to its original
candidate: `build/proof/playback-account/REPORT.md`.

## Internal DuoCrew on both apps

DuoCrew remains internal on DuoTwitch and Duocord. DuoTwitch now has build
`202611051233`; the existing Duocord build `202611050134` was preserved.
The unused external group is retained as **DuoCrew External (unused)**, without
assigning a build. No Duocord source or build was changed by this update.

Andy Neggles was sent an App Store Connect team invitation, accepted by Apple
with HTTP 201, for limited MARKETING access to exactly DuoTwitch and Duocord.
Fresh readback still finds that pending invitation. Apple previously returned
HTTP 409 when assigning his tester identity to an internal group before acceptance.
Both apps' internal membership still needs to be added after he accepts. A team
invitation is not a TestFlight invitation or proof of inbox delivery. His supplied
email and raw user receipts remain private.

## Identity and archive

- Product/display name **DuoTwitch**, bundle `com.saphid.duotwitch`, Apple app `6831008730`.
- Team `NJZUMEA4BN`, registered bundle `BXXWR6ZCZ7`, SKU `duotwitch-ios`, locale en-US.
- Build ID `6e23b54b-5812-48a9-ba3f-22bc4428e10b`.
- Public Twitch client `xuaoegs6v9yy1dw86gemt4gyuqtf1o`, registration Saphid Duo Viewer, PUBLIC.
- Player host `https://saphid.app/apps/duotwitch/player/index.html`.
- Archive `build/testflight/202611051233/DuoTwitch.xcarchive`.

Archive, export/upload and fresh strict/deep archive signature verification exited
**0**. Archived Info.plist/signature verify the bundle, team, version/build, public
client and owned player host. Export requested `testFlightInternalTestingOnly=true`.
Processing, three internal group relationships and exact en-US What to Test notes
were read back after assignment. Final private receipt:
`build/testflight/playback-account-delivery-final.json`. Credentials stay outside Git.

The first delivered build `202611050949`, source d87901e, remains historical.
An earlier attempt `202611050926` exited 75 at its disk reserve before compiling.
This update began with about 99 GiB free; no disk cleanup was needed.

## Remaining beta limits

Physical Duo OPEN/fold playback, PiP, background recovery, physical audio ownership,
large text/VoiceOver and complete accessibility remain unverified or unfinished.
Native chat sending was not exercised. Historical 62-test runtime verified OAuth,
discovery, received native chat, authenticated relaunch and draft continuity;
67-test runtime verified native Play/Pause/resumed gameplay. Neither is relabeled
as this archive or physical-device proof. The product council gate remains WITHHOLD.

Playback verification must remain inaudible: verify official per-player mute or a
supported silent Simulator route before every Play, including after recreation or
channel change. If silence cannot be verified, do not start playback. Do not change
global Mac audio for unrelated applications. No physical device was operated here.
