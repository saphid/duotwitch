#!/bin/sh
# Synthetic records only, temporary Mac loopback HTTP. No host/service/route changes.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/duotwitch-wire-tests.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
swiftc -parse-as-library -strict-concurrency=complete \
  "$root/Player/PlaybackDiagnosticRecord.swift" \
  "$root/Player/PlaybackDiagnosticTransport.swift" \
  "$root/Player/PlaybackDiagnosticUploader.swift" \
  "$root/services/diagnostics-receiver/DiagnosticWireFixture.swift" -o "$fixture/generate"
"$fixture/generate" > "$fixture/body.json"
DUOTWITCH_WIRE_FIXTURE="$fixture/body.json" PYTHONDONTWRITEBYTECODE=1 \
  python3 -m unittest discover -s "$root/services/diagnostics-receiver" -p 'test_*.py' -v
