# Configured candidate — registered public client

The only executable/configuration delta from source checkpoint 7 is
`Config/App.xcconfig`: set the verified public client ID and deployed owned
player URL. No credentials or client secret are bundled. Registration evidence
is documented in `docs/PUBLIC_CLIENT.md`.

Owned Duo Simulator test run: **61 passed, 0 failed/skipped**, command exit 0,
no Swift compiler diagnostics and no xcresult runtime warnings. Evidence:
`build/verification/configured-20261105.xcresult`, matching `.log`, and
`build/verification/configured-summary.json`. The private DerivedData wrapper
completed cleanup.

A real unsigned Release Simulator build also exited 0 with the registered
configuration. The configuration guard ran under sandbox-exec, with no Swift
diagnostics. Log: `build/verification/configured-release-20261105.log`.
This is not a signed archive or TestFlight artifact.

Both Debug and Release Info.plists were read back: bundle
`com.saphid.duotwitch`, public ID `xuaoegs6v9yy1dw86gemt4gyuqtf1o`, player host
`https://saphid.app/apps/duotwitch/player/index.html`.

Frozen source: `source-configured-sha256.json`, 44 files, SHA256
`f09d573c9312bef422d43ea90dcebf21177be00f181085fb0f28a3c6f91fcb75`.
Runtime candidate: `build/configured-simulator/DuoTwitch.app`; complete
10-file manifest: `build/verification/configured-bundle-sha256.json`.
Debug dylib SHA256:
`eda5f6864675b10efaef3dd75b495125a40edd9d4c0497fe143ffc14c7483300`.

Current native sign-in, discovery, production WatchView, chat and fold runtime
proof are pending. The historical 57-test player probe proof retains its own
identity and does not identify this binary. Fresh source review was attempted
through Claude Opus 5.5, effort xhigh, but failed before a review was produced:
"Claude API rate limit reached. Try again later." No fresh source-quality pass
is claimed; the earlier score belongs to the 57-test candidate. Task:
`node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3Aduotwitch-configured-source-review-20261105`.

Alex subsequently authorized GPT-6.1 Sol (Codex, high reasoning) for unfinished
implementation/review work during Claude quota exhaustion. A new read-only
review completed against the same unchanged frozen target; the failed Claude
turn was not reused. The parent remains the only source editor and keeps all
44 files frozen while Astra's runtime check runs.

The fresh Sol high review **passes at 8.5/10 for source quality**, with no new
actionable findings. It independently verified the 44 source entries, 10 bundle
files, actual 61-test xcresult and saved Debug/Release logs. It provides a fresh
independent session, without model diversity from the implementation author,
under Alex's explicit quota-recovery routing. Actual source report and T3 task
metadata are in `source-configured-review-sol.md`. Production SwiftUI callback
ordering, fold/navigation fit restoration and live integration still need
runtime proof. Neither the earlier failed Claude attempt nor this source pass
establishes product parity or TestFlight readiness.
