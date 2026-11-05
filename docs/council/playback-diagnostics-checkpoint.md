# Persistent playback diagnostics checkpoint

Alex confirms that TestFlight 0.1.0 (202611051233) still stops video before one
second in open mode. The earlier audio classification change did not resolve
that physical symptom. This delta adds observation and export; it does not
claim a cause or a physical-device fix.

## Automatic collection follow-up source

The later implementation candidate defaults to automatic, allowlisted upload to
Alex’s existing network Loki over tailnet HTTPS, while preserving export. It is
not yet a delivered build. The receiver currently returns HTTP 500
(`Ingester is shutting down`); ingestion persistence and readback are unverified.
See [automatic collection contract and remaining prerequisite](../automatic-playback-diagnostics.md).
The no-upload statements below describe the earlier delivered instrumentation
candidate, not the automatic collection source.

## Current reattachment-fix target

This section supersedes the initial frozen target below. Only the passive script
and its tests changed after review 1. A WeakMap retains a stable video ID and one
listener set, while allowing sampling/visibility observation to restart on
rediscovery or a connected media event. The detached-node fixture fails on the
initial script (exit 1) and passes on the fix (exit 0). A new hosted regression
checks sample restart and no listener/timer duplication.

- Source manifest: `playback-diagnostics-reattach-source-sha256.json`, 47 files,
  SHA256 `63297823d6deac599ecbd78e2172382a97accbd898b1c4d65acc31b528a180d7`.
- Signed candidate: `build/playback-diagnostics-reattach-simulator/DuoTwitch.app`.
- Complete 12-file manifest:
  `build/verification/playback-diagnostics-reattach-bundle-sha256.json`.
- Actual xcresult: `build/verification/playback-diagnostics-reattach.xcresult`;
  matching log, summary and exit: **83 passed**, zero failed/skipped,
  runtimeWarnings empty, command exit 0. Strict/deep signature exit 0.
- One initial attempt deferred at the live build lease with exit 75 before
  compilation. After that lease was released, the ordinary wrapper run succeeded;
  no other owner's process/lock was removed.
- Fresh Codex / GPT-6.1 Sol high independent-session recheck found no actionable
  findings or blocking objections; the accepted P2 is resolved. Same model as
  author, no model diversity. See [review 2](playback-diagnostics-review2.md).
- The initial 82-test binary passed native Account and channel Info share routes,
  local export and persistence across relaunch. Production injection yielded
  observerReady, attached and 60 paused samples, with no Play/audio started.
  Report: `build/proof/playback-diagnostics/REPORT.md`. This evidence remains
  attributed to that initial binary, not relabeled as the changed candidate.
- Host inspection cannot establish the physical iOS file-protection class.
  Actual physical Duo playback, the stop's cause and its resolution remain unknown.

## Initial frozen target

- Base: 7da5625 on main (application source previously 679bdf0).
- Source: `playback-diagnostics-source-sha256.json`, 47 files including three
  new files. Manifest SHA256:
  `569f9118d74a2f928e6841a942154cd7f1c6065ed0414d7e6aacf54578f77101`.
- Signed Simulator app: `build/playback-diagnostics-final-simulator/DuoTwitch.app`.
- Bundle manifest: `build/verification/playback-diagnostics-bundle-sha256.json`,
  all 12 regular files.
- Test result: `build/verification/playback-diagnostics-final.xcresult` and
  matching log, summary and `.exit` in that directory: 82 passed, zero
  failed/skipped, runtimeWarnings empty, actual command exit 0.
- Strict/deep signature verification: exit 0. The pre-existing
  AccountView presentation-anchor deprecation remains in the build log.

## Diagnostic contract

Play/Pause commands and command results, host events before/after state
application, video fit and geometry, window attachment, watch appearance and
leave decisions, audio classification/raw notification metadata and app scene
phase are recorded with wall-clock and monotonic subsecond timestamps. Raw
pause callbacks and deadline results share a command UUID, including late
callbacks. Bridge and app-run UUIDs separate stale pages and relaunches.

A passive production WKUserScript observes public HTML video event/timing/frame
counters on HTTPS player.twitch.tv only. An observer-ready event distinguishes
successful injection from absent video discovery. Native receipt additionally
requires that origin and the current bridge nonce. No diagnostic message can
change playback state. Dynamic video discovery uses initial enumeration,
loadstart capture and pageshow; unusual insertion without those events remains
a discovery limit until runtime observation. Sampling is every 250 ms near
video events and every 2.5 seconds after ten seconds without a video event.

Disk work is serialized off the main actor. Four rolling 256 KiB JSONL files
survive relaunch, are protected until first device authentication, and are
excluded from backup. One bounded export copy is retained. The export queue
includes preceding appends and the export event; write failure is surfaced
rather than silently exporting an incomplete success. No network upload exists.

Only fixed native event/error classifications, numeric state/counters,
booleans, public OS/build metadata and ephemeral diagnostic UUIDs are saved.
Credentials, account/channel identity, chat, full errors, URLs, port names,
port UIDs and raw WebKit payloads are excluded. The WebKit boundary whitelists
kinds and typed finite bounded fields; unknown fields are discarded.

User path: channel Info -> Playback diagnostics -> Share playback logs;
alternatively Account -> Playback diagnostics. This uses the native share
sheet. The person reproducing must share the file; there is no automatic
collection service.

## Checks and limits

Eight new tests cover ordered persisted records across recorder recreation,
bounded chronological rotation, surfaced write failure, origin/nonce/type
filtering and state neutrality, app-vs-provider pause trace, timeout/late
callback correlation, and executing the real passive script against a
JavaScriptCore fixture (progress, pause, detachment, dynamic video, wrong
origin and no media commands).

No physical playback has been reproduced by the author. The synthetic tests
use stubbed audio/media commands and cannot establish the physical stop's
cause or its resolution. Live injected media observation and the native share
journey still require bounded runtime verification. Runtime work must not
start playback without fresh official mute verification; no global Mac audio
changes, authentication changes, chat sends or sign-out are in scope.
