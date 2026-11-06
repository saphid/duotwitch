# Phone feedback and playback follow-up — 6 November 2026

Alex confirms that TestFlight 0.1.0 (202611052312) now continues playback in open
mode. This is a user-observed physical improvement after native audio activation
was removed. It does not establish background, interruption or fold continuity.

New report: playback pauses when leaving **DuoTwitch Full video layout**, not
Twitch native fullscreen / Done. Preserve selected channel/player and current
playback when returning to Video & chat or Slim, where the supported player fits.
Record the layout, geometry, visibility and native Pause cause around that exact
transition before selecting the correction. Do not auto-resume an intentional
user Pause or playback after leaving Watch.

Alex also requires video playback on the Duo outside display. Acceptance needs
actual compact/outside geometry, visible playable content and working controls;
a phone Simulator with a different screen is not physical outer-display proof.
Use compact/regular adaptation and the system arrangement/fold APIs. Twitch's
current official embed documentation requires a minimum 400×300 player; respect
that constraint and distinguish any supported viewing mode from a limitation.
No private stream extraction or minimum-size bypass is part of this work.

Verification should cover full -> balanced/slim and open -> outside -> open,
player identity/load count, uninterrupted media progress where expected, native
Pause remaining paused, draft/focus continuity and readable accessible controls.
Runtime media must be muted, with fresh official Unmute readback before Play.

## Reproduction and candidate

The Astra/high runtime on the previous frozen 54-source candidate observed zero
pauses in two compact 402-point returns. Same player/load remained, all fitting;
poor frame rendering prevents sustained-motion claims. See the historical
`build/proof/fullscreen-exit/REPORT.md`. It is not physical Duo proof.

A mounted **production WatchView**, with real AppStorage preference changes and
stubbed media/host events, reproduced Full video return at a narrow regular
550-point width: balanced and slim each requested insufficient-space Pause.
The focused test failed with four assertions, exit 65. This is the actual
production layout/fit/pause chain, but does not establish the physical trigger.

The candidate preserves the 400-point player width and stacks chat if the pane
cannot also fit 240-point side chat. Short compact layouts use side-by-side
allocation when supported. Stacked layouts prioritize the 300-point player plus
64-point native transport over the usual chat-height target. Active fold
regions still take precedence. There is no auto-resume behavior.

Focused layout green: 11 tests pass, exit 0. The final production regression also
covers 466-point regular width and verifies intentional Pause remains paused
across layout changes, with one load. Initial complete signed Simulator suite:
**101 passed, zero failed/skipped, runtimeWarnings empty, exit 0**. Strict/deep
signature verifies (exit 0). The old AccountView deprecation and AppIntents
metadata warnings remain; newly introduced Sendable warnings were corrected
before this final run.

Alex reports “Video needs more room” on the outside display. The historical
private phone log contains 382-point allocations; only numeric aggregate sizes
were inspected, not published raw. Twitch's 400 CSS-pixel minimum prevents a
supported inline player at that portrait width. The candidate provides explicit
rotation guidance and removes the ineffective Focus action at widths below400.
It does **not** claim portrait outer-display playback or physical continuity.

A privacy-filtered watch.layout event now records fixed viewing mode, compact
flag, usable bounds and numeric fold region. Both client and receiver allowlists
match; the actual Swift upload fixture contains this event and the receiver
suite passes **27 tests, exit 0**. It can distinguish the next phone transition
from video geometry, native Pause, provider Pause and lifecycle events.

## Collection integration and remaining gates

The staged lxso1 receiver and reviewed ownership/transaction fixes are integrated
as parent commits 62105bc and 1cba995. The fresh recheck
8211f63e-3b33-4ec0-9470-237c24a64c09 (Codex / gpt-6.1-sol / high) completed with
no actionable P0–P3 findings. Same model as author: independent session only.

Fresh live host preflight shows Python3.12, about29.9GiB free, no existing owned
unit/source/data or listener, and preserved Serve configuration. Standard775
parent directories use a private user group with zero other explicit or primary
members. The installer now accepts group-write only for such private groups,
while rejecting world-write and other group writers; no shared directory mode
was changed. This small delta plus layout diagnostics awaits fresh review.

Current candidate is frozen under fullvideo-source-sha256.json and the complete
build/verification/fullvideo-bundle-sha256.json. Receiver deployment, synthetic
HTTPS/readback, current live runtime and new TestFlight delivery remain pending.

## Accessibility review correction

Fresh independent review c58891e8-7289-4a09-997f-a2ade2c811c1 completed through
Codex / gpt-6.1-sol / high, reporting one P2: the fixed64-point transport reserve
could still produce insufficient-space Pause at large accessibility text sizes.
No other actionable P0–P3 findings in the full delta were reported. Its old
61-source/12-bundle freeze and101-test result matched. Same model as author,
independent session only; no model diversity.

The new mounted production regression at Accessibility3 and5,466/550 regular
widths and both returning chat modes reproduced the issue:16 assertions failed,
exit65. WatchPaneLayout now synchronously measures its actual primary panel at
unconstrained height. The video GeometryReader has idealHeight300 for that
measurement; it can still compress under an actual insufficient allocation.
The measured height reserves actual transport size and supported video in the
same layout pass. There is no asynchronous height feedback or auto-resume.
Focused12 layout tests pass. Final complete signed suite: **102 passed, zero
failed/skipped, runtimeWarnings empty, exit0**; signature verifies exit0.
The receiver suite now passes28 tests including direct explicit/primary private
group membership checks, not just mocking the helper. These are synthetic tests.

## First live receiver attempt and rollback

Reviewed receiver source/install/unit hashes matched the earlier frozen target.
The first owned user-unit start failed before Python with systemd218/CAPABILITIES:
“Failed to drop capabilities: Operation not permitted.” Installer exit1.
Ownership-checked rollback succeeded exit0. Full Serve configuration remained
exactly unchanged. Only the owned failed-state entry was reset; the newly created
protected empty data directory was removed with rmdir after uid/mode/resolution
and emptiness checks. No records existed or were deleted. Owned unit/source are
absent. Existing services, directories and modes are preserved.

A real transient owned systemd preflight with the same hardening properties,
minus the unsupported CapabilityBoundingSet directive, exited0. Its process
reported CapPrm=0, CapEff=0 and NoNewPrivs=1. Only that redundant directive was
removed from the staged unit. The receiver is **not operational**, and no
HTTPS route has yet been added. Evidence: build/proof/local-receiver-deployment/.
Fresh source review is pending for the accessibility correction and unit change;
then deploy, prove synthetic HTTPS204/exactreadback, current muted runtime, and
ship a new TestFlight build. Portrait outside-screen playback below400 remains
an explicitly unmet limitation, with rotation guidance instead of a bypass.
