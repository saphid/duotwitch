# Prepared Twitch privacy inquiry — not sent

**Alex’s instruction,8November2026: Keep it as a draft. No message is authorized or pending.**

Recipient: **privacy@twitch.tv**, published in [Twitch's current privacy notice](https://legal.twitch.com/en/legal/privacy-notice/). Developer support may be the appropriate destination; please route internally if needed.

Subject: Official Twitch embed in iOS WKWebView: data collection and ATT-compatible behavior

Hello Twitch Privacy and Developer Support,

I am preparing Foldstream (iOS bundle com.saphid.duotwitch) for App Store review. I need accurate information about Twitch's official embedded player to complete Apple's privacy disclosures and ensure the supported integration respects Apple's App Tracking Transparency choices.

The app loads an HTTPS host page at https://saphid.app/apps/duotwitch/player/index.html using WKWebView. The host uses https://player.twitch.tv/js/embed/v1.js and Twitch.Player with channel, parent, width/height, autoplay=false and muted=false. Video playback uses the public player API. Native Twitch authorization is separate, uses the documented device flow, and is not passed into the player. The native app does not use IDFA or an advertising/analytics SDK. The current integration uses the default WKWebView data store. The existing Twitch registration still uses the name Saphid Duo Viewer; the public client identity has not changed.

Apple's documentation requires functional webview collection to be disclosed and requires ATT permission if the embedded functionality tracks users under Apple's definition. Twitch's general privacy/cookie notices describe advertising and identifier use, but I could not find an embed-specific data/consent contract in the public player documentation.

Could you clarify:

1. For this official embed in iOS WKWebView, what data does Twitch or its advertising/analytics partners retain beyond servicing the current request, for which purposes, and is it linked to an account, browser or device identifier? Please distinguish guest playback from signing into the player.
2. Does this integration link data from the app with data from other companies' apps/websites for targeted advertising or ad measurement, or share it with data brokers, as covered by Apple's tracking definition?
3. What documented parameter, consent API or supported configuration should an iOS host use when ATT is not determined, restricted, denied, authorized or later revoked? Is there an officially supported playback mode that prevents such tracking while retaining the standard player and advertising behavior? Please provide implementation guidance for denial and revocation, not only a consent notice.
4. If mobile/WebKit defaults already change collection or advertising behavior, which documented guarantees apply specifically to this embed? Is a nonpersistent WKWebView data store supported, and does it materially change the above answers?

We will keep the official player, Twitch marks, controls and advertisements intact. We are not seeking stream URLs, an alternative player, ad blocking or an exemption from Apple's rules. A link to the relevant public documentation or confirmation from the responsible team would help us implement the supported behavior and publish accurate disclosures.

Thank you,
Alex / Saphid

---

Approval scope: send this single technical inquiry only if Alex explicitly authorizes it. No credentials, personal account exports or private diagnostics are included. No contract acceptance, marketing permission claim, code distribution or further correspondence is authorized by this draft. Player origin was checked against `Config/App.xcconfig` and `docs/PLAYER_HOST.md`.
