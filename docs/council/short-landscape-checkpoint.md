# Short landscape controls and inaudible runtime gate — 6 November 2026

Parent baseline773d89e passed102iOS tests/source recheck. Its latest Astra runtime
was paused-only: semantic official Unmute unavailable, so no Play/Resume. It
verified exact61-source/12-bundle identities, retained paused player/load on full
returns, and observed750×304 usable landscape bounds with750×240 video beneath
64-point bottom controls. AX5 video space survived, but transport text truncated.
See build/proof/fullvideo-current/REPORT.md, not a playback acceptance pass.

The exact-run receiver query (uppercase UUID) returned zero rows; a normalized
lowercase repeat also returnedzero. Aggregate readback found385records total,
including384app records and the synthetic receiver probe. The app's persisted
queue contained452entries,206from the fresh run, with failurecount0. FIFO backlog
is a supported explanation; no uploader defect is established. App automatic
transmission of older queued records is demonstrated, current-run receipt isn't.
No queue or receiver behavior was changed for this follow-up.

## Red/green and change

The mounted production panel at750×304 could not become playable. Red xcresult
short-landscape-red reports a failure/exit65 (only20 of21sizes playable). A new
custom panel layout keeps video as the same first subview and places controls in
a64-point right rail on short supported screens. No overlay covers the Twitch
surface. The pane arrangement reserves464points for video+rail before allocating
side chat, preserving the official400×300embed. Otherwise measured bottom controls
remain; insufficient actual video still reaches the existing pause/fit gate.
The production mounted regression now covers750×304full-mode returns and both
chat modes at default/AX3/AX5, plus22panel allocations including464×304. Paused
state and one load are preserved. These use stubbed playback, not live video.

Debug-only -DuoTwitchSilentPlayback makes native Play first call Twitch's public
setMuted(true) and synchronously require getMuted()===true. Missing/unconfirmed
mute refuses Play. A native Play retry may be needed while the SDK updates its
cached state. No delayed JavaScript Play, audio-session write, global output
change, hosted-page modification or iframe-private access is introduced. Release
ignores the argument. Successful gated requests emit a fixed public log line.
This replaces dependence on unavailable iframe accessibility for silent tests.

The offline Node fixture extracts the production script and exercises six cases:
unconfirmed mute, confirmed mute, missing API, ordinary Play, stale session, and
session change during public mute read. The unchanged first refusal assertion
failed before the guard (exit1); all six now pass (exit0). No network/audio starts.
The fixture's final stale-during-read case was strengthened after the red run.

Final actual short-landscape-final.xcresult:103passed,0failed/skipped,
runtimeWarningsempty,testexit0; strict signatureexit0. Existing AccountView
compiler deprecation remains. Receiver28-test evidence is unchanged; production
receiver code was not changed. New source/bundle freezes accompany this checkpoint.
Fresh source review and gated live runtime are pending before next TestFlight.
Physical Duo transitions and sub400portrait playback remain unverified/unsupported.
