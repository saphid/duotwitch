# Small-video review fixes — 6 November 2026

Parent base remains cd483937414a28ffcb6244ea42a8cc5a3511f9ab. This is the full
six-file executable candidate plus two fixes from the fresh source review, not a
new playback architecture. See small-video-keyboard-checkpoint.md and the saved
small-video-keyboard-review1-sol.md for the preceding target and findings.

Review1 completed personally on Codex/gpt-6.1-sol/high with one P2 and one P3.
Both were accepted and reproduced. small-video-review-red.xcresult/log/exit65 has
two failing tests and12 assertion failures: a one-point chat allocation expanded
to117points wide/about189points high and overlapped/exceeded its pane; default
Slim and regular geometry were identical. The new regression bodies pass after
the fixes; the harness now uses the same production bounds wrapper.

P2 fix: WatchPaneBounds is a GeometryReader-sized wrapper with a fixed child frame,
clipping and a rectangular content hit region. WatchView wraps chat with it and
observes the wrapper size, not the child's intrinsic minimum size. The NativeChat
view/composer remain in the same structural slot. A mounted layout harness using
this production wrapper verifies one-point allocations on both sides and below,
actual wrapper bounds, containment and absence of video overlap. This is not pixel
or touch/VoiceOver runtime proof. Existing composer draft/selection/focus tests
remain part of the full suite.

P3 fix: regular and Slim modes use separate saved width/height preferences.
Defaults are240and160 respectively; Reset split resets the current mode only.
Both remain freely resizable down to positive tiny panes. Geometry defaults now
depend on the mode when no explicit size is supplied. The distinct-mode regression
checks both side and stacked placements. The production WatchView AX3 resizing
test additionally switches to Slim, checks its larger video allocation, changes
its saved size and returns to the unchanged saved regular split while retaining
playing state, the same browser and one load.

Final actual build/verification/small-video-review-fixed.xcresult and summary:
112passed, zero failed/skipped, runtimeWarnings empty. Matching log and exit file
record0; strict deep codesign verification exits0. Existing AccountView compiler
deprecation/platform console noise remain. All test playback is synthetic and
inaudible. The source/build contain no new audio writes, private media API, hosted
page edit, uploader change or receiver change.

Source62 manifest: docs/council/small-video-review-fixed-source-sha256.json,
SHA256 1101b392fe90fc8de2bbc7baf0b8838d8054569ae548ab48897dd1ef1f0ebfbe.
Exact12-file candidate: build/small-video-review-fixed-simulator/DuoTwitch.app.
Bundle manifest: build/verification/small-video-review-fixed-bundle-sha256.json,
SHA256 28d072bdabb4c8576fae0260052435b05e1622bd25b97794de98e6cc0c1e0e6e.

Fresh independent Codex/Sol/high recheck completed with no actionable P0–P3
findings; see small-video-keyboard-review2-sol.md. Silent current runtime remains
pending. No inherited source score or model diversity is claimed. Actual drag behavior,
keyboard/IME, scaled WebKit touch/VoiceOver, sustained live motion, physical Duo
outside/fold continuity and new TestFlight remain unverified. Earlier remote160
record receipt is evidence for cd48393 only, not complete diagnostic delivery.
