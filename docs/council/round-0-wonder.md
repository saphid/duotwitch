# Initial council: wonder

Task ID: `node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A696f4f1c-ade0-4d2a-9f39-f781d7b83a0d`

Provider: `muse`; model: `muse-wonder-full-1.0`; status: `completed`.

## Round 0 verdict

DuoTwitch is **absent, not merely low-scoring**. There is no runnable candidate to test.

The inspected tree is only [README.md](/Users/saphid/.t3/projects/duotwitch/README.md), [REQUIREMENTS.md](/Users/saphid/.t3/projects/duotwitch/REQUIREMENTS.md), a placeholder icon, and `build/reference/`. No runtime, parity, or fold claim is possible.

One requirement is probably unattainable as written. Twitch offers no supported native playback URL for third parties. Real system PiP therefore needs a decision before GPT-6.1 starts building.

I performed this review directly as Muse Code powered by muse-wonder-full-1.0 (xhigh). No re-delegation. Owning issue: [saphid/personal-ops#208](https://github.com/saphid/personal-ops/issues/208).

## Scores

Official scores mean "feature visibly shown in marketing screenshots". They are not runtime quality scores. Runtime behaviour of the official app is `U` from this evidence.

| Category | Official shown | DuoTwitch | Build feasibility |
| --- | --- | --- | --- |
| Discovery/navigation (V) | 9/10 | absent — null | 8/10 (D) |
| Video and controls (V) | 7/10 | absent — null | 4/10 (D) |
| Native chat (V) | 8/10 | absent — null | 7/10 (D) |
| Auth/privacy (U) | null | absent — null | 6/10 (D) |
| Layout modes (U) | null | absent — null | 7/10 (S/D) |
| Accessibility (U) | null | absent — null | 5/10 (D) |
| Continuity/performance (U) | null | absent — null | 7/10 (S) |
| TestFlight (S) | n/a | absent — null | 8/10 (S) |

Evidence: iPhone screenshots 1–4 show a Following/Live/Clips feed, live-following list, search with categories, and a channel page with video over native-looking chat. IPad screenshots 1–4 are cropped collages and prove almost nothing. No screenshot shows sign-in, offline states, PiP, fullscreen controls, or any Duo pose.

## Launch blockers

1. **Playback path is undecided — this gates everything.** See below.
2. **No Twitch app registration exists.** No Client ID was found. Registration forces an early client-type choice (next section). Alex's Twitch account with 2FA must create it.
3. **No owned HTTPS domain is named.** The supported player needs a `parent` domain. See below.
4. **No App Store Connect app record exists** for `com.saphid.duotwitch`. Bundle ID registration is scriptable via the existing ASC pattern. App-record creation still needs the ASC web UI.
5. **Logged-out parity is impossible without a backend.** Every Helix call needs a user or app token. App tokens need a client secret, which cannot ship in the app. Either DuoTwitch is login-first, or someone hosts a token minter. [REQUIREMENTS.md](/Users/saphid/.t3/projects/duotwitch/REQUIREMENTS.md) does not say which.

## Playback and PiP

**Option A — supported web embed.** Load `https://player.twitch.tv/?channel=…&parent=<owned-domain>` inside `WKWebView`, served from a minimal page on that domain, with the `Twitch.Player` JS bridge for state and quality. Docs: [Embedding Video and Clips](https://dev.twitch.tv/docs/embed/video-and-clips/). Constraints from those docs: minimum 400×300 px, player must not be obscured, `parent` is mandatory.

- A compact iPhone is ~390–430 pt wide. A 16:9 video there is ~220 pt tall. That already breaks the documented 400×300 minimum.
- A "chat focus + floating video" mode is necessarily smaller still. As specified, it conflicts with the embed terms.
- Controls are Twitch's web controls, not native ones. VoiceOver and Dynamic Type do not reach them properly.
- The 27.2 SDK has `WKWebViewConfiguration.allowsPictureInPictureMediaPlayback`. Whether Twitch's MSE player yields system PiP through it is unknown. This must be spiked, not assumed.

**Option B — direct HLS into `AVPlayer`.** This is the only route to real `AVPictureInPictureController` PiP, native controls, and free sizing. It requires private playback-token endpoints. The task and [REQUIREMENTS.md](/Users/saphid/.t3/projects/duotwitch/REQUIREMENTS.md:25) forbid it. Rejected.

**Option C — deep-link out** to the official app or Safari via [Mobile Deep Links](https://dev.twitch.tv/docs/mobile-deeplinks/). Supported, but abandons the product. Keep it only as an honest "Open in Twitch" fallback when the embed fails.

Recommendation: run a 1-day Option A spike first, on an owned Simulator session only. Test live playback, inline playback, fullscreen, audio session, quality switching, and every PiP route. If system PiP fails, amend the requirement to "in-app floating mini-player" and record the 400×300 conflict explicitly. Do not let the builder hill-climb toward a PiP that cannot exist.

## Auth and native chat

Twitch documents four flows at [Getting OAuth Access Tokens](https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/). No PKCE appears in those docs.

- **Public client:** Device Code Flow only. It can refresh without a secret. Refresh tokens die after 30 days inactive. UX is "enter this code at twitch.tv/activate" — clunky on a phone, workable via `ASWebAuthenticationSession`.
- **Confidential client + implicit flow:** smoother in-app sign-in. No refresh token. Re-authentication on expiry or revocation. The secret must never ship, so no code-exchange and no app tokens on device.
- **Confidential client + small backend:** only route to auth-code refresh and logged-out browsing. New operational burden.

My recommendation: register a **public client, Device Code Flow**, tokens in Keychain (`ThisDeviceOnly`, no iCloud sync), hourly `/validate` as [Validating Tokens](https://dev.twitch.tv/docs/authentication/validate-tokens/) mandates — Twitch audits this. Use the same owned domain as the player host for a universal-link redirect. Decide this at registration; client type is painful to reverse.

Native chat is genuinely supported. Use EventSub WebSocket (`wss://eventsub.wss.twitch.tv/ws`, `channel.chat.message`, scope `user:read:chat`) for receiving, and Helix Send Chat Message (scope `user:write:chat`) for sending. Send returns `is_sent` plus `drop_reason`, which gives the authoritative failure behaviour the requirements ask for. Sources: [Chat & Chatbots](https://dev.twitch.tv/docs/chat/), [Send and Receive Messages](https://dev.twitch.tv/docs/chat/send-receive-messages/), [Handling WebSocket Events](https://dev.twitch.tv/docs/eventsub/handling-websocket-events/).

Two parity gaps follow. Chat requires a signed-in user; anonymous read is not a documented EventSub capability, and undocumented IRC `justinfan` access should not be a dependency. EventSub does not replay events lost during a disconnect, so reconnect must resubscribe and show a visible gap marker.

Emotes and badges are well supported: message fragments identify emotes, and Helix supplies global/channel emote and badge artwork. Third-party emote sets (BTTV/7TV) are outside Twitch APIs and are not mentioned in the requirements.

## Layout modes

The reference pattern is sound but must not be copied literally. [Fold.swift](/Users/saphid/.t3/projects/duocord-native/Platform/Fold.swift:82) reads `reservedRegions(kind: .division)` plus `UIHingeInteraction`. I verified both in the 27.2 SDK headers (`UIView.h`, `UIHingeInteraction.h`, `API_AVAILABLE(ios(27.1))`), along with `UIArrangementViewController`/`UISplitArrangement`.

Applied to Duo rules:

- **Compact:** single stack; video on top, chat below (matches official screenshot 4).
- **Open/flat regular:** `NavigationSplitView` for discovery; on the watch screen, video and chat as split arrangement. Sidebar toggle belongs in the detail column's toolbar, symbol-only with a title, so it relocates into the vertical bar. [MainView.swift](/Users/saphid/.t3/projects/duocord-native/App/MainView.swift:50) already demonstrates the shape.
- **Book:** video on one page, chat on the other. This is the best Duo mode and should be the design centrepiece. Video must never straddle the division region.
- **Tabletop:** video on the top page; all tappable controls and the composer on the bottom page. No navigation control in the top half.
- **Chat left/right, full video, slim overlay, chat focus:** model these as one persisted user `LayoutMode` orthogonal to posture. Do not build per-pose layouts; Apple guidance and the requirements both point this way.

Continuity requirements: one retained `WKWebView` across every mode change (reload only on channel change), selected channel preserved, composer draft/selection/focus preserved. [UIContinuityTests.swift](/Users/saphid/.t3/projects/duocord-native/Tests/UIContinuityTests.swift:8) and [DuoLayoutTests.swift](/Users/saphid/.t3/projects/duocord-native/Tests/DuoLayoutTests.swift:161) are the right test templates — mounted layout measurement and responder-intent retention, including the hidden-sidebar reveal surviving scroll.

Accessibility is the weakest area because of the web player. Native chat can fully support Dynamic Type, VoiceOver, and Reduce Motion. Live chat must not use `.updatesFrequently` firehose announcements; it needs pause-on-scroll-up and a VoiceOver-quiet default. Touch targets at 44 pt. These match the review tests in `build/reference/interface-craft.txt` lines 581–592.

Performance: cap the chat timeline (ring buffer, roughly 300–500 messages), coalesce inserts, cache emote/badge images, and backpressure very large channels. EventSub volume on a 100k-viewer channel is the stress case.

## TestFlight feasibility

Feasible, with adaptation. [testflight.sh](/Users/saphid/.t3/projects/duocord-native/scripts/testflight.sh:13) already pins Xcode 27.2 and timestamp build numbers, and [asc.mjs](/Users/saphid/.t3/projects/duocord-native/scripts/asc.mjs:16) signs ASC tokens in memory. I did not read the protected ASC config contents.

Required changes: hardcoded `com.saphid.duocord` checks at lines 49–57 become `com.saphid.duotwitch`; drop the Live Activity extension; `deploymentTarget iOS 27.1` (fold APIs need it) — confirm every T3 crew device runs 27.1+; `TARGETED_DEVICE_FAMILY` should be iPhone-only (`1`) unless iPad is explicitly in scope.

Open risks: whether "T3 crew" is an internal ASC group or external testers. External means Beta App Review on the first build, and the copied script's `testFlightInternalTestingOnly` would block it. The name "DuoTwitch" and any Twitch-like trade dress risk a 5.2.x rejection even in beta review; the current red "D" icon is safely unlike Twitch. UGC obligations (report/block via Helix, mature-stream gating) are unaddressed in the requirements.

## Bounded architecture

Six modules are enough: `App` (tabs/split/watch), `TwitchAPI` (Helix client, pagination, rate-limit), `Auth` (device flow, Keychain, hourly validate), `Player` (single retained `WKWebView` + JS bridge + fallback link), `Chat` (EventSub socket, bounded timeline, emote/badge rendering, composer), `Platform` (fold state copied in principle from [Fold.swift](/Users/saphid/.t3/projects/duocord-native/Platform/Fold.swift:17), fake-fold debug flag for Simulator).

Explicitly out of scope, because no public API exists: subscriptions, Bits/cheering, channel points redemption, Drops claiming, VOD chat replay, go-live. The official screenshot's Subscribe button cannot be replicated; a deep link is the honest substitute.

## Acceptance test matrix

- **Discovery:** top streams, categories, search channels/categories, followed-live when signed in, pagination, empty/offline/error states, login-first wall if no backend.
- **Playback:** live channel plays inline; offline channel shows honest offline state; VOD/clip playback; quality switch; fullscreen exit returns to same position; audio interruption; embed failure offers "Open in Twitch"; PiP result recorded as pass or documented fail.
- **Continuity:** compact ↔ open ↔ book ↔ tabletop with fake and real folds; player instance and playback survive; chat left/right swap; draft, selection, and keyboard survive; channel preserved.
- **Chat:** messages arrive with badges/emotes; send succeeds and appears once; slow/follower/sub-only and banned drops surface `drop_reason`; disconnect shows gap + reconnect + resubscribe; scroll-up pauses autoscroll; 60-minute soak on a large channel without unbounded memory.
- **Auth/privacy:** device-flow sign-in, refresh, hourly validate, revoke/sign-out wipes Keychain, token absent from logs and UserDefaults.
- **Accessibility:** full watch journey in VoiceOver, largest Dynamic Type, Reduce Motion, contrast check on chat colours, 44 pt targets.
- **Delivery:** clean archive with `DEVELOPER_DIR` pinned to Xcode 27.2, bundle ID verified in the archive, build reaches `VALID`/`IN_BETA_TESTING`, audience read back before any invitation.

## Council review

Rounds: 0 (initial assessment; no candidate exists)

| Delegate | Round 0 |
| --- | --- |
| Muse Wonder Full (xhigh) | no score — candidate absent |

Other delegates' Round 0 scores are theirs to give; I will not invent them.

No `CODING_STANDARDS.md` exists in this repo, its parent, the home root, or the Duocord root — I searched all four. No standard exists to violate.

**Bottom line:** resolve the two registration decisions and spike the embed player before any build round. Everything else — Helix discovery, EventSub chat, fold layout, TestFlight plumbing — is evidence-backed and buildable.
