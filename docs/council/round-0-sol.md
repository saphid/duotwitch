# Initial council: sol

Task ID: `node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A5a13522c-7a98-4936-8ece-a5844253f097`

Provider: `codex`; model: `gpt-6.1-sol`; status: `completed`.

**Round 0 verdict: withhold sign-off.** DuoTwitch has no executable app yet. Native discovery, chat and Duo layouts are feasible; supported Twitch playback and real Picture in Picture need an early proof before extensive UI work.

I inspected the project at `f87f7d74312dd7951c75251c24b5bce84c657d6c`, read [REQUIREMENTS.md](/Users/saphid/.t3/projects/duotwitch/REQUIREMENTS.md) fully, and checked the specified Duocord sources and release scripts. Requirements remained unchanged during review. Owning work: [#208](https://github.com/saphid/personal-ops/issues/208). No build, Simulator, runtime, authentication or parity test was performed.

**Scores describe evidence, not demonstrated parity.** V = screenshot; D = documented interface; S = source; U = unknown. DuoTwitch’s zeros mean **absent implementation**, not measured runtime failures.

| Category | Official reference /10 | DuoTwitch availability /10 |
|---|---:|---:|
| Discovery/navigation | 8 V | 0 S — absent |
| Video/control presentation | 7 V | 0 S — absent |
| Chat presentation | 7 V; native behavior null U | 0 S — absent |
| Authentication/privacy | null U | 0 S — absent |
| Compact composition | 8 V | 0 S — absent |
| Duo open/book/tabletop | null U | 0 S — absent |
| Chat left/right, full video, slim chat | null U | 0 S — absent |
| Chat focus and real PiP | null U | 0 S — absent |
| Accessibility | null U | 0 S — absent |
| Continuity/performance/recovery | null U | 0 S — absent |
| Settings | null U | 0 S — absent |
| TestFlight delivery | null U | 0 S — absent |

I inspected all eight supplied images. The iPhone references show recognizable discovery, a following drawer, category search, channel details and dense chat. Small controls and crowded chat merit scrutiny rather than literal copying. The iPad images are promotional composites featuring older hardware, not evidence for current Duo behavior. The [downloaded metadata](/Users/saphid/.t3/projects/duotwitch/build/reference/official-twitch.json) identifies Twitch 31.9, released November 2; that does not establish when each marketing image was captured.

**The principal launch blocker is the playback contract.**

| Option | Evidence and limitation |
|---|---|
| Official Twitch embed in a native shell | D: documented web playback and JavaScript controls. A `WKWebView` integration is a plausible first spike, but native-app packaging, authenticated playback and PiP remain unverified. |
| `AVPlayer` with native controls/PiP | D: Apple supports this. The inspected Twitch APIs return stream metadata, not an authorized live HLS URL. This route requires an explicitly supported Twitch media-delivery interface or agreement. |
| Open official Twitch externally | Useful fallback, but does not satisfy in-app video/chat continuity or DuoTwitch PiP. |

[Twitch’s embed requirements](https://dev.twitch.tv/docs/embed/) require HTTPS, valid parent-domain configuration, approved player elements, an unobscured player and minimum dimensions. [Video documentation](https://dev.twitch.tv/docs/embed/video-and-clips/) specifies **400×300 pixels**, mobile user interaction before playback, and documented play/pause, quality, mute, captions and status APIs. Live seeking is unsupported.

These constraints directly challenge narrow compact layouts, a small floating web player and chat laid over video. Do not solve that by cropping controls, forging a parent domain, extracting private player tokens or copying stream credentials.

For **real PiP**, the installed SDK confirms:

- `AVPictureInPictureController` accepts supported media sources such as an `AVPlayerLayer`.
- `WKWebViewConfiguration.allowsPictureInPictureMediaPlayback` permits HTML video PiP; it does **not** guarantee Twitch exposes or permits it.
- A floating SwiftUI rectangle is an in-app layout mode, not proof of system PiP.

The first implementation milestone should therefore demonstrate a real Twitch live stream, user-controlled playback, system PiP, background continuation and restoration into the same session. Test an actual Twitch stream, not an unrelated sample HLS video. If the supported route cannot meet these requirements, resolve that product constraint before declaring the app comparable.

**Public-client authentication and native chat have documented routes.**

Use a dedicated registered Twitch client. The supplied credential searches are incomplete absence evidence; registration remains an early prerequisite. Twitch documents **public-client Device Code Flow**, including secretless refresh, in [Getting OAuth Tokens](https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/). Use the system authentication surface, honor the returned polling interval and cancellation, and store rotated tokens atomically in Keychain.

A relevant nuance: Twitch’s live [OIDC discovery metadata](https://id.twitch.tv/oauth2/.well-known/openid-configuration) advertises PKCE `S256`, but also advertises only `client_secret_post` token-endpoint authentication. That does not establish a supported secretless authorization-code flow for this app. Prefer the documented public Device Code route until registration-specific evidence proves otherwise.

Request `user:read:chat`, `user:write:chat`, and `user:read:follows` when those features are needed. Validate sessions at startup and hourly as [Twitch requires](https://dev.twitch.tv/docs/authentication/validate-tokens/). Serialize refresh operations, preserve replacement refresh tokens, and handle revocation and reauthorization. Never bundle a client secret or put API tokens into player JavaScript.

For native chat, use EventSub WebSockets with the viewer’s user token and Helix Send Chat Message. [Subscription authorization](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#channelchatmessage) supports this without requiring every broadcaster to authorize a cloud bot.

Essential behavior includes:

- Native bounded timeline and composer, emote/badge rendering and accessible text alternatives.
- Deduplication, keepalive detection, reconnect handoff, subscription recreation after a fresh connection, and an honest gap indicator after missed events.
- Message deletion/clear events, chat restrictions, replies and visible send outcomes.
- Respect `is_sent` and `drop_reason`: HTTP 200 can still mean AutoMod held the message. Avoid automatic resend after an ambiguous timeout.
- Shared Chat awareness: [user-token sends reach the shared session](https://dev.twitch.tv/docs/api/reference/#send-chat-message); do not promise source-channel-only delivery.

The [WebSocket protocol](https://dev.twitch.tv/docs/eventsub/websocket-reference/) and [chat guide](https://dev.twitch.tv/docs/chat/send-receive-messages/) provide the relevant contracts.

**Keep the first architecture bounded.** A SwiftUI navigation shell, one persistent viewing session, a small Helix client, an authentication actor and an EventSub chat service are sufficient. Keep the player/controller outside layout-dependent branches; changing posture or chat side must not recreate playback. Use cancellation and session generations to prevent late search, channel or send callbacks affecting a newer selection.

Discovery should cover live categories, channel search, followed streams and channel details, with stable back navigation and restored search/scroll context. [Helix](https://dev.twitch.tv/docs/api/reference/#get-streams) supports these metadata journeys. It requires an access token even for ordinary discovery: choose signed-in-first browsing initially, or explicitly scope a server component for guest discovery. Do not manufacture a client-credentials token on the phone.

Keep API authentication and embedded-player login distinct. A Helix token does not demonstrate authenticated subscriber playback or equivalent ad/account behavior inside the embed.

**Duo layout feasibility is supported by real SDK interfaces, not just the skill notes.** With explicit `DEVELOPER_DIR`, Xcode reports **27.2, build 27B52**. The iOS 27.2 interfaces contain `ArrangementView`, `ReservedRegion`, `GeometryProxy.reservedRegions`, hinge updates, and UIKit arrangement equivalents, available from 27.1.

Use size classes and active division regions:

- Compact: accessible stacked viewing/navigation with an obvious route back.
- Open/book: video and chat in separate usable regions, with chat-side preference preserved.
- Tabletop: video above the division; composer and frequent controls below it.
- Full video/chat focus: explicit reversible modes retaining the same session and draft.
- Slim chat: preserve readable text and adequate targets; avoid obscuring the embedded player.

Duocord’s [fold reader](/Users/saphid/.t3/projects/duocord-native/Platform/Fold.swift:80), mounted layout tests and continuity tests offer good principles: actual geometry assertions, stale-presentation protection, per-channel draft/selection retention and keyboard continuity. Their mocked/model tests and DEBUG fold injection are not DuoTwitch fold-runtime evidence.

Accessibility must cover the complete viewing/chat journey: Dynamic Type reflow, VoiceOver ordering and state, captions where available, generous 44-point controls, contrast over changing video, Reduce Motion, keyboard input and an alternative to drag-only interactions. Avoid continuously announcing every incoming chat message. Provide pause/jump-to-latest behavior and preserve reading position.

**TestFlight is feasible, with identifiable remaining prerequisites.** Newly added [delivery records](/Users/saphid/.t3/projects/duotwitch/DELIVERY.md) report no DuoTwitch app record yet. I read the saved audience evidence: `t3crew` is internal, contains three testers, has no next page, and includes Alex according to the delivery record. I did not repeat authenticated ASC queries.

Create and verify `com.saphid.duotwitch`, its app record, signing identity and its own app-scoped group assignment. Preserve the intended existing tester identities. Duocord’s [script](/Users/saphid/.t3/projects/duocord-native/scripts/testflight.sh:70) sets `testFlightInternalTestingOnly=true`; that suits this recorded internal audience. It would prevent external distribution if the audience later changes—[Apple documents that restriction](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers).

Do not copy Duocord bundle or extension identifiers. Verify the archived identity/team/build number, successful processing, exact build-to-group assignment, invitation outcome and actual testing availability. Upload success or `VALID` alone is insufficient.

**Minimum acceptance matrix before a passing judgment:**

| Area | Required proof |
|---|---|
| Discovery/navigation | Real search → channel → back; live/offline states, empty/error results, pagination and retained context. |
| Playback/PiP | Live video, truthful controls, buffering/offline/error handling, system PiP, background/restore and restricted-content behavior. |
| Native chat | Controlled live send/receive; AutoMod/permission failure, rate limiting, moderation removal, reconnect, deduplication and bounded memory. |
| Authentication/privacy | Device authorization/cancel/expiry, refresh rotation, revocation, logout cleanup; no token/secret leakage. |
| Layout | Ordinary phone and Duo compact/open/book/tabletop; both chat sides, full video, slim chat and chat focus; keyboard shown/hidden. |
| Continuity | Repeated mode/fold changes preserve player identity, selected channel, mute/pause intent, draft, selection, scroll anchor and focus. |
| Accessibility/performance | VoiceOver journey, largest text, Reduce Motion, captions and busy-chat soak; measure startup, stalls, memory and recovery on representative hardware. |
| Delivery | Reproducible tests/archive, matched reference/candidate captures, frozen candidate manifest, fresh judging, processed beta and verified audience availability. |

Use owned Simulator sessions for mounted layout evidence and appropriate physical-device evidence for PiP, audio and hinge behavior. Never count fixture captures as live integration proof.

The highest-risk omissions are playback authorization, real PiP, embedded-player account separation, Shared Chat/moderation semantics, suspension recovery and an undefined parity scope. Official recommendations, stories, commercial features and creator tools need an explicit supported/unavailable ledger rather than silent placeholders.

No `CODING_STANDARDS.md` exists in the target or inspected ancestors; this is the primary worktree. I therefore cite no coding-standard violation. The consulted [interface-craft text](/Users/saphid/.t3/projects/duotwitch/build/reference/interface-craft.txt) particularly supports stable navigation, preserved drafts, authoritative completion feedback and measured continuity.

**Reviewer:** OpenAI, GPT-6.1 Sol, xhigh, through the Codex harness. Assessment completed independently; no re-delegation, edits, account writes, invitations or commits.
