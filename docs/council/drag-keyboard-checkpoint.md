# Drag resizing, keyboard dismissal and navigation cleanup

Base: main 94d29c018a54215b56f49ace7b6a2463660285d0. User requests a drag
handle instead of the chat-size slider, a Hide keyboard button, and a less
cluttered side menu. Alex clarified that side menu means Viewing options only; the Explore sidebar
cleanup was reverted to the base implementation. User explicitly revoked further
Discord updates. No Discord read or send belongs to this change.

## Change

The focused safe-area slider and its extra bar are removed. The existing divider
becomes a native pan view with a 44-point touch target around the unchanged
12-point visible separator. Axis comes from actual pane geometry. The same
native composer remains mounted and is not asked to resign focus by resizing.
Native pan deltas use stable window coordinates and immediately accumulated,
clamped saved extents, including reversal at a size limit. VoiceOver adjustment
remains available; Full video and reserved-fold separators are noninteractive.

WatchView and NativeChatView share the composer's FocusState binding, with a
local fallback for standalone chat hosts. Hide keyboard appears as a titled,
symbol-only standard navigation item while focused; it clears that binding.
No global responder broadcast or draft mutation is used.

Viewing options retains playback, details, Account, a Layout sheet and the
Twitch link. Layout settings use a small system Form instead of two nested
submenus and size buttons. Resizing uses the divider/adjustable accessibility
action. The Explore sidebar remains unchanged.

Executable delta: App/WatchView.swift,
Chat/NativeChatView.swift, Platform/WatchArrangement.swift,
Tests/MountedWatchLayoutTests.swift. No playback, authentication, uploader or
receiver changes. The iPhone Duo UI patterns skill informed standard toolbar
placement and keyboard/fold behavior. Existing UI craft reference principles
remain content hierarchy, restrained chrome and progressive disclosure.

## Verification in progress

Swift frontend parse exits0. The mounted production fixture now requires no
UISlider, a 44-point native handle, actual pane changes from pan deltas on both
axes, accumulation of several events before layout, the same first responder,
unsent draft and selection. The focused attachment shows Hide keyboard, but the hosted UIKit tree does not
expose SwiftUI's toolbar action; attempted UIControl and accessibility discovery
failed without establishing a product defect. That action assertion was removed.
Direct pan-delta dispatch does not establish physical touch routing, keyboard
clearance or toolbar dismissal. Those require device-surface verification.

Focused result: build/verification/drag-keyboard-focused.xcresult/log/exit.
Final full suite: build/verification/drag-keyboard-final.xcresult, log, summary
and exit receipt. 114 passed, zero failed/skipped, exit0. Candidate:
build/drag-keyboard-final-simulator/DuoTwitch.app. Strict/deep codesign exit0.
Current-candidate silent visual checks and independent review are pending. Existing physical keyboard/live playback/outside/fold limitations
remain; no new physical fix is claimed before device evidence.

## Capacity

Free space was about3GiB and falling; the normal10GiB admission floor blocked
new builds. Verified no package-manager install/prune or open pnpm-store file,
then used CI=true pnpm store prune. It exited0, reporting3.61GB of replaceable
package data removed; installed environments and lockfiles remain. Observed
free space later recovered to about6.9GiB. No other deletion occurred. Pending
app-update staging, source, app data, databases, signed builds and recovery
artifacts were preserved. This bounded verification uses the previously used
5GiB admission reserve. Receipts: build/verification/handle-cache-recovery/.

## Scope clarification

Alex clarified Viewing options only. Cancelled the broad-scope review and visual
tasks before replacing the freeze. The 114-pass result above belongs to the
pre-clarification candidate with sidebar cleanup; narrowed candidate verification
and reviewer/runtime results are separate. No old pass is relabeled.

## Narrowed final candidate

MainView.swift exactly matches base HEAD; the executable delta is four files:
WatchView, NativeChatView, WatchArrangement and MountedWatchLayoutTests.
All114 tests passed, zero failed/skipped, runtimeWarnings empty, exit0 in
build/verification/drag-watch-final.xcresult (matching log/summary/exit).
Strict/deep signature exit0. Existing AccountView compiler deprecation remains.
Candidate build/drag-watch-final-simulator/DuoTwitch.app; source62 and exact12
bundle freeze: drag-watch-final-source-sha256.json and
build/verification/drag-watch-final-bundle-sha256.json.
Cancelled old tasks6d0cac1b (source review) and86ca15fa (visual) have no accepted
verdict. Astra cleanup run3c300310 restored all348 saved preference files exactly,
portrait and closed owned app/session/panel; data and Keychain preserved.
Fresh narrowed source review and silent visual acceptance pending.

## Target-boundary fix

Accepted source P3: symmetric44point target expansion could leave15points
outside screen bounds at a one-point edge pane. WatchSplitTarget now constrains
its target frame to available size and reports the divider's local offset. The
native view draws its strip/grip at that offset, preserving visible alignment.
A new geometry regression covers both axes/sides, minimum/maximum splits and
sub44point containers, requiring full containment and preserved grip position.
Exact extracted production geometry red fixture fails at x=-15, exit1; green
fixture exits0. Full app regression and new source/runtime rechecks pending.
Prior114test/current runtime evidence remains attributed to its earlier freeze.

Final edge-fixed full suite:115passed,0failed/skipped,runtimeWarnings[],exit0;
actual build/verification/drag-watch-delivery.xcresult with log/summary/exit.
Strict/deep signature0; candidate build/drag-watch-delivery-simulator/DuoTwitch.app.
Source62/exact12-file bundle freeze uses drag-watch-delivery manifests.
Narrowed historical runtime task2a5da176 (Codex/Astra/high, completed personally)
passed below/beside/leading dragging, tiny panes/reversal, relaunch persistence,
reset and short menus/Layout portrait/landscape. Signed out: keyboard action
not exercised. Identity exact before/after;369 preference files restored exactly,
portrait and own app/session/panel closed. Report build/proof/drag-watch-current/report.md.
Fresh source recheck and edge-fixed silent verification pending.

Final source recheck25ef3754 completed personally via Codex/GPT-6.1 Sol/high:
no actionable P0-P3 findings in complete frozen four-file delta. Prior P3
resolved. See drag-watch-delivery-review-sol.md. Same-model independent session,
no diversity claim. Final edge-fixed runtime taskb0d10614 still pending; no
TestFlight delivery of these changes yet.

## Final silent runtime and delivery start

Taskb0d10614 completed personally using OpenAI/Codex GPT-6 Astra/high without
delegation: no actionable findings in edge-drag/Viewing options scope.
One-point leading/trailing and tiny portrait/below panes recovered by dragging
visible grips with correct alignment. Viewing options/Layout worked.62source and
exact12candidate/installed matches before/after.390 fresh preference files restored
byte-for-byte; portrait restored, own app/session/panel closed; data/Keychain
preserved. Signed out: Hide keyboard/composer runtime not exercised. No Play.
Report build/proof/drag-watch-delivery/report.md and receipt.json.

Reviewed source committed/pushed as860ec92. Signed internal-only archive/upload
started once through the existing reviewed5GiB-floor job; exact launch receipt
build/testflight/drag-watch-supervisor-launch.json. No duplicate job, public
release/external group or Discord action. Processing/assignment not yet claimed.

## Delivered

0.1.0(202611060438), build4f7cea8b-cdf2-4529-ac71-0712c66cfd0f, from
860ec926bbaac918504a7258ceca786c71b4b2a1. Archive identity/signature/internal-only
export verified, exact8-file manifest. Archive/upload/supervisor/processing/
distribution/readback exits0. VALID/INTERNAL_ONLY/IN_BETA_TESTING, exact complete
explicit Alex/t3crew/DuoCrew internal relationships, autoNotifyEnabled=true and
matching en-US notes. No duplicate invite. Email receipt/installation unverified.
Final receipt build/testflight/drag-watch-delivery-final.json, exact archive
and receipts build/testflight/202611060438/. No Discord read or send. Final
source/runtime reviews and115test evidence remain bounded as stated above.
