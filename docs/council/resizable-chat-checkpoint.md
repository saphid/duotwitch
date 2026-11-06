# Adjustable video and chat — 6 November 2026

Historical intermediate target, superseded by Alex's arbitrary visible sizing and
keyboard-continuity clarification before review completed. The Sol/high review
task 168ff151-a53f-49e5-9e3c-7f67833485a2 was canceled and is interrupted, without
a final verdict. This checkpoint's minimum-visible-size rules are no longer the
requested behavior. See small-video-keyboard-checkpoint.md for the new target.

Target: main cd483937414a28ffcb6244ea42a8cc5a3511f9ab plus the frozen
six-file executable delta and requirement/document updates.

Alex requested adjustable chat in open landscape, chat below video in open
portrait, and the largest video by default with manual adjustment available.
The implementation keeps ArrangementView and both stable pane hosts. Automatic
placement follows the usable aspect ratio; explicit Beside/Below options are in
Viewing options. A 12-point visible divider supports direct dragging, an expanded
hit region, VoiceOver adjustable actions with the current allocated size, and
equivalent Smaller/Larger chat menu actions. Side width and stacked height persist
independently. Largest video resets both to the minimum useful chat allocation,
240 points. Requests clamp against the supported video plus measured transport;
active system divisions retain precedence and have no draggable divider. When
there is insufficient room below but a supported side split fits, it uses that.

The preceding cd48393 Astra runtime verified three silent accepted requests,
fitting short landscape, and same-player Full/chat returns. Exact current-run
receipt of 160 projected records was verified against the deployed lxso1 receiver,
including app.launch, watch.layout and native Play. This was incomplete delivery:
the bounded queue had 492 remaining entries, with nine older records evicted.
Long frame freezes prevented sustained-motion acceptance. Both rotations produced
transient undersize native pauses. See build/proof/short-landscape-current/REPORT.md.

The new mounted production regression reproduces that rotation failure with
an 80ms 340×286 intermediate frame: three assertions failed (playing, pause count
and attached browser host), exit65 in resizable-chat-rotation-red. The correction
keeps the browser host mounted at a supported size but entirely hidden and
inaccessible while undersized. It disables native Play immediately, gives the
geometry 350ms to settle before insufficient-space Pause, and invalidates stale
settling work after refit, cancellation, page replacement or leaving Watch.
No scaled/undersized Twitch surface is displayed. Persistent insufficient space
still pauses; leaving Watch still pauses immediately. No auto-resume is added.

Focused resizing/layout tests: 17 passed, exit0. Final actual xcresult
build/verification/resizable-chat-reviewed.xcresult: 109 passed, zero failed/skipped,
runtimeWarnings empty, exit0. Strict deep signature exit0. The prior full run also
passed109; final rerun covers the stale-page cleanup and accessibility refinement.
Existing AccountView deprecation and platform console noise remain. All playback
in these tests is synthetic; no audible live playback was started.

The production-mounted resizing test changes actual persisted preferences at
regular landscape1000×700 and portrait800×1100, with AX3, checking actual WebKit
allocation changes, minimum400×300, one load, retained player and playing state,
and reset allocation. Geometry tests cover defaults, explicit placement, either
side, extreme sizes, measured control height and fold precedence. Session tests
cover stale refit, blocked Play while settling, real insufficient-space Pause and
immediate leaving. These are source/test evidence, not physical Duo proof.

Source62 freeze: docs/council/resizable-chat-source-sha256.json,
SHA256 92466bfbe0c1e692d39e0573df888c29b16b35b87483e3c92ef4f5846584c2c0.
Exact12-file app: build/resizable-chat-reviewed-simulator/DuoTwitch.app;
bundle manifest build/verification/resizable-chat-bundle-sha256.json,
SHA256 3171df8f8e815f81764a9ac5e09d1dbcab8497c023055095de1f5591984f7bc4.

Fresh independent source review and silent visual/gesture runtime remain pending.
Current physical Full-video exit/rotation/outside playback, large-text readability,
complete log delivery, phone connectivity and updated TestFlight remain unproven.
Sub400-point portrait outside playback remains unsupported by the official embed.
