<img src="assets/icon.svg" width="64" height="64" alt="">

# Foldstream

Public branding is Foldstream. Repository, Xcode scheme, bundle and registered Twitch client identities remain unchanged. See the [App Store approval checkpoint](docs/APP_STORE_APPROVAL.md) for current candidate status; historical beta evidence below predates this rename.

A native SwiftUI Twitch viewer for iPhone and iPhone Duo, built in [T3 Code](https://t3.codes).

Browse live channels and categories, connect through a system-hosted Twitch approval page using the public device-code flow, and watch the official Twitch embed beside native EventSub chat. Viewing options include video/chat, slim chat, chat on either side, and video-only mode. Native Play and Pause supplement the official player controls; drafts remain in memory across mode changes and navigation.

The current source passes **74 signed Simulator tests** and a fresh independent-session source review. Production authentication, discovery, received chat, authenticated relaunch, draft continuity and native Play/Pause/resume have runtime evidence on the preceding candidate. This is a development beta; no overall Twitch-parity or final product-council pass is claimed.

The latest source separates system audio inactivity from genuine interruptions, keeps playback controls visible, and gives Twitch approval a prefilled browser handoff with resumable cancellation. These changes have source/test evidence; the reported physical Duo one-second stop remains unconfirmed. The current muted runtime verified controls and portrait layout, but its nearly static captures did not establish sustained moving video or resume. Internal TestFlight 0.1.0 (202611051233) contains the reviewed changes.

## Current limits

- Picture in Picture is unavailable. Actual fold continuity, background recovery and a complete accessibility journey still need verification.
- The official embed requires at least 400×300 points. Smaller video areas show an external Twitch fallback. An active fold can constrain video to one panel even in video-only mode; the observed Simulator layout needs further investigation.
- Emotes appear after message text; badge artwork, VOD/clips, reporting/blocking and commercial/creator capabilities are incomplete or external.
- Runtime chat sending has not been exercised; verification has been receive-only.

## Development and evidence

Use Xcode 27.2 with the iOS 27.2 SDK; deployment targets iOS 27.1. Open `DuoTwitch.xcodeproj` and the shared DuoTwitch scheme. Keep Simulator signing enabled when exercising Keychain access. The registered public Client ID and owned HTTPS embed host are configured in `Config/App.xcconfig`; no client secret is used. Saved tokens belong in Keychain, never in source.

[Requirements](REQUIREMENTS.md) · [Implementation status](docs/IMPLEMENTATION_STATUS.md) · [Public client](docs/PUBLIC_CLIENT.md) · [Player host](docs/PLAYER_HOST.md) · [Ordering checkpoint](docs/council/native-play-ordering-checkpoint.md) · [Delivery status](DELIVERY.md)

Playback verification must establish official per-player mute or a verified silent Simulator route **before** starting a stream, including after a channel change or player recreation. Do not assume a previous mute state persists. Runtime artifacts stay in ignored `build/proof/`; their identities and limitations are recorded in the checkpoint documents.
