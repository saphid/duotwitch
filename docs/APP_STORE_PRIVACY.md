# App Privacy preparation — 8 November 2026

This is an evidence inventory and answer plan for Saphid Duo Viewer, bundle `com.saphid.duotwitch`, app6831008730. **It is not an applied or published Apple label.** Executable candidate [029339d](https://github.com/saphid/duotwitch/commit/029339df86e87f4347aac2193f3c8abb15e37d8a), App Store1.0/build202611080727. Keep [approval checklist](APP_STORE_APPROVAL.md) as the submission checkpoint.

## Rules verified from Apple

[App privacy details](https://developer.apple.com/app-store/app-privacy-details/) defines collection as off-device transmission accessible longer than needed to service the request in real time. On-device-only storage is not collection for the label. All third-party partner collection must be considered. The guidance explicitly says: “Data collected via web traffic must be declared, unless you are enabling the user to navigate the open web.” The embedded Twitch player is app functionality, not an open-web browser.

[User privacy and data use](https://developer.apple.com/app-store/user-privacy-and-data-use/) says tracking within a functional webview requires ATT permission. A native app having no IDFA access or advertising SDK does not establish that its embedded service performs no tracking. A privacy policy link or web consent banner alone does not establish an ATT-compatible implementation.

Current source has no ATT integration. The privacy manifest's `NSPrivacyTracking=false` covers the declared native implementation; it is not independent proof about Twitch's remote player. **Resolve the embedded-player assessment before asserting an app-wide no-tracking label or submitting.** Do not add a prompt without establishing which tracking it controls, and do not suppress or modify Twitch's official advertising/player code.

Fetched HTML/text evidence is in ignored `build/app-store-approval-20261108/`: `apple-privacy-details.*`, `apple-att-guidance.*`, `twitch-privacy-notice.*`, `twitch-embed-docs.*`. These are policy sources, not a network capture or runtime finding.

## Native and developer-held data

| Flow and source | Data and retention | Proposed label treatment |
| --- | --- | --- |
| Automatic playback uploads: `Player/PlaybackDiagnosticRecord.swift`, uploader/transport; receiver in `services/diagnostics-receiver/` | App/OS/build, event timestamps, performance counters, playback/layout/audio state; per-run/session random UUIDs. Allowlist excludes account/channel identity, tokens, chat, media URLs, freeform errors and device uptime. Private receiver retains up to24h, bounded10k records/4MiB/128runs. No request/IP logging in receiver source. | **Performance Data**, **Other Diagnostic Data**, and diagnostic interaction events under **Product Interaction**; **App Functionality**, **not linked to user**, **not used for tracking** for this developer-held flow. Reconcile final categories with live Apple catalog; do not use Data Not Collected. |
| Credentials: `Auth/CredentialStore.swift`, `Auth/TwitchAuth.swift` | Access/refresh tokens, user ID/login and scopes in local non-sync Keychain. Direct auth/API requests go to Twitch. Native sign-out clears saved credentials. | Local Keychain alone does not require collection disclosure; Twitch's off-device processing is assessed separately below. No password is received by the native app. |
| Blocks/preferences: `Chat/ChatSession.swift` | Blocked user IDs/logins in UserDefaults; remove by unblock or sign-out. Layout/settings local. | On-device-only entries do not need collected-data label categories. Do not claim account-level Twitch blocks. |
| Native chat: `Twitch/TwitchAPI.swift`, `Chat/ChatSession.swift` | Sending posts text, sender/broadcaster IDs and optional reply ID to Twitch. Received chat has bounded in-memory500-message timeline; drafts in memory. No developer diagnostic collection. | **User ID** and **Other User Content**, linked to Twitch account, **App Functionality**. Public channel chat is not private email/text messaging. Twitch may use/retain this information for other policy-defined purposes; assess partner row below. |
| Support/report: `App/SupportLinks.swift`, Account support links | User-sent email draft; selected author login/message ID/text included. Email sender address and contents reach developer only if user sends. Retained for support, deletion by request. | Conservative inclusion: **Email Address**, **Customer Support**, **User ID** from reports; linked, **App Functionality**, no developer tracking. Do not assume optional-disclosure exemption: all Apple's criteria, including prominently displayed account/name alongside submitted data, must hold. No report was sent in verification. |
| Share local diagnostic file | Explicit system share action to recipient chosen by user. Automatic upload has a separate projection/queue. | No implicit developer collection from opening share sheet. User-directed exports must not be conflated with automatic allowlisted uploads. |

Ephemeral UUIDs correlate diagnostic events within one run; they are not a persistent device or account ID. The “not linked” proposal applies only to the audited developer-held diagnostic payload. It does not extend to Twitch data, proxy/hosting/network-service policies, or information voluntarily emailed with identity.

## Twitch/hosting assessment still to resolve

[Current Twitch privacy notice](https://www.twitch.tv/p/en/legal/privacy-notice/) (page says modified08/12/2026) describes IP addresses, unique user IDs, device/browser types and identifiers, referring/exit addresses and service interactions. It describes customized advertising and ad measurement, and sharing cookie/mobile-ad identifiers with third-party ad networks for advertising on and off Twitch. This is evidence that the partner assessment matters; the general notice does not prove which practices occur in this specific embed/session.

`web-player/index.html` loads Twitch's official embed script. `Player/PlaybackSession.swift` constructs `WKWebViewConfiguration` without declaring a distinct nonpersistent data store, and does not implement ATT. WebKit default protections are not evidence that all policy-defined tracking is absent. Do not claim a user opt-out changes partner behavior without a supported control and verified effect.

Before final label publication:

- Determine applicable embedded-player data collection and purposes from official, embed-specific documentation plus authorized runtime observation. Account/user IDs, product interaction, search terms, advertising data, device/cookie identifiers, approximate location from IP and diagnostics are items to assess, not a claim that every category is collected by this app.
- Separate data Twitch retains from request-only fields. Native search sends queries directly to Twitch; do not invent a retention exemption.
- Establish whether the supported integration tracks under Apple's definition. If so, implement an official consent-compatible route and ATT behavior (including denial) before upload/submission. If evidence establishes no tracking, preserve that evidence rather than inferring it from the absence of IDFA.
- Host page delivery uses GitHub Pages; its network/hosting collection is governed by [GitHub's policy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). Do not attribute the diagnostic receiver's no-IP-log implementation to GitHub or Twitch.
- Capture no private account/session data into public artifacts. No permission is granted to sign into a desktop browser, a personal Twitch account or a physical device.

## Apply and verify after authentication

The first trusted-device challenge expired. A **fresh second challenge succeeded** with Alex’s private code. Task-local cache authentication readback is true, passwordStored false, and provider selection matches the existing team. The one-use secret file and FIFO were removed; shared auth/config remain unchanged. Private auth evidence is protected under `apple-auth-private/attempt-2/`.

Use installed `asc web privacy` with `ASC_BYPASS_KEYCHAIN=1`, isolated `ASC_WEB_SESSION_CACHE_DIR`, file backend and `ASC_WEB_NO_AUTO_LOGIN=1` for reads after authentication. Live `catalog` and `pull` succeeded for app6831008730. `privacy-catalog.json` contains current tokens. `privacy-pull-result.json` reports **published=false, publishedKnown=true**; `privacy-current.json` currently has **DATA_NOT_COLLECTED**, which is incompatible with automatic diagnostic collection. Do not publish it.

`privacy-working-draft-INCOMPLETE.json` records the seven source-backed baseline categories using live-validated tokens (support, email, user ID, public chat content, interaction, performance and other diagnostics). `privacy-working-draft-NOT-FOR-APPLY.txt` marks the unresolved partner assessment. This draft is deliberately **not ready for apply/publish**. Fetch live state again before any mutation and finish embedded-player purposes/linkage/tracking first. Canonical file shape is `schemaVersion:1` and `dataUsages` entries with `category`, `purposes`, `dataProtections`. `DATA_USED_TO_TRACK_YOU` is the CLI's tracking protection token; native-only no-tracking must not be applied to unknown partner flows.

The dry-run `privacy-working-draft-plan.json` succeeds (exit0) and proposes seven creates with no deletes; **no apply/publish was run**. After the partner assessment is resolved, generate a final plan and inspect every addition/removal before authorized apply; publish explicitly and pull/read back published state. Protect any private exports. Re-run deep validation for exact version/build and preserve MANUAL release. A successful public API validation cannot verify App Privacy publication without a web session.
