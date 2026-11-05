# Player host deployment — 5 November 2026

The exact page approved in Opus source review 3 was deployed to the existing
GitHub Pages site at https://saphid.app/apps/duotwitch/player/index.html.
No site settings or existing files changed. No full app source was published.

Repository: [saphid/saphid.github.io](https://github.com/saphid/saphid.github.io).
Deployment commit: [be1f8bc](https://github.com/saphid/saphid.github.io/commit/be1f8bc7757c51cf23d98604e0a986aaad92f186).

HTTPS GET returned 200 and exact byte equality with web-player/index.html.
SHA256: 6e86e8e1b539cf9128ced76ea88079f65e7abded5cd48c0f2fea287536de331f.
Receipts: build/player-host-publish.json and build/player-host-readback.json.

The page contains no credentials. Its parent is derived from its actual HTTPS
hostname. This proves publication and readback, not runtime Twitch playback,
authentication, chat or Picture in Picture.
