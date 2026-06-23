#!/bin/sh
# Launch Just Text with sample content and capture a clean window screenshot.
# Produces a transparent-background, drop-shadowed PNG suitable for a tutorial.
#
# Usage:
#   sh screenshot.sh [output.png]          # use built-in sample text
#   sh screenshot.sh output.png < file     # seed the buffer from a file/pipe
set -e

cd "$(dirname "$0")"

APP="Just Text.app"
BIN="$APP/Contents/MacOS/JustText"
OUT="${1:-screenshot.png}"

# Build on demand so the script works from a fresh checkout.
[ -x "$BIN" ] || sh build.sh

# Seed the buffer: piped/redirected stdin if present, otherwise a friendly sample.
if [ -p /dev/stdin ] || [ -f /dev/stdin ]; then
    SAMPLE="$(cat)"
else
    SAMPLE='Just Text — a scratch editor that pipes through the shell.

Type freely, then press  ⇧⌘|  and run any command:

    sort | uniq -c
    jq .
    tr a-z A-Z

The buffer is sent to the command on stdin and replaced with its output.'
fi

# Tiny helper: find the window id for a given PID (no screen-recording perm needed).
HELPER="$(mktemp -d)/windowid"
cat > "$HELPER.swift" <<'SWIFT'
import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1]) ?? -1
guard let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { exit(1) }
for w in infos {
    if let p = w[kCGWindowOwnerPID as String] as? Int, p == pid,
       let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
       let num = w[kCGWindowNumber as String] as? Int {
        print(num); exit(0)
    }
}
exit(1)
SWIFT
swiftc -O "$HELPER.swift" -o "$HELPER"

# Launch the app in the background, seeding the buffer via stdin.
printf '%s' "$SAMPLE" | "$BIN" &
APP_PID=$!

cleanup() { kill "$APP_PID" 2>/dev/null || true; }
trap cleanup EXIT

# Wait for the window to appear, then settle so SwiftUI finishes its first paint.
WIN=""
for _ in $(seq 1 50); do
    WIN="$("$HELPER" "$APP_PID" 2>/dev/null || true)"
    [ -n "$WIN" ] && break
    sleep 0.1
done
[ -n "$WIN" ] || { echo "Timed out waiting for the window." >&2; exit 1; }
sleep 0.4

# -l: capture just this window (rounded corners + shadow, transparent background).
screencapture -l "$WIN" "$OUT"

echo "Saved $OUT"
