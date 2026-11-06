# Watch chrome and keyboard resizing — 6 November 2026

Frozen base HEAD ac609a8; uncommitted executable delta is exactly App/WatchView.swift,
App/MainView.swift, Chat/NativeChatView.swift and Tests/MountedWatchLayoutTests.swift.
User supplied a physical screenshot rejecting the duplicate native transport rail,
then reported inability to resize panels while the keyboard is open. This target
is a UI correction, not a new physical playback/fold recovery claim.

## Change

The player owns all of its video-pane allocation; WatchVideoPanelLayout and both
permanent native transport variants are removed. One standard More menu retains
native Play/Pause, retry when needed, channel details/diagnostics, modes, chat
position/size, account and the Twitch link. The duplicate global Account toolbar
item is suppressed while watching; Account remains in that menu. Player failures
still get a contextual status overlay, rather than a permanent status rail.

A Chat size slider occupies the safe-area edge above the keyboard while the
composer is focused. NativeChatView forwards only focus state; stable composer
identity and existing resize persistence remain. The slider changes actual pane
allocation and disappears when editing ends. This avoids dependence on a keyboard
ToolbarItemGroup that did not mount in the actual hosted fixture.

The large persistent chat connection banner becomes an on-demand notice in the
existing chat header; the full uncertainty text remains available in its alert
and accessibility label. Duplicate connection text in an empty composer is removed.
No playback session, WebKit/public host, auth, transport, receiver or audio behavior
is changed. UI craft reference consulted: Human Interface Craft 1997–2026,
principles1–3 (content hierarchy, restrained chrome and progressive disclosure),
and the iPhone Duo UI patterns skill (standard, titled system toolbar controls).

## Verification

The added whole-player allocation assertions failed against the original rail in
watch-chrome-red.xcresult/log, exit65; they now pass for all25 mounted panel sizes.
The first attempt was deferred at the default50GiB reserve before compilation,
with separate receipts. Silent/synthetic full suite watch-chrome-final.xcresult:
113passed, zero failed/skipped, runtimeWarnings empty, shell exit0.

A new production WatchView fixture restores only in-memory fake credentials via
StubTwitchProtocol, with an unconfigured no-network chat API and stubbed media.
It focuses the real native composer, invokes the real UISlider valueChanged
control action for beside and below positions, requires changed actual video
allocation, and verifies the same focused composer and unsent draft. Ending
editing removes the slider. No actual login, credential or chat send is involved.

A final test-only capture of MainActor requestedScopes before the Sendable stub
closure removes the new compiler warning. This exact final candidate was rebuilt
and its affected keyboard test passed1/1, exit0, in watch-chrome-clean.xcresult.
The preceding full113-test run has identical application source; only that test
capture differs. Existing AccountView deprecation/AppIntents/Simulator noise remain.

Final source62 manifest: docs/council/watch-chrome-source-sha256.json,
SHA2564005a32f82e1ab1e9146c7524a178b57c0329b736e8b0753f193f6ad580aae1d.
Exact12-file candidate: build/watch-chrome-simulator/DuoTwitch.app.
Bundle manifest: build/verification/watch-chrome-bundle-sha256.json,
SHA256c39345a0cb9f49dea25a880bf3a6b3e8e66ca696db1bcdcd1b95a6340458e6d3.
Strict signature exit0. Fixture image/manifest: build/proof/watch-chrome-keyboard/.
Window-only rendering omits the remote keyboard pixels; this is a focused
production UI fixture, not a physical phone screenshot or live-video proof.

Fresh independent Codex/Sol/high source review completed with no actionable
findings; see watch-chrome-review-sol.md. Paused current runtime remains pending. All runtime work must
remain inaudible; no Play is needed for this visual check. Earlier Simulator
motion failures and unsolicited Twitch Pause remain unresolved.

## Capacity and release

Disk fell from36.7GiB to4.9GiB during this work. Go/CocoaPods caches were verified
idle and cleared through their owning CLIs, recovering about3GiB; UV cache cleanup
returned0 but little physical reclaim. No source, databases, Keychain, Simulator
data, signed archive or retained proof was removed. Live large databases are
preserved; no growth cause is claimed. Build admission used an explicit5GiB
reserve. Cache receipts: build/verification/cache-recovery/.

The private next-release job is the existing release-job.py with only the bounded
reserve changed10→5GiB consistently in state, preflight, monitor and wrapper env;
no job is started yet. Exact job build/testflight/watch-chrome-release-job.py,
SHA2566848bc1dcb5c800a4baef375a61a61c210b906fae4462e2ba303e8ab1036fd31.
Signing identity and internal-only upload checks are unchanged. Include this
private operational script in source review before any next release invocation.
Current distributed build remains0.1.0(202611060151), sourcee78213d.

## Refined candidate — supersedes original freeze

After the first silent visual acceptance task found an over-tall menu and a
DEBUG-only Account presentation gap, the primary routes now appear first in the
menu; layout and chat settings occupy submenus. One app-root Account presenter
serves both normal and DEBUG watch roots. Signed-out chat uses a compact text
prompt without the repeated decorative chat icon. This final executable delta
is five files: App/DuoTwitchApp.swift, App/MainView.swift, App/WatchView.swift,
Chat/NativeChatView.swift and Tests/MountedWatchLayoutTests.swift, against ac609a8.

The exact refined full run watch-chrome-refined.xcresult reports 113 passed,
zero failed/skipped, exit 0. Strict/deep codesign verification exits 0. Existing
AccountView presentation-anchor deprecation and AppIntents/Simulator noise remain.
Candidate build/watch-chrome-refined-simulator/DuoTwitch.app contains 12 files.
New source manifest docs/council/watch-chrome-refined-source-sha256.json contains
62 entries, SHA256 4b022b16e78dcbbd40c05080070afebe43fd219ce7267811ca057d43a5221072.
New bundle manifest build/verification/watch-chrome-refined-bundle-sha256.json
SHA256 fff213bf4213174457cb51428e56a9438e2babfa886164bcf3a63548045c0ad4.
Earlier manifests and reports remain attributed to the earlier candidate.
A fresh source recheck and short paused visual recheck are required.

Disk recovered externally before the refined build; the refined run used the
normal explicit 10 GiB reserve. Prefer the original release-job.py with its
10 GiB reserve; the reviewed 5 GiB alternative has never been started.

## Shared account observer correction

The refined review found one P2 in the DEBUG direct-watch route: the root
Account sheet could sign in without MainView's account-change observer. The
observer now lives next to the common presenter in DuoTwitchApp and was removed
from MainView, so there is one account-change handler for either root. See
watch-chrome-refined-review-sol.md. The concurrent visual task was cancelled
because its candidate was superseded; do not attribute visual acceptance to it.
A new full test run is watch-chrome-account-root.xcresult.

The corrected candidate full suite passes 113 tests, zero failed/skipped, exit0
in watch-chrome-account-root.xcresult. Strict/deep signature command/output and
exit0 are saved. Freeze: docs/council/watch-chrome-account-root-source-sha256.json
and build/verification/watch-chrome-account-root-bundle-sha256.json (62/12).
Candidate: build/watch-chrome-account-root-simulator/DuoTwitch.app.

## Resolved broadcaster identity correction

The next source recheck found a second DEBUG-entry P2: its pre-existing synthetic
constructor used login as user ID. DebugWatchEntry now keeps an explicitly empty
identity while signed out, and resolves api.user(login:) after sign-in. It cancels
stale lookups and offers a bounded explicit retry after lookup failure. AppModel
refuses authenticated chat startup with an empty identity in both watch() and
accountChanged(). The resolved numeric ID then enters the ordinary watch path.
Production library channels keep their existing verified IDs. New synthetic
regression covers signed-out entry, account restore/change and unresolved
reappearance without a socket, followed by real-ID lookup and chat connection
using an in-memory fake socket and HTTP stub. No real login or message is sent.
The first new test compile attempt failed at an async XCTest autoclosure, exit65;
the await was separated from XCTUnwrap before the final verification run.

The cancelled visual owner has now restored its original preferences exactly,
portrait, and closed its own app/session/panel. Cleanup receipt lives at
build/proof/watch-chrome-refined/cleanup.json. The later blocked visual attempt
made no changes; DEVICE_IN_USE was an ownership issue, not an app finding.

Current executable delta is seven files against ac609a8: App/AppModel.swift,
App/DuoTwitchApp.swift, App/MainView.swift, App/WatchView.swift,
Chat/NativeChatView.swift, Tests/ChatSessionTests.swift,
Tests/MountedWatchLayoutTests.swift. Earlier candidate manifests stay historical.

Final identity candidate: 114 tests passed, zero failed/skipped, test exit0.
Strict/deep signature command/output and exit0 saved. Result and summary:
build/verification/watch-chrome-identity-final.xcresult and -summary.json.
Source62: docs/council/watch-chrome-identity-final-source-sha256.json.
Exact12 bundle: build/verification/watch-chrome-identity-final-bundle-sha256.json.
Candidate: build/watch-chrome-identity-final-simulator/DuoTwitch.app.
Fresh review and silent acceptance dispatched for this exact candidate.

Final source review completed with no actionable findings in the full frozen
seven-file executable delta; see watch-chrome-identity-final-review-sol.md.
Task a5b691e6-05d7-406f-97a9-1678591ceeb0, OpenAI/Codex/gpt-6.1-sol/high, completed.
Same-model independent session only. Current silent visual acceptance is still
pending; do not claim physical keyboard or live account proof.

## Delivered final candidate

Reviewed source committed/pushed as a9f46a311cba264f13fe3fb4657bac5439264db3.
Astra/high silent visual acceptance completed with no actionable visual defects
in the scoped signed-out/non-playing controls. Monstercat was offline; no
Play/Resume/audio occurred. Source62 and exact12 candidate/installed identities
match at both boundaries. Preferences restored byte-for-byte, portrait restored,
owned session/panel closed, simulator/data preserved. Report and screenshots:
build/proof/watch-chrome-identity-final/. Task:
node:delegated-task:command%3Amcp%3A01b949c1-9016-42f6-a4e4-fd3e90c5884d%3Adelegate-task%3A39a569d8-b640-42ff-9b3f-e17afc430218
Actual OpenAI/Codex gpt-6-astra/high, completed personally without delegation.

Original release-job.py ran once with normal10GiB reserve, archive/upload/strict
signature/supervisor exits0. Build0.1.0(202611060259), Apple ID
4f4f1035-1ab2-4226-901d-ae9ae59698e8, VALID/INTERNAL_ONLY/IN_BETA_TESTING.
Live group readback is complete and explicitly assigns internal Alex, t3crew,
DuoCrew. Automatic notifications enabled; email receipt/installation unverified.
Exact trimmed What to Test notes verified. Archive identity and exact8-file
manifest are in build/testflight/202611060259/. Validated final receipt:
build/testflight/watch-chrome-delivery-final.json.
Authorized Discord #txt announcement/repo link sent through Beeper with exact
normalized self-authored readback; native Discord ID/placement unverified.
Receipt: build/testflight/watch-chrome-discord-receipt.json.

Physical keyboard touch/clearance/selection, mounted app-root sign-in transition,
live auth/chat, sustained playback and physical Duo/fold remain unverified.
Previous freeze/motion/host-Pause observations retain historical attribution.
