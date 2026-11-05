# DuoTwitch

Alex's request, 5 November 2026: build a native Swift Twitch client for iPhone and iPhone Duo; learn from Duocord Native; support excellent open/closed/fold layouts, video and chat side by side, chat with video Picture in Picture, fullscreen video and a slim chat on either side. Deliver through TestFlight to Alex and the T3 crew group.

## Product target

Use official Twitch's ordinary viewing experience as the baseline. Native navigation, discovery, channel details, playback, chat, account handling, accessibility, failure recovery and settings must be assessed separately. Never equate a polished mock with live functionality or numerical scores with feature completeness. Document unavailable commercial/creator capabilities and platform limits.

## Reference implementation

Read-only reference: `/Users/saphid/.t3/projects/duocord-native`. Its `Platform/Fold.swift` reads real active division regions and hinge updates; `App/MainView.swift` adapts navigation and fold layout; `Tests/DuoLayoutTests.swift`, `Tests/AdaptivePresentationTests.swift` and `Tests/UIContinuityTests.swift` demonstrate continuity and mounted layout verification. Reuse principles, not Discord-specific account or network behavior. Do not change that repository or reuse its bundle identifier.

Xcode 27.2 is installed at `/Applications/Xcode-27.2.0.app`; the system-selected Xcode is older. Use an explicit `DEVELOPER_DIR`. Verify SDK interfaces before writing fold APIs. Test on owned Simulator sessions through the T3 Device panel.

## Judging workflow

1. Initial independent council assessment: Claude Opus 5.5 (`effort=xhigh`), GPT-6.1 Sol (`reasoningEffort=xhigh`), Muse Wonder Full (`reasoningEffort=xhigh`). Same starting candidate and requirements. Obtain findings across product, runtime, accessibility, technical feasibility and delivery. Initial empty source is not a runnable candidate.
2. GPT-6.1 implementation and focused tests, then fresh Sol judging passes until the candidate meets the applicable official Twitch baseline. Preserve direct official screenshot references and matched candidate captures. Record source identity, actual provider/model/task/status, scores, findings, unknowns and dissent.
3. Bring the other judges back only once Sol passes the substantially completed candidate. Final council agreement must concern the same frozen candidate. Do not invent a pass where live authentication/playback/chat or fold evidence is missing.
4. Fresh independent source review after focused tests and before shipping, best effort subject to usable model capacity. Read nearest `CODING_STANDARDS.md` only in review context.

## Acceptance evidence

- Browse/search/open a real Twitch channel; preserve selected channel and playback across layout changes.
- Officially supported Twitch authentication and APIs; tokens in Keychain; no bundled client secrets or extraction of private player APIs.
- Live video with honest loading/offline/error states, real playback controls and supported Picture in Picture.
- Live chat with reconnect, a bounded timeline, native composer and authoritative send/failure behavior; account/permission limitations explicit.
- Compact phone, Duo open, book and tabletop; full video, video/chat split, chat left/right, slim overlay and chat-focused floating video; persistence without recreating the player on every mode change.
- Dynamic Type, VoiceOver labels, adequate targets, contrast and Reduce Motion; keyboard and draft continuity.
- Reproducible build/tests, actual Simulator screenshots, direct reference comparisons, council ledger and known gaps.
- Separate app identity `com.saphid.duotwitch`; signed archive and verified TestFlight build processing. Invite Alex and include the existing T3 crew group, verifying the exact audience before sending invitations. No production App Store release or public beta link is requested.

## Existing infrastructure lookup

`pa-memory` returned older native iPhone signing references but no DuoTwitch implementation; this is incomplete prior-work evidence, not proof of absence. T3 project inventory located both Duocord and Duocord Native. Portfolio registry validation passed; no Twitch/Duocord/iPhone Duo capability matched the bounded lookup. Use the explicitly requested new project here. Existing App Store operations are documented in `/Users/saphid/projects/apple-app-store-connect`, and Duocord Native has reusable ASC signing/upload patterns.
