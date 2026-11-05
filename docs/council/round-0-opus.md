# Initial council: opus

Task ID: `node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A388f2417-4c64-4afc-b6e9-80ff5fb24c81`

Provider: `claudeAgent`; model: `claude-opus-5-5`; status: `completed`.

# DuoTwitch Round 0 council assessment (Claude Opus 5.5)

The starting app is **absent**: it scores 0/10 in every category. Before anyone builds the UI, five things need settling. Three of them block everything else:

1. **A Twitch developer app (Alex).** It needs a 2FA-enabled Twitch account and the Public client type. Nothing else can be tested with a real account without it.
2. **A supported playback page.** Twitch requires its own embedded player for all video, hosted on a web address we own.
3. **A real Picture in Picture check.** Whether the Twitch player allows system Picture in Picture is unknown.

The app name and a few delivery steps are the other early decisions (P4–P6 below). I'm Claude Opus 5.5 (`claude-opus-5-5`, Anthropic, Claude Code in T3). I did the review myself with no subagents. My effort setting isn't visible to me, so I can't confirm it was xhigh.

**What I inspected:** `/Users/saphid/.t3/projects/duotwitch` at commit `f87f7d7` (README.md, assets/icon.svg), plus the untracked `REQUIREMENTS.md`, `build/reference/*` (all 8 images viewed) and owning issue #208. I also read the 7 named Duocord Native files (commit `3f5cffb`, read only), plus its `testflight-share.sh`, `DELIVERY.md` and `project.yml`. I checked the iOS 27.2 SDK (Xcode 27.2, build 27B52) and the public Twitch docs and legal pages.

**The project changed while I was reviewing.** At 10:58 another worker added `App/`, `Platform/`, `Player/`, `Tests/`, `project.yml`, `DuoTwitch.xcodeproj`, `DELIVERY.md` and new `build/*` files. I scored none of it; there are two early warnings about it under "Objections".

**Coding standards:** no `CODING_STANDARDS.md` exists in the repo, its primary worktree (the same checkout), any parent folder, or Duocord Native. I can't cite any violated standard.

## Scores

These are the baseline versus the empty candidate, not a parity claim. Evidence: **V** = screenshot, **D** = documented, **S** = source, **U** = unknown.

| Category | Official Twitch (marketing images only) | Candidate R0 | Risk for the planned approach |
|---|---|---|---|
| Discovery and navigation | **8 V**: 5-tab bar, stories row, Live/Clips feed, Following list with live counts and an Offline section, search with recent searches, Categories/Live Channels with tags and viewer counts. How it behaves is U. | **0 S, absent** | Low: Get Streams, Search and Get Top Games are documented, but **signed-out browsing is impossible** without a server (see Auth). |
| Video and controls | **7 V**: cast, share, clip, settings, volume and rotate on the video, plus uptime and viewer count. Playback quality is U. | **0 S, absent** | High: the Twitch embed is the only allowed player; Picture in Picture is U. |
| Native chat | **7 V**: badges, coloured names, emotes, composer with channel-points, Bits and emote buttons. Reliability is U. | **0 S, absent** | Low to medium: everything needed is documented. There's no backlog of recent messages. |
| Auth and privacy | **null U**. The App Store text (D) says the official app ships Nielsen measurement software. | **0 S, absent** | Low: the device code flow suits a public client, but it needs Alex to register an app first. |
| Duo layout modes | **null U**: no fold, side-chat or landscape evidence. The iPad images are 360×480 marketing composites of an old home-button iPad. | **0 S, absent** | Medium: the APIs exist in the SDK. Twitch's player rules limit overlays and small video. Tabletop can't be produced in the Simulator. |
| Accessibility | **null U** (images too small to judge) | **0 S, absent** | Medium: the web player's own controls are outside our control. |
| Continuity, performance, recovery | **null U** | **0 S, absent** | Medium: whether the player survives being moved between layouts is U. |
| TestFlight | n/a | **0 S, absent** | Low to medium: the signing scripts and App Store Connect key exist, but `t3crew` belongs to another app (see P5). |

The baseline numbers rate only the visible design in marketing images. They aren't measured runtime targets.

## Things to settle early (in order)

**P1 – Twitch app registration (Alex).** Twitch requires 2FA ("You must also enable two-factor authentication"). Register with the **Public** client type. Public clients "are only limited to the usage of device authorization grant flow… cannot use… client credentials, implicit grant flow". So the client ID ships in the app and the client secret never does.

Without a client secret there's no app token, which Get Streams and Search need ("Requires an app access token or user access token"). So **discovery needs the user to sign in.** Signed out, the app can only open a channel by name, using the embed and no chat.

**P2 – Supported playback.** The agreement says: "You must adopt and integrate our embeddable player for all Twitch video content. You may not use any other player…" and "Do not modify, replace, interfere with, limit, block, cover, or obscure… advertisements within the player". No Helix endpoint returns playback or HLS addresses.

| Option | Verdict |
|---|---|
| A. A small static page on an HTTPS domain we own (e.g. a saphid GitHub Pages site), loaded in one `WKWebView` that the app keeps alive. It uses the documented `Twitch.Player` controls (`play`, `pause`, `setChannel`, `setQuality`, `setMuted`) and events (`ONLINE`, `OFFLINE`, `PLAYING`, `PLAYBACK_BLOCKED`), with `parent` set to that domain. | **Recommended.** Test it first. |
| B. `loadHTMLString` with an owned-domain `baseURL`, so nothing is hosted | Possible, but whether Twitch accepts that origin is U. Test alongside A. |
| C. Load `player.twitch.tv` directly with `parent=player.twitch.tv` | Fakes the parent value. Probe use only. |
| D. Pull a stream address from GQL/usher and play it in AVPlayer | **Rejected.** It uses undocumented material and a non-Twitch player. |

Two embed facts matter for layout. Twitch says "Embedded video windows must be at least 400x300 pixels" and that size and visibility are needed for autoplay. It also says mobile video "cannot be played without user interaction".

**P3 – Real Picture in Picture.** `AVPictureInPictureController` needs an AVPlayer layer or sample buffers, and both need a native stream, which option D rules out. The only allowed route is WebKit's own video Picture in Picture: `allowsPictureInPictureMediaPlayback`, which defaults to YES in the SDK header.

Whether the Twitch embed exposes it, and whether it starts when the app goes to the background, is **U**. Calling `webkitSetPresentationMode` on Twitch's internal `<video>` element is undocumented interference. If the test fails, ship an honest "Picture in Picture unavailable" message. Chat focus would then use a docked video of at least 400×300 points.

**P4 – App name and bundle ID (Alex's decision).** Twitch's trademark rules say: "Don't incorporate Twitch's Brand Assets… in… app names" and "Don't combine Twitch Brand Assets as part of a name of a product or service". **"DuoTwitch" breaks both** for the display name and for the Twitch developer app name.

A bundle ID can't be reused once an App Store Connect record uses it, so this is a one-way door. I recommend a neutral display name with a "Compatible with Twitch" line, and settling the bundle ID before the record exists. The risk is lower while distribution is internal-only.

**P5 – App Store Connect.** `build/t3crew-audience.json` (the other worker's file) shows `t3crew` is an **internal group on the Duocord app** (`com.saphid.duocord`). TestFlight groups belong to a single app, so this group can't be reused. The plan is:
- create the `com.saphid.duotwitch` app record (I believe the App Store Connect API can't create app records, so this is probably a manual web step; I didn't verify it);
- create a new internal group on it;
- add exactly the current `t3crew` members plus Alex;
- check the membership matches before assigning a build. Internal testing avoids Beta App Review.

**P6 – Privacy policy.** The Twitch agreement requires "a publicly available and easily accessible privacy policy". Its other data rules:
- delete Twitch data when access is revoked or the user asks;
- keep cached Twitch content no longer than "a twenty-four hour time period";
- keep chat logs only as long as needed, with an opt-out.

## Native chat and sign-in

**Sign-in.** Use the device code flow: POST to `id.twitch.tv/oauth2/device`, show the code, open the verification page in an `ASWebAuthenticationSession`, then poll `oauth2/token` with the `device_code` grant at the given interval. Handle `authorization_pending`, expired codes and denial.

Tokens last 4 hours. Refresh tokens are "one time use only" and expire after "30 days" unused. That makes **a single-flight refresh mandatory**: if two requests refresh at once, the second refresh token is already invalid and the user is signed out. Store tokens in the Keychain (this-device-only). Validate "when it starts and on an hourly basis thereafter". Signing out revokes the token and clears all cached data.

**Reading chat.** Use EventSub over WebSocket at `wss://eventsub.wss.twitch.tv/ws`. It needs a user token ("If you use app access tokens with WebSockets, the subscriptions will fail"). Subscribe to these events, all version 1, all needing `user:read:chat`:
- `channel.chat.message`
- `message_delete`, `clear` and `clear_user_messages` (so moderation removals show correctly)
- `notification` and `chat_settings.update`

The app must also handle:
- subscribing within 10 s of the welcome message;
- treating a missed keepalive as a lost connection and resubscribing;
- for `session_reconnect`, keeping the old socket open until the new one sends its welcome;
- revocation messages;
- the limits of 3 connections, 300 subscriptions and a total cost of 10.

**Sending chat.** Use `POST /helix/chat/messages` with `user:write:chat` and a 500-character limit. `is_sent` and `drop_reason` give a definite answer on whether the message was sent, which the failure UI should show. Keep the draft after any failure, and back off on 429 (20 messages per 30 s for ordinary accounts).

**Emotes and badges.** These come from Helix with either token type.

**Recommended scopes:** `user:read:chat`, `user:write:chat` and `user:read:follows`. Optionally add `user:read:emotes`, `user:read:blocked_users`/`user:manage:blocked_users` and `clips:edit`.

**No message history.** EventSub sends no recent messages when you join, so chat should say "Showing messages since you joined". Anonymous IRC and other services' history are undocumented, so don't use them.

**Gaps to document as N/A** (no documented viewer API was found in the Helix list): follow/unfollow (only reads exist), subscribing, sending Bits, channel points, poll and prediction voting (only broadcaster endpoints), stories, going live, push notifications/Activity (needs a server), and ad-free viewing through OAuth.

## Proposed architecture

- **Targets:** app and tests only, iOS 27.1 minimum, MainActor by default (like Duocord). No extensions until after TestFlight.
- **`Twitch/`:** `HelixClient`, `DeviceAuth`, `TokenStore` (Keychain, single-flight refresh, hourly validation), `EventSubSession` (state machine), `ChatSender`.
- **`Player/`:** one `PlayerHost` keeps the single `WKWebView` alive outside SwiftUI's view identity. Layouts move it between containers and never recreate it. A bridge passes only the documented `Twitch.Player` events from our own origin.
- **`Platform/Fold`:** port Duocord's `FoldReader` principle (`reservedRegions(kind: .division)` plus `UIHingeInteraction`, a DEBUG fake fold, and a re-query on every layout pass). The SDK has no notification for region changes; I confirmed this. The SDK also offers SwiftUI equivalents (`GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, `ArrangementView` with `.split` and overlay styles, `toolbarVerticalEdge`) and `UIArrangementViewController`. All are iOS 27.1+.
- **Layout:** the chosen mode is user intent (`stacked`, `split(edge)`, `fullVideo`, `slimChat(edge)`, `chatFocus`). Posture and size class come from the environment. The final layout is one pure function of those inputs, so it can be unit-tested. Book pose snaps the divider to the fold. Tabletop puts video above the fold and chat plus composer below. Never use the overlay arrangement over the player.
- **Chat UI:** a `UICollectionView` with a bounded ring buffer (about 500–1,000 messages) and batched diffable updates (about every 150–250 ms). Auto-scroll pauses when the user scrolls up, with a "new messages" pill. Port Duocord's `ComposerContinuity` for the composer.

## Acceptance test matrix

| # | Check | Evidence needed |
|---|---|---|
| T1 | The same `WKWebView` instance with an unchanged navigation count, across all 5 modes × compact/regular/book/tabletop | Mounted test plus a live check that `PLAYING` continues |
| T2 | No native view overlaps the player frame in any mode; the frame is at least 400×300 wherever autoplay is claimed | Geometry test |
| T3 | Book edges match the fold; in tabletop the player sits above the fold and the composer below it | Fake fold plus the Duo Simulator. Duocord's code notes the Simulator can't produce tabletop or portrait book, so **only a physical device can confirm these**. |
| T4 | Replayed EventSub sessions (welcome, keepalive timeout, reconnect, revocation, delete/clear) give a correct timeline; the buffer stays capped; 50 messages/s causes no visible stall | Unit and performance tests |
| T5 | `is_sent=false` shows `drop_reason`; 401 triggers exactly one refresh; 429 backs off; the draft is kept | Unit tests plus a **live** send |
| T6 | Device-code states; two concurrent 401s cause one refresh; validation at launch and hourly; sign-out revokes and clears data | Unit tests plus **live** sign-in |
| T7 | Draft, selection, channel and scroll position survive every layout transition and a background/foreground cycle | Port `UIContinuityTests` / `AdaptivePresentationTests` |
| T8 | Largest Dynamic Type size works in every mode; VoiceOver labels; chat is not read out message by message; username colours adjusted to at least 4.5:1 contrast; Reduce Motion; 44 pt targets | Mounted tests plus Simulator captures |
| T9 | Offline channel, mature-content gate, network loss, embed load failure, `PLAYBACK_BLOCKED` | Simulator plus live checks |
| T10 | Archive identity, build `VALID`, group members match `t3crew` plus Alex, `IN_BETA_TESTING` | App Store Connect readback |

## Launch blockers

1. No Twitch client ID yet (P1).
2. No compliant embed origin yet (P2).
3. No App Store Connect record or new internal group yet (P5).
4. The app name breaks Twitch's trademark rules (P4).
5. No privacy policy address (P6).
6. No live sign-in, chat or playback evidence yet. The council must not pass these from mock data alone.

## Objections

- **"Comparable to official Twitch" can't be fully met** with supported APIs. Judge it against the ordinary viewing experience, and publish the N/A list above.
- **Slim chat overlaid on the video** conflicts with the rule against covering the player. It should be redefined as a slim side column.
- **A small in-app floating video** in chat focus falls below the 400×300 minimum. System Picture in Picture is the only legitimate small-video route.
- **Compact portrait is a known limit:** on screens narrower than 400 points, the embed's minimum size can't be met.
- **Twitch's prohibited-use clause** bars embeds that "replicate the Twitch experience without offering additional content or data of substantial value". The Duo layouts are the justification, so keep distribution internal.
- **The worker's player probe (unscored)** in `Player/PlaybackSession.swift:51-95` loads the player with `parent=player.twitch.tv` and injects scripts that drive Twitch's internal `<video>` element. That's acceptable only as a throwaway feasibility test; it must not ship (options C and D above).

## Sources

- [Twitch embed: video and clips](https://dev.twitch.tv/docs/embed/video-and-clips/)
- [Getting OAuth tokens](https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/)
- [Validating tokens](https://dev.twitch.tv/docs/authentication/validate-tokens/)
- [Registering an app](https://dev.twitch.tv/docs/authentication/register-app/)
- [Scopes](https://dev.twitch.tv/docs/authentication/scopes/)
- [Chat overview](https://dev.twitch.tv/docs/chat/)
- [Chat IRC](https://dev.twitch.tv/docs/chat/irc/)
- [EventSub subscription types](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/)
- [EventSub WebSocket handling](https://dev.twitch.tv/docs/eventsub/handling-websocket-events/)
- [Helix API reference](https://dev.twitch.tv/docs/api/reference/)
- [Developer Services Agreement](https://legal.twitch.com/en/legal/developer-agreement/)
- [Trademark guidelines](https://legal.twitch.com/en/legal/trademark/)
- [Official app lookup](https://itunes.apple.com/lookup?id=460177396&country=au)
- SDK headers: `UIViewReservedRegion.h`, `UIHinge.h`, `UIHingeInteraction.h`, `UIArrangementViewController.h`, `WKWebViewConfiguration.h`, `AVPictureInPictureController.h`, and `SwiftUICore.swiftinterface` (iOS 27.2)

I made no edits, commits, account writes or invitations. My only temporary download folder was deleted.
