#!/bin/sh
# Silent, non-network Foundation tests; no Simulator, playback, browser or Xcode lease.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
package=$(mktemp -d "${TMPDIR:-/tmp}/duotwitch-upload-tests.XXXXXX")
trap 'rm -rf "$package"' EXIT HUP INT TERM
mkdir -p "$package/Sources/PlaybackDiagnosticsCore" "$package/Tests/PlaybackDiagnosticsCoreTests"
for source in PlaybackDiagnosticRecord PlaybackDiagnosticTransport PlaybackDiagnosticUploader; do
    cp "$root/Player/$source.swift" "$package/Sources/PlaybackDiagnosticsCore/"
done
cp "$root/Tests/PlaybackDiagnosticUploadTests.swift" "$package/Tests/PlaybackDiagnosticsCoreTests/"
cp "$root/Tests/PlaybackDiagnosticHTTPTransportTests.swift" "$package/Tests/PlaybackDiagnosticsCoreTests/"
cat > "$package/Package.swift" <<'SWIFT'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PlaybackDiagnosticsCore", platforms: [.macOS(.v13)], targets: [
    .target(name: "PlaybackDiagnosticsCore", swiftSettings: [.unsafeFlags(["-strict-concurrency=complete"])]),
    .testTarget(name: "PlaybackDiagnosticsCoreTests", dependencies: ["PlaybackDiagnosticsCore"])
])
SWIFT
swift test --package-path "$package" --scratch-path "$package/.build"
