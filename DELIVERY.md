# DuoTwitch delivery

Owning work: [personal-ops #208](https://github.com/saphid/personal-ops/issues/208).

## Next candidate — layout continuity and owned-network diagnostics

Source review is complete with no actionable findings after correcting both
narrow-width and accessibility-control-height allocation.102signed iOS tests and
28receiver tests pass; signature verifies. See
[checkpoint](docs/council/playback-followup-20261106.md) and
[fresh recheck](docs/council/fullvideo-accessibility-review-sol.md).
Current muted runtime and new TestFlight delivery remain pending.

The new lxso1 receiver is now active: two identical real HTTPS pushes returned204,
with exact one-record SSH readback. All pre-existing Serve/Funnel routes are
preserved. The next app source targets it by default; the currently distributed
build still targets the blocked lxso2 receiver. Phone connectivity/permissions
and automatic receipt remain unverified.

Alex confirms the delivered202611052312build continues open-mode playback.
The follow-up layout correction addresses a production-mounted insufficient-space
Pause after Full video exit; physical resolution is not yet confirmed. Outside
screen says “Video needs more room”; historical382-point allocations cannot host
the supported400×300embed in portrait. Rotation guidance is provided; portrait
outside playback, fold continuity and PiP are not claimed.

## Distributed internal TestFlight — WebKit audio ownership candidate

**0.1.0 (202611052312)** is available to the existing internal **Alex**, **t3crew**
and **DuoCrew** groups. Apple readback verifies `VALID`, `INTERNAL_ONLY`,
`IN_BETA_TESTING` and each complete explicit group/build relationship. Notification
was requested; inbox delivery, tester installation and physical playback recovery
remain unverified. The exact en-US What to Test notes were read back.

The supplied physical log shows native audio activation beginning immediately
before both short playback attempts stop. This build removes competing native
audio category/activation/deactivation writes and leaves media audio ownership
with WebKit. It retains native media controls and genuine interruption handling.
This is a trace-supported candidate fix, not a confirmed physical resolution.

Automatic allowlisted diagnostic upload attempts are enabled by default. The
owned receiver currently rejects writes because its disk is full; **working
automatic collection is not claimed**. Local export remains independent. The
phone also needs existing Tailscale connectivity and any requested iOS permission.

- [Build details](https://appstoreconnect.apple.com/apps/6831008730/testflight/ios/200d7a68-cfc5-4682-9ed3-1c2369fa1328).
- Public source: [saphid/duotwitch](https://github.com/saphid/duotwitch).
- Archived source: [940748c](https://github.com/saphid/duotwitch/commit/940748c92934a24044f390e9554cdee57f00ef67).
- Archive: `build/testflight/202611052312/DuoTwitch.xcarchive`; archive/upload exits 0,
  archived identity and strict/deep signature exit 0. Complete eight-file hash
  manifest is retained beside the archive.
- Receipt: `build/testflight/webkit-audio-delivery-final.json`.
- Frozen source: 54/54 match; signed Simulator candidate: 12/12 match.
- 98 signed Simulator tests pass, zero failed/skipped, exit 0 and empty
  runtimeWarnings. The separate 15-test uploader execution repeats those tests;
  it is not an additional distinct count. Existing compiler deprecation remains.
- Fresh Codex / GPT-6.1 Sol high independent-session review completed with no
  actionable P0–P3 source findings. Same author/reviewer model; no diversity claim.
  [Review artifact](docs/council/webkit-audio-upload-review-sol.md).

No public/external beta, App Store release, physical fix, PiP or fold-continuity
claim. Earlier runtime proof below remains attributed to its original build.

## Current Simulator runtime — partial

The frozen WebKit-audio candidate was tested personally by GPT-6 Astra high,
with official Unmute readback before both Play actions and muted media samples.
Source 54/54 and candidate/installed bundles 12/12 matched before and after.
Native Pause held 36.1 seconds; the player retained one load, and zero native
`audio.transition` records occurred. No unintended native Pause followed Play.

Sustained visible motion and resumed motion did **not** pass: initial and resume
recordings contain long identical-frame intervals and very high dropped-frame
counts despite media-clock progress. This does not isolate source, decoder,
compositor/capture or provider behavior. It is not a physical Duo recovery pass.
The default queue/retry activity was observed, but no remote receipt was verified.
Report: `build/proof/webkit-audio-ownership/REPORT.md`. App/session cleanup
completed and Simulator data/Keychain were preserved.

## Automatic collection operational limit

Next-source change (not yet deployed/distributed): automatic upload now targets
Alex’s dedicated DuoTwitch JSON/SQLite receiver at
`https://lxso1.tail4e5636.ts.net/duotwitch-diagnostics`. Receiver source, bounded
storage, hardened unit and additive-route comparison guard are staged for parent
review. No production service or route was changed by this implementation;
HTTPS 204 plus exact SSH readback remain required. The existing lxso2 setup is
untouched. Deployment and rollback are documented in the linked runbook below.

The current internal build enables automatic, privacy-filtered upload by
default to Alex’s existing private Loki receiver over Tailscale HTTPS at
`https://lxso2.tail4e5636.ts.net/duotwitch-diagnostics`, while retaining local logs
and Share. It requires no manual export or app configuration. The bounded queue,
retry policy and destination are disclosed in the app.

**Collection is not operationally verified:** a synthetic push reaches the owned
network Loki but returns HTTP 500: its volume is 98.8% full, above the 90% WAL
threshold. Approximately 80.6 GiB capacity recovery is required; unrelated data
has not been deleted. No ingestion readback has been verified. The receiver must recover,
then pass synthetic write/readback, before claiming working automatic collection.
The physical phone’s tailnet access and any iOS permission remain unverified.
See [implementation and prerequisite details](docs/automatic-playback-diagnostics.md).

## Previous internal TestFlight — diagnostics-only build

**0.1.0 (202611052215)** is available for existing internal testers. Apple API
readback verifies `VALID`, `INTERNAL_ONLY`, and `IN_BETA_TESTING`, plus complete,
explicit relationships to **Alex**, **t3crew**, and **DuoCrew**. The exact en-US
What to Test notes were read back. Installation and inbox delivery are unverified.
No public/external beta or App Store submission was made.

This is a **diagnostics update**. Alex confirms the previous build
202611051233 still stops video before one second with the phone open. The
physical cause and its resolution remain unknown.

After reproducing on the new build, tap the video **info circle -> Playback
diagnostics -> Share playback logs**, or use **Account -> Playback diagnostics**.
Share `DuoTwitch-playback.jsonl` with the developer. Logs survive relaunch;
this delivered build has no automatic upload. Credentials, chat, account/channel identity,
media URLs and full errors are excluded. Four rolling 256 KiB files and one
bounded export copy are retained locally.

- [Build details](https://appstoreconnect.apple.com/apps/6831008730/testflight/ios/71e59bda-14bd-4ec1-af38-5df9ded5f89a).
- Public source: [saphid/duotwitch](https://github.com/saphid/duotwitch).
- Archived source: [2836abc](https://github.com/saphid/duotwitch/commit/2836abc73945897bc86bbb3b6c6651ed94fbde61).
- Archive: `build/testflight/202611052215/DuoTwitch.xcarchive`.
- Final private receipt: `build/testflight/diagnostics-delivery-final.json`.

83 signed Simulator tests passed, zero failed/skipped, runtimeWarnings empty,
actual command exit 0. The fresh Codex/GPT-6.1 Sol high recheck found no actionable
findings after the accepted passive-video reattachment issue was fixed. It is an
independent session using the author's model, not model diversity; see
[review 2](docs/council/playback-diagnostics-review2.md). The existing AccountView
compiler deprecation remains disclosed.

Archive and export/upload exited 0; strict/deep archive signature exited 0.
Archived identity verifies app/bundle/team/version/build and public player config.
The Release executable contains the diagnostics recorder, export screen and
reattachment-aware passive script. Source identity remains 47/47; the archived
bundle's eight regular files have a private full hash manifest. No disk cleanup
was needed (about 76 GiB free before upload).

The initial 82-test instrumentation binary passed both native share routes,
export creation and persistence across relaunch, and real passive observer receipt
with 60 paused samples. No Play/audio was started. That evidence is explicitly
attributed to the initial binary, before the small script lifecycle fix; current
real-video detach/reuse and physical iOS file protection remain unverified.
Report: `build/proof/playback-diagnostics/REPORT.md`.

The diagnostic build details and public repo were sent through the
[Discord history skill](https://github.com/saphid/discord-history-tool) Beeper
route to **T3Code (dev) -> #txt** at **22:20:37 UTC on 5 November**. Exact normalized
message, self-sender and no reply chain were verified by fresh Beeper readback.
Beeper message 184836/sortKey296069 is a bridge receipt; native Discord ID and
placement remain independently unverified. No attachment or broad mention was
sent. Private receipt: `build/testflight/diagnostics-discord-receipt.json`.

DuoCrew internal membership and Andy's pending Apple team invitation were not
changed; the earlier limited-access prerequisite below still applies. Duocord
source, builds and groups were preserved.

## Previous internal TestFlight — 5 November 2026

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
