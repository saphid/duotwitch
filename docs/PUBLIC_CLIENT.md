# Registered Twitch public client

- Developer account: `saphid`.
- Registration name: **Saphid Duo Viewer**. This external Twitch registration has not been renamed.
- App Store branding: **Foldstream**, accepted by Apple on8November2026. The new uploaded/attached1.0(202611080806) displays Foldstream (VALID/APP_STORE_ELIGIBLE); the older1.0(202611080727) still displays Duo Viewer. Repository/module/executable/bundle and this public client identity remain unchanged.
- Client ID (public configuration): `xuaoegs6v9yy1dw86gemt4gyuqtf1o`.
- Type: **PUBLIC**; category: **Application Integration**.
- Registered development redirect:
  `https://saphid.app/apps/duotwitch/oauth-callback`.
- No client secret was created. No callback handler is implemented or claimed;
  native authorization uses Twitch's public Device Code Flow.

On 5 November 2026, Astra high used the authorized local MacBook Pro CUA
route to complete fresh-SMS sign-in and verify account `saphid`. Twitch
rejected registration names DuoTwitch and DuoTwitch by Saphid. The parent
selected the distinct developer name above; registration then succeeded.
Reloaded Manage details confirmed the persisted name, public type, category,
redirect and Client ID; the applications inventory contained exactly one app.
The exact cause of the rejected names was not established by the service.

Sanitized receipts and public metadata are in ignored files:
`build/mac-pro-twitch-cua-recovery-20261105.json`,
`build/twitch-client-distinct-name-registration-20261105.json` and
`build/twitch-public-client.json`. The final registration task
`node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3Aduotwitch-public-client-distinct-name-20261105`
completed as Codex / gpt-6-astra, high. Existing browser selections were
restored and no native app identity changed.

`Config/App.xcconfig` contains this public ID and the deployed owned-origin
player URL. An optional ignored Local.xcconfig can override them for another
environment. Access/refresh tokens remain runtime Keychain credentials and
must never be added to configuration or documentation.
