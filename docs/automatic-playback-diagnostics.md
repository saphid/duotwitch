# Automatic playback diagnostics

The next source build attempts automatic upload by default to
`https://lxso1.tail4e5636.ts.net/duotwitch-diagnostics`, without a Share action,
configuration screen, bundled secret or analytics SDK. This is Alex’s private
DuoTwitch JSON record receiver: validated JSON lines are stored in SQLite on
owned local-network storage. It is **not Loki or PostHog**.

**Deployment is staged, not operationally verified.** No lxso1 service has been
installed/started and no Serve handler changed by this implementation. Parent
review, deployment, synthetic HTTPS 204 and exact SSH readback are prerequisites
for claiming collection works. The already distributed 0.1.0 (202611052312)
client still targets lxso2’s unavailable Loki. Its volume was 98.8% full, above
Loki’s 90% WAL threshold; the final synthetic push/readback failed. That
installation, route and ingester remain untouched. PostHog’s scoped access
returned 401, so this implementation uses owned storage instead.

The phone needs an approved Tailscale connection and any permissions iOS
requests. There is no prompt bypass, ATS exception or third-party fallback.
Offline upload records remain bounded; the independent local export works as
before. Automatic default does not guarantee continuous execution while iOS
suspends or terminates the app.

## Ownership and storage

Source lives in this repository at `services/diagnostics-receiver/`, owned by
[personal-ops #208](https://github.com/saphid/personal-ops/issues/208). A fresh
issue read confirmed that owner. The available `pa-memory` query and the parent’s
prior-work receipt were incomplete lookup evidence, not proof of absence. Fresh
lxso1 listener/unit/service-source checks identified Codex’s file-based usage
collector, an agent-session proxy, and a disabled Kindle-specific SLOP collector;
none is a generic ingest receiver with this privacy boundary. The streaming
archive and media hub own different datasets and are not reused.

The staged canonical host layout follows lxso1’s existing service/data split:

- Source: `/home/saphid/services/duotwitch-diagnostics/receiver.py`.
- State: `/home/saphid/pa-agent-data/duotwitch-diagnostics/records.sqlite3`.
- User unit: `/home/saphid/.config/systemd/user/duotwitch-diagnostics.service`.
- Loopback: `127.0.0.1:18792`, unused in the fresh inventory. The installer
  rechecks it rather than stopping anything to free it.

The host had 32,071,262,208 free bytes (about 29.9 GiB); user lingering was already
enabled. No changes to lingering, other workloads, lxso2, accounts or purchases
are part of this implementation. Private lookup/inventory and verification
receipts live under ignored `build/verification/local-diagnostics-receiver/`.

## Privacy boundary and limits

The unchanged Swift upload projection and the independent receiver both allow
only fixed events, booleans, finite bounded numbers, fixed text classifications,
public numeric version/build/OS strings, and ephemeral run/session/command/
appearance UUIDs. The receiver rejects unknown fields/types/strings, invalid
UUIDs, duplicate JSON keys, mismatched labels/timestamps and arbitrary lines.
The Python suite compares event/key/enum lists with the Swift source to catch
drift. No credentials, account/channel identity, device/installation identifier,
chat, media URLs, freeform errors or private attachments/app data are accepted.

HTTP headers, source IPs, peer identity and raw request bodies are never stored
or logged by the receiver. Tailscale necessarily handles network metadata;
existing daemon behavior is outside this receiver. No public query, metrics or
HTTP health endpoint exists. Native `systemctl --user is-active` is a liveness
probe; acceptance plus SSH readback is the ingestion health test.

The receiver accepts only POST at the exact `/duotwitch-diagnostics` path, with
`application/json`, a single positive Content-Length, and no transfer/content
encoding. A batch may have at most 32 records, 24 KiB of record JSON and a
64 KiB body; each record is at most 4096 UTF-8 bytes. It retains the existing
Loki-shaped wire envelope solely for client compatibility. Wrong methods,
paths, query strings, schemas and framing fail closed. Headers are bounded to
8 KiB, the listen backlog to eight, concurrent handlers to four, and each
connection to a five-second absolute deadline, including slow trickle reads.
A global token bucket permits 120 connections/minute with a burst of 20; it
stores no per-peer rate-limit identities. Overload returns 429 when possible.

The SQLite directory is 0700 and files are 0600. It uses DELETE journaling,
secure deletion and synchronous EXTRA commits (fsync plus directory sync),
never a growing WAL. HTTP 204 is emitted only after the transaction’s durable
commit. Retry identity is `(run UUID, sequence)` with matching stable timestamp
and canonical JSON line. An identical retry is accepted without duplication or
extending retention; conflicting reuse returns 409 and rolls back the batch.
A crash or lost response can cause a retry but cannot overwrite an accepted
record. Deduplication lasts within bounded retention, not forever.

Records expire 24 hours after first acceptance, with maintenance at startup,
every accepted batch, and at most 60-second idle intervals. Maximums are 10,000
records, 128 distinct runs and 4 MiB of canonical JSON payload. Older batches
are evicted for record/payload capacity; the incoming batch is never evicted
before its acknowledgement. Run overflow returns 429. SQLite has an 8 MiB page
cap; its temporary rollback journal can approximately double this, leaving
total normal state below 32 MiB. A 1 GiB filesystem headroom floor rejects writes
with 503. Full disks, SQLite/commit/retention failures also reject with 503;
these conditions can delay deletion until storage recovers. Data is never
silently acknowledged on a storage failure. The systemd unit bounds memory,
CPU, tasks and file descriptors, disables core dumps/output, and restricts
filesystem writes to this service’s data directory.

## Client queue and local export

Local export remains four rolling 256 KiB JSONL files plus one bounded export
copy. Upload acknowledgement, failure, expiry or eviction cannot delete them;
pre-update local logs are not retrospectively uploaded. The separate persistent
upload queue retains at most 512 records and 512 KiB of encoded record payload
for 24 hours. Its atomic spool also holds validation metadata and a second
representation; loading rejects files larger than 2 MiB. It revalidates restored
entries and works on a serial utility queue. iOS files are protected until first
authentication and excluded from backup.

Uploads remain single-flight, no more often than once per 30 seconds. New
samples do not postpone an existing scheduled send. Network errors, 408, 429
and 5xx retry with persisted exponential backoff, bounded jitter and numeric
Retry-After (up to an hour). After eight reserved attempts, or a permanent
rejection, that batch is dropped. A retry never extends the queue’s TTL.
Only exact HTTP 204 counts as success. The same serialized line and timestamp
are reused after retry/relaunch. The ephemeral URLSession has 15-second request
and 20-second resource deadlines, platform TLS validation, no cookies,
credentials, redirect following, response-body collection or external fallback.
There is no new background mode, playback command or audio ownership.

The app footer names this default destination. Its existing local-network
purpose string remains accurate. The parent must reconcile App Store privacy
disclosures before any external release.

## Verification and parent handoff

Run with the explicit Xcode toolchain (no device, Simulator, GUI or build lease):

```sh
DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer /bin/sh scripts/test-diagnostic-upload.sh
DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer /bin/sh scripts/test-diagnostic-receiver.sh
```

The first runs the existing 15 Foundation XCTest cases with an intercept-all
URLProtocol/fake transport. The second compiles the actual Swift projection,
queue and transport types with a synthetic fixture generator, then sends that
actual wire body to an isolated temporary Mac loopback receiver. Python tests
cover exact SQL readback, duplicate/conflict atomicity, SIGKILL/restart durability,
malformed requests, schema/type/batch limits, slow connections, concurrency/rate
limits, retention (including idle maintenance), headroom/page exhaustion and
failed writes/deletion. No tests contact the tailnet endpoint or private app data.

The parent owns fresh independent source review, full signed integration tests,
production deployment using the following runbook, synthetic HTTPS acceptance
and SSH readback, phone network/permission checks, and any beta delivery.
Implementation itself makes no operational collection claim.

## Deployment after parent review only

Read `~/AGENTS.md` on lxso1 before host work. Copy only the reviewed
`services/diagnostics-receiver/` files to a protected temporary staging directory
there. Do not run from this Mac with a remote wrapper. On lxso1 as `saphid`, run:

```sh
python3 /path/to/reviewed-staging/install.py install
systemctl --user is-active duotwitch-diagnostics.service
```

The installer refuses existing unowned service/data paths, an occupied port,
source drift or a different installed release. It checks the effective systemd
fragment and all unit search paths, including exact, prefix and type-wide
drop-ins. Ancestor directories must remain real, owned directories without
group/world write access. These checks repeat before enable/disable, so rollback
refuses externally changed service behavior. Repeating the same installation
is safe. Partial installs fail closed and need ownership inspection; do not
remove unknown paths to retry. It installs/enables only this user unit; lingering
is already enabled. The source, ownership manifest and data are protected. It
never invokes Tailscale. If the host denies a unit hardening feature, stop and
review that exact limitation rather than relaxing unrelated settings.

Capture **fresh** Serve JSON immediately before adding the handler. The saved
implementation inventory is evidence, not a deploy-time comparison baseline:

```sh
tailscale serve status --json > serve-before.json
python3 /path/to/reviewed-staging/serve_config.py preflight serve-before.json
tailscale serve --bg --https=443 --set-path=/duotwitch-diagnostics http://127.0.0.1:18792/duotwitch-diagnostics
tailscale serve status --json > serve-after.json
python3 /path/to/reviewed-staging/serve_config.py added serve-before.json serve-after.json
```

The guard rejects public Funnel on 443 and compares the **entire** configuration:
443 root, all existing handlers, other TCP listeners and `AllowFunnel` must be
identical except the one expected diagnostics handler. Existing Funnel on 8443
must remain as it was. Do not enable Funnel, replace the root, run global
`serve off`, or reset Serve. The backend target includes the exact path so
Tailscale’s prefix forwarding resolves to the receiver’s narrow POST path.

Send a synthetic, allowlisted record with a new UUID to the HTTPS endpoint.
Require exact 204 and verify its full `(run, sequence, timestamp, line)` through
SSH with Python’s `sqlite3` module in read-only mode. Retry the identical body
and require one row. Do not use lxso1’s sqlite CLI shim or query over HTTP.
For example, run locally on lxso1 with the synthetic run ID:

```sh
python3 - SYNTHETIC-RUN-UUID <<'PY'
import json, sqlite3, sys
from contextlib import closing
with closing(sqlite3.connect('file:/home/saphid/pa-agent-data/duotwitch-diagnostics/records.sqlite3?mode=ro', uri=True)) as db:
    rows = db.execute('SELECT run,sequence,timestamp,line FROM records WHERE run=? ORDER BY sequence', (sys.argv[1].lower(),)).fetchall()
    print(json.dumps(rows))
PY
```

Keep sanitized actual exit/status/readback receipts. A native active service,
local loopback success or a 200 login page alone does not verify HTTPS collection.

## Rollback

On lxso1, save current Serve state, remove **only** this exact handler, then
compare it with the saved current state using the guard:

```sh
tailscale serve status --json > serve-rollback-before.json
python3 /path/to/reviewed-staging/serve_config.py preflight serve-rollback-before.json
tailscale serve --https=443 --set-path=/duotwitch-diagnostics off
tailscale serve status --json > serve-rollback-after.json
python3 /path/to/reviewed-staging/serve_config.py removed serve-rollback-before.json serve-rollback-after.json
python3 /path/to/reviewed-staging/install.py rollback
```

First verify the current diagnostics target matches this service; the guard
refuses an unrelated target. The installer verifies its ownership hashes before
stopping/disabling/removing its own unit and source. It retains protected data
for SSH readback, never recursively deletes, and does not touch other units or
routes. Repeating rollback is safe. Reinstallation after rollback requires an
explicit ownership decision for the retained data directory; it is not silently
adopted. A failed Serve comparison requires stopping and inspecting drift, not
resetting or replaying an old whole configuration. The previous lxso2 route is
not part of either deployment or rollback. Reverting the source destination
requires a new app build; clients without an lxso1 receiver simply use their
existing bounded queue/retry and local export.
