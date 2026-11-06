# Small video and keyboard continuity — 6 November 2026

Target: main cd483937414a28ffcb6244ea42a8cc5a3511f9ab plus the complete
six-file executable delta in App/WatchView.swift, Platform/WatchArrangement.swift,
Player/PlaybackSession.swift and the three affected test suites.

Alex clarified that the visible video must shrink as small as requested and
opening the landscape keyboard must not produce “Video needs more room.” This
supersedes the earlier minimum-visible-size design and the resizable-chat review,
canceled via task_cancel. Task168ff151-a53f-49e5-9e3c-7f67833485a2 finished
interrupted without a verdict; no source pass is claimed for it.

The candidate retains the public Twitch player and one WKWebView/host. A positive
small pane now presents a uniformly scaled supported logical viewport; only its
native presentation scales, not native transport controls. The renderer remains
at least400×300; small-pane viewport aspect ratios clamp to0.25…4, bounding backing
view dimensions at1600points even for a one-point visible pane. Larger supported
panes render unscaled. Empty/nonfinite allocations are invisible, noninteractive
and still pass through the bounded350ms settling/hidden navigation pause guards.
No private media API, host-page change, stream extraction or native audio write
is introduced. Release still ignores the Debug silent-testing flag.

Split preferences now permit positive visible panes down to one point, with a
12-point divider. Automatic placement follows available aspect ratio; explicit
Below remains below, including small keyboard layouts. Side width and below-video
height persist independently. Dragging uses stable coordinates and actual clamped
chat size; menu and VoiceOver actions perform the same adjustment. Reset split
restores240-point useful chat defaults. Fold regions retain precedence over manual
placement/resize, and both content hosts retain structural identity.

Short panels move unscaled native controls to a64-point scrollable side rail
when width allows. The Viewing options menu also provides Play/Pause and Full
video, allowing access when a user deliberately makes the native panel tiny.
The video panel clips its own contents so native chrome cannot spill into chat.

Recorded red: small-video-keyboard-red.xcresult/log/exit reports the production
panel test only22/25 playable allocations, exit65. The three added sizes are
500×160,382×280 and160×120; that unchanged25-case assertion passes after scaling.
Focused small-video-keyboard-focused suite:18passed, exit0. Final actual
small-video-keyboard-delivery.xcresult and extracted summary:110passed, zero failed
or skipped, runtimeWarnings empty; log/exit0. Strict deep signature exit0.
Final rerun includes chat clipping and strict400-point floating-width rounding.
Existing AccountView compiler deprecation and platform diagnostics remain.

The production mounted resizing test checks AX3 side/below preference changes,
real WebKit logical allocations, one load/browser host, retained playing state,
transient rotation, and a persistent750×160 keyboard-sized frame for500ms. Its
converted visible WebKit rectangle fits within161points while logical dimensions
remain supported; intentional Pause survives restoration. The25panel allocations
must all load and retain synthetic playback. Viewport tests cover bounded extreme
aspect ratios, containment, zero/nonfinite inputs and unscaled normal sizes.

All playback here is synthetic, not audible live media. A reduced test frame is
not proof of an actual keyboard/IME interaction, UIKit touch mapping into scaled
WebKit, real Twitch motion, physical Duo outside/fold behavior, or accessibility
readability. Those require current silent runtime/physical evidence. Earlier
cd48393 runtime remains attributed to that candidate:160 exact automatic received
records, partial delivery, silent accepted public Play, long frame freezes and
unintended rotation pauses. Receiver and uploader are unchanged by this delta.

Frozen source62 manifest: docs/council/small-video-keyboard-source-sha256.json,
SHA256 064ee35e5af5f5135d6269d661de294b3d1c3b8da5a62eb4465516f5a3c174ae.
Exact12-file app: build/small-video-delivery-simulator/DuoTwitch.app.
Bundle manifest: build/verification/small-video-keyboard-bundle-sha256.json,
SHA256 fb4829a38bd2ffc32e0acb535dcad6f805a413fa91bb265db534b538c85d91c2.

Fresh independent source review, silent runtime and new internal TestFlight
delivery remain pending. No completed physical keyboard/outside playback claim.
