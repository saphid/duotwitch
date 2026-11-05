# Automatic playback diagnostics

This source candidate enables automatic diagnostic upload by default, without a
Share action, configuration screen or bundled secret. It has **not** been shipped
in TestFlight. Build 0.1.0 (202611052215) remains the local/export-only build.

## Destination and current blocker

The configured client endpoint is
`https://lxso2.tail4e5636.ts.net/duotwitch-diagnostics`. It is HTTPS within Alex’s
Tailscale network, not Mac loopback, a foreground development server, PostHog or
a public Internet receiver. The physical phone needs an approved Tailscale
connection and any permissions iOS requests. There is no prompt bypass, ATS
exception or third-party fallback.

This uses the existing network-observability Loki container on `lxso2`, owned by
`/home/saphid/services/network-observability/docker-compose.yml`, exposed locally
on port 3100. A single additive Tailscale Serve handler maps the exact ingest
prefix to `http://127.0.0.1:3100/loki/api/v1/push`. All pre-existing Serve settings,
including Funnel settings, were compared before/after and remained identical.
The handler runs under Tailscale’s existing daemon and survives shell exit. No
receiver service, account or analytics project was created, and Loki was not
restarted or reconfigured.

**The endpoint is not usable for collection yet.** HTTPS reaches Loki, but a
synthetic, non-private push returned HTTP 500 with the fixed classification
`Ingester is shutting down`. Its `/ready` response alone misleadingly reports
ready. Ingestion persistence and readback have **not** been verified. Repairing
the existing network Loki ingester and then obtaining a synthetic 204 plus exact
readback is the remaining service prerequisite. A second Loki on port 3105
belongs to a separate T3 performance stack and was deliberately not used.

Evidence is in `build/verification/automatic-diagnostics/`: endpoint receipt,
Serve before/after snapshots, deployment log/exit, test log/exit and iOS build
log/exit/result bundle. These private local artifacts are ignored by Git.

## Privacy and ownership evidence

The prior-work lookup found other apps’ PostHog integrations but no suitable
DuoTwitch project; this partial result does not prove no other receiver exists.
Portfolio validation passed; its current capability catalogue has no generic
playback-diagnostic ingest route. The canonical network-infra repository and
service-map documentation identify owned LGTM on `lxso2`; live container labels,
HTTPS and the push response refreshed that evidence. The existing owning work
remains [personal-ops #208](https://github.com/saphid/personal-ops/issues/208).
GitHub issue readback was rate-limited during this work; the issue identity comes
from `DELIVERY.md`, not a claim of a fresh issue read.

Only fixed native event names, finite bounded numeric state/counters, booleans,
public version/build/OS numbers, fixed error/audio classifications and ephemeral
run/session/command/appearance UUIDs may be uploaded. The uploader applies a
second typed allowlist and revalidates restored spool entries. Unknown event
names, keys, string values, types, corrupt spool content and full errors cannot
pass it. Account/channel identity, chat, credentials, device/installation IDs,
port names/UIDs, media URLs, and raw WebKit data are excluded. The receiver sees
normal network source metadata and the diagnostic event timestamps.

The upload client sends only to this owned endpoint with platform TLS validation.
It has no SDK, cookies, credential storage, authentication UI, redirect following,
response-body collection or third-party fallback. Tailnet membership is the
access boundary; no admin/API key is bundled. The app’s diagnostic footer names
the destination and default upload behavior. The standard local-network purpose
string describes this use if iOS requests permission. Before any new external
release, the parent must reconcile the store privacy disclosure for this change.

## Queue, bandwidth and lifecycle

- Local export remains four rolling 256 KiB JSONL files plus one bounded export
  copy. Upload acknowledgement, failure, expiry or eviction cannot delete them.
  Existing pre-update logs are not retrospectively uploaded.
- The independent upload queue retains at most 512 records and 512 KiB of encoded
  record payload, for at most 24 hours. The atomic spool also stores validation
  metadata and a second representation of the record, so its file can exceed
  512 KiB; loading rejects any file larger than 2 MiB. Disk/network work runs on a
  serial utility queue. Files use protection until first authentication on iOS
  and are excluded from backup. Oldest records are evicted on overflow.
- Each batch has at most 32 records, 24 KiB of record JSON and a 64 KiB HTTP body.
  Uploads are single-flight, no more often than once per 30 seconds. The initial
  window collects a batch; new samples do not postpone an already scheduled send.
  High event rates or prolonged outages can lose upload records; local export is
  independent and bounded too.
- Retryable failures are network errors, 408, 429 and 5xx. The delay starts at
  60 seconds, doubles to an hour, and has bounded jitter; numeric Retry-After is
  respected up to an hour. The attempt count and next eligible time are saved
  before sending. Relaunch cannot reset the budget. After eight reserved attempts,
  or on a permanent HTTP rejection, that batch is dropped from the upload queue.
  A successful upload requires Loki’s exact HTTP 204, not an arbitrary 2xx page.
- Retries retain the same serialized line and timestamp. Fixed app/component
  labels plus the ephemeral app-run label separate concurrently used apps and
  allow Loki to deduplicate identical timestamp/line retries. There is no
  persistent person or device identifier. A lost acknowledgement remains
  best-effort delivery rather than an exactly-once guarantee.
- The ephemeral HTTP session has 15-second request and 20-second resource
  deadlines. Response bodies and redirects are rejected. There is no busy loop,
  background-audio ownership, playback command or new background execution mode.
  iOS may suspend execution; queued data is retried when app execution resumes or
  on a later launch, within its bounds. Continuous collection while the app is
  suspended/terminated is not promised.

## Verification and integration

Run `DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer /bin/sh
scripts/test-diagnostic-upload.sh` from the repository. It copies the actual
Foundation-only sources into an isolated temporary Swift package and runs XCTest,
with a fake transport or an intercept-all URLProtocol. It cannot fall through to
the network. It starts no audio, browser, device or Simulator and takes no Xcode
build lease. Real command exits and test counts are required; Swift Testing’s
separate zero-test footer is not the XCTest result.

The final-source checks passed 15 XCTest cases with zero failures and
actual exit 0. The generic iOS Debug build also exited 0 through the Xcode hygiene
wrapper’s non-T3 lease, with private DerivedData removed and lease released. It
was unsigned and did not run iOS tests. The existing AccountView deprecation and
AppIntents metadata warning remain. No GUI, Play/audio, private physical trace,
phone installation, beta delivery or announcement was used for verification.

Parent integration should apply the worker commit into the parent-owned branch,
run the existing/full iOS tests alongside these focused tests, and obtain the
fresh source-shipping review. Any new native event classifications added by the
parent need explicit additions to `PlaybackDiagnosticUploadProjection`; unknown
names fail closed. The parent also owns the receiver repair/readback decision,
physical-phone network/permission verification through its Astra/device route,
and any separately authorized TestFlight delivery. No merge/cherry-pick into the
parent branch was performed by this worker.

For route rollback, remove only the handler this task added:
`tailscale serve --https=443 --set-path=/duotwitch-diagnostics off` on `lxso2`.
Do not run a root-level `serve off` or reset, which would affect unrelated routes.
Compare the resulting settings to the saved `serve-before.json`.
