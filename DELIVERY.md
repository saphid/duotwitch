# DuoTwitch delivery

Owning work: [personal-ops #208](https://github.com/saphid/personal-ops/issues/208).

## Current delivery — 5 November 2026

**Internal TestFlight is available to the authorized audience.** Version
**0.1.0 (202611050949)** is processed as `VALID`, restricted to
`INTERNAL_ONLY`, and reports `IN_BETA_TESTING`. A fresh App Store Connect UI
reload shows the exact build as **Testing**. Final API readback independently
confirms both group/build relationships and all invitation states.

- [App Store Connect TestFlight](https://appstoreconnect.apple.com/apps/6831008730/testflight/ios).
- Public source: [saphid/duotwitch](https://github.com/saphid/duotwitch).
- Archived source: [d87901e](https://github.com/saphid/duotwitch/commit/d87901e3827c3d4e4fadb2048ff4cc4f408c1e69).
- Minimum iOS version: **27.1**.
- `t3crew`: Nikolas Kitsios, Julius M, Alex Jankowiak, and account holder
  Alexander Southwell. All four show **Invited**; the original crew is preserved.
- Separate internal `Alex` group: Alexander Southwell, with the same build.
  This is the same person, not an additional tester.
- Invitation acceptance, inbox/email delivery, TestFlight installation and
  physical-device launch remain unverified. Install through the Apple
  TestFlight invitation using the invited Apple account.
- No public beta link, external beta or App Store submission was created.

The authorized announcement was sent to **T3Code (dev) → #txt** at
**10:11:06 UTC**, including the exact version/build, invitation instructions,
public repository and beta limitations. Beeper readback matched the complete
sent text after HTML normalization, confirmed the sender, and showed no reply
chain. Its private receipt is `build/discord-delivery-receipt.json`.
Beeper message identifiers are not native Discord identifiers; native message
ID and Discord-side placement were not independently read back.

## Internal DuoCrew on both apps

Following Alex's explicit request, **DuoCrew is internal on DuoTwitch and
Duocord**. Direct group readbacks confirm `isInternalGroup=true` on both.
The assigned existing builds are DuoTwitch `202611050949` and Duocord
`202611050134`; both are `VALID`. No new upload or external review is needed
for these internal groups.

Apple does not allow changing `isInternalGroup` after group creation. The
unused external DuoTwitch group was therefore preserved as **DuoCrew External
(unused)**, and a new internal DuoCrew was created. Its external Andy tester
record remains intact and has no build assigned.

Andy Neggles was sent an **App Store Connect user invitation**, accepted by
Apple with HTTP 201, for the limited `MARKETING` role. Readback verifies exactly
DuoTwitch and Duocord in the invitation's visible-app relationship. His supplied
email was matched privately and is not published here. Acceptance is pending.
Both internal groups currently have zero members: Apple returned HTTP 409
“Tester(s) cannot be assigned” when adding Andy's existing tester identity
while that user invitation is pending. After he accepts, his internal tester
membership still needs to be added and verified on both apps. A user invitation
is not yet a TestFlight invitation or proof of inbox delivery.

A fresh DuoTwitch **TestFlight invitation for Alexander Southwell** was also
explicitly submitted earlier. The app-and-tester invitation POST returned
HTTP 201 and a new invitation record. Readback shows **INVITED**, with his
existing internal build access; inbox delivery and acceptance are unverified.

Private evidence: `build/testflight/duocrew-internal-both-receipt.json`,
`build/testflight/duocrew-alex-invitation-receipt.json`, and matching API receipts.

## Identity and signed artifact

- Product/display name: **DuoTwitch**.
- Bundle: `com.saphid.duotwitch`; Apple app: `6831008730`.
- Team: `NJZUMEA4BN`; registered bundle record: `BXXWR6ZCZ7`.
- App SKU: `duotwitch-ios`; primary locale: `en-US`.
- Build ID: `731ace5d-52c8-4b47-b404-41bb3f577515`.
- Player host: `https://saphid.app/apps/duotwitch/player/index.html`.
- Public Twitch Client ID: `xuaoegs6v9yy1dw86gemt4gyuqtf1o`.
- Twitch registration: **Saphid Duo Viewer**, PUBLIC, Application Integration.
  Native product name and bundle remain DuoTwitch. No client secret is used.
- Use `/Applications/Xcode-27.2.0.app/Contents/Developer` as `DEVELOPER_DIR`.
  Protected ASC credentials remain in `~/.appstoreconnect/frame-control.json`;
  never print, copy or commit their values.

The signed archive is retained at
`build/testflight/202611050949/DuoTwitch.xcarchive`. Archive and Xcode
export/upload both exited **0**; archived strict/deep signature verification
also exited **0**. Archived Info.plist and signature verify the bundle, team,
version/build, public Client ID and owned player host above. Export requested
`testFlightInternalTestingOnly=true`. Logs, actual exit files and identity
receipts are under `build/testflight/202611050949/`.

The earlier build attempt `202611050926` exited **75** before compiling because
its 20 GiB free-space reserve was unmet. The successful small archive used an
owned-process disk monitor with a 10 GiB floor. Only unused pnpm store entries
were pruned; no unrelated processes or shared Simulator/DerivedData were removed.

## Verification and known beta limits

The archived source has **69 signed Simulator tests passed**, zero failed or
skipped, no runtime warnings, and actual command exit **0**. The native Play
ordering defect was reproduced before its fix; a fresh independent-session
Codex / GPT-6.1 Sol high source recheck passed with no actionable findings.
See [the review](docs/council/source-native-play-ordering-review-sol.md) and
[the frozen source manifest](docs/council/source-native-play-ordering-sha256.json).
This is a source review, not a product-parity verdict.

Historical runtime evidence remains attributed to its actual binary:

- Signed **62-test candidate**: native OAuth as `saphid`, real discovery,
  received native chat, authenticated relaunch, and genuine unsent draft
  continuity across Full/Slim, chat-side changes and Back/reopen.
- **67-test candidate**: production native Play, changing gameplay, native
  Pause with unchanged video pixels, and resumed changing gameplay. Category
  search/open and retained authentication were also verified.
- Current **69-test source**: ordering fix and category subtitle correction
  are tested and reviewed. Earlier runtime captures are not relabeled as this
  candidate or as physical-device TestFlight proof.

**Playback verification must be inaudible to Alex.** Official player mute was
verified before later playback in the 67-test run. Earlier playback did not
have a verified silent route. Before every further playback check, verify
per-player mute or a supported silent Simulator route, including after player
recreation or channel change. Do not infer prior mute persists or change global
Mac audio for unrelated applications. The delivery verification used no playback.

Known limits are included in TestFlight notes and the Discord announcement:
compact video must fit Twitch's supported 400×300 minimum; fold continuity and
full-video layouts need testing; Picture in Picture is unavailable; background,
audible-output/audio ownership and a complete accessibility journey are
unproven. Native chat sending was not performed. The product council gate
remains **WITHHOLD**; no Twitch parity or final-product completion is claimed.

## Durable evidence and history

Private build and account receipts are ignored by Git. Relevant paths:

- `build/proof/testflight-ready/REPORT.md`, sanitized receipt and screenshots:
  final persisted UI audience, exact build and cleanup.
- `build/testflight/final-*.txt`: final API readbacks for state, groups and testers.
- `build/discord-delivery-receipt.json`: authorized send and matching readback.
- `build/proof/native-play/REPORT.md`: historical 67-test playback evidence.
- `build/proof/native-ssh/REPORT.md` and
  `build/proof/native-ssh-followup/REPORT.md`: historical authenticated journey.
- `build/proof/testflight-crew/REPORT.md`: earlier crew setup before a build
  existed; its zero-build result is superseded by current delivery evidence.

Apple registration/sign-in and Twitch SMS/client-name blockers were resolved
before this release. Historical sanitized receipts remain in `build/`:
`asc-app-record-prerequisite.json`, `mac-auth-recovery-20261105.json`,
`mac-air-twitch-recovery-20261105.json`, `mac-pro-twitch-cua-recovery-20261105.json`,
and `twitch-client-distinct-name-registration-20261105.json`.
The registered public client and callback limitations are documented in
[PUBLIC_CLIENT.md](docs/PUBLIC_CLIENT.md). No callback implementation is claimed.

All final GUI verification was performed personally by Codex / GPT-6 Astra
high, without re-delegation. Owned preview and Chrome resources were closed;
existing windows, app authentication and Simulator state were preserved.
