# Signed Simulator checkpoint — real Keychain access

The 61-test normal-app proof in `build/proof/native-configured/REPORT.md`
obtained a real native device code but stopped before authorization. It showed
a saved-sign-in Keychain error. Its Chrome activation URL never committed
despite bounded foreground attempts; no account, discovery, playback or chat
integration was proven. All 10 bundle and 44 source entries matched.

A new read-only regression calls the real `KeychainCredentialStore.load()` in
the application host. It neither clears credentials nor prints their contents.
The unsigned build reproduced the error: one test failed, command exit 65,
`keychain-unsigned-20261105.xcresult` and matching log. Changing only the build
invocation to `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-` made the same test
pass: one executed, zero failed/skipped, command exit 0, no runtime warnings,
`keychain-signed-20261105.xcresult` and matching log.

The prior app had only the linker's ad-hoc signature (identifier DuoTwitch,
unbound Info.plist, no sealed resources). Xcode's signed app has identifier
com.saphid.duotwitch, bound Info.plist and sealed resources. No account/Keychain
reset, entitlements workaround or application credential-store change was
made. The controlled experiment identifies the verification build's signing
as the cause of this reproduced Keychain read failure. Normal-app restore and
save still require runtime verification outside XCTest.

Full signed Simulator test run: **62 passed, 0 failed/skipped**, command exit 0,
no Swift compiler diagnostics or xcresult runtime warnings. Owned temporary
DerivedData cleanup completed. Result:
`build/verification/configured-signed-20261105.xcresult`, matching log and
`build/verification/configured-signed-summary.json`.

Frozen source: 44 entries in `source-configured-signed-sha256.json`, SHA256
`563374ddd7bae809b824feabce56b2301b1b60761ca6f6eaae5523bcd43af7a6`.
Only `Tests/AuthTests.swift` changed from the configured source; app code and
public configuration are unchanged. Runtime bundle:
`build/configured-signed-simulator/DuoTwitch.app`, 12-file manifest
`build/verification/configured-signed-bundle-sha256.json` (includes signatures).
Debug dylib SHA256:
`e73ae2f7e465cfa6775a284da306064c1962d3866d31876aae18f5af5d2032d9`.

The historical unsigned Release build remains evidence for its exact build;
this checkpoint is not a signed device archive or TestFlight delivery. Native
authorization, discovery/chat, production watch/fold continuity and PiP remain
unproven. The fresh Sol high source review passes at **8.5/10**, with no
actionable findings in the new regression or bounded signing diagnosis.
It independently verified the 44 source entries, 12 bundle files and all
three actual xcresults. This is independent-session review without model
diversity under Alex's quota-recovery authorization. Report and T3 metadata:
`source-signed-keychain-review-sol.md`.

The signed normal-app retry verified that the startup Keychain error is absent
and that the production Account screen obtains a real device-code challenge.
All 44 source and 12 candidate/installed bundle entries matched before and
after. It stopped before authorization: Continue on Twitch was acknowledged,
but observation failed; the advised snapshot retry failed with
`regular iOS snapshot node escaped its cumulative clip`. No browser destination,
account approval, token persistence, discovery, native chat or WatchView was
verified. Report: `build/proof/native-configured-signed/REPORT.md`.

The runtime task
`node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3Aduotwitch-signed-native-auth-semantic-url-20261105`
completed as Codex / gpt-6-astra high. Owned app/Device resources were closed
without Simulator shutdown or Keychain changes. Under the Device tool stop
rule, no further GUI retry or alternative driver was used. The parent asked
for explicit direction on the permitted SSH-based Simulator fallback; no
dependent action is being taken while that choice is pending.
