#!/bin/sh
# Record a GIF demo of Just Text piping its buffer through a shell command.
# Launches the app with an unsorted list, then drives  ⇧⌘| → "sort" → Run
# while screen-recording, and crops/encodes the result to a GIF.
#
# Requires: ffmpeg (brew install ffmpeg). Needs Screen Recording AND
# Accessibility permission for the terminal running this script.
#
# Usage: sh demo.sh [output.gif]
set -e

cd "$(dirname "$0")"

APP="Just Text.app"
BIN="$APP/Contents/MacOS/JustText"
OUT="${1:-demo.gif}"
WIDTH=900   # output GIF width in px; height keeps aspect ratio

command -v ffmpeg >/dev/null || { echo "ffmpeg not found (brew install ffmpeg)" >&2; exit 1; }
[ -x "$BIN" ] || sh build.sh

TMP="$(mktemp -d)"
trap 'kill "$APP_PID" "$FF_PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT

# Helper: print "windowID x y width height scale" for a given PID.
cat > "$TMP/win.swift" <<'SWIFT'
import CoreGraphics
import AppKit
let pid = Int(CommandLine.arguments[1]) ?? -1
guard let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { exit(1) }
for w in infos {
    guard let p = w[kCGWindowOwnerPID as String] as? Int, p == pid,
          let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
          let b = w[kCGWindowBounds as String] as? [String: Any],
          let num = w[kCGWindowNumber as String] as? Int else { continue }
    let x = b["X"] as! Double, y = b["Y"] as! Double
    let wd = b["Width"] as! Double, ht = b["Height"] as! Double
    let scale = NSScreen.main?.backingScaleFactor ?? 2.0
    print("\(num) \(Int(x)) \(Int(y)) \(Int(wd)) \(Int(ht)) \(scale)")
    exit(0)
}
exit(1)
SWIFT
swiftc -O "$TMP/win.swift" -o "$TMP/win"

# Find ffmpeg's avfoundation index for the main display ("Capture screen 0").
SCREEN_IDX="$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
    | sed -n 's/.*\[\([0-9]*\)\] Capture screen 0/\1/p' | head -1)"
[ -n "$SCREEN_IDX" ] || { echo "No screen capture device found." >&2; exit 1; }

# Launch the app, seeded with an unsorted list.
printf '%s' 'banana
apple
cherry
date
blueberry
apricot' | "$BIN" &
APP_PID=$!

# Wait for the window and read its geometry.
GEO=""
for _ in $(seq 1 50); do
    GEO="$("$TMP/win" "$APP_PID" 2>/dev/null || true)"
    [ -n "$GEO" ] && break
    sleep 0.1
done
[ -n "$GEO" ] || { echo "Timed out waiting for the window." >&2; exit 1; }
set -- $GEO
X=$2; Y=$3; W=$4; H=$5; S=$6

# Crop rect in capture (pixel) space.
CROP="$(awk -v x="$X" -v y="$Y" -v w="$W" -v h="$H" -v s="$S" \
    'BEGIN{printf "crop=%d:%d:%d:%d", w*s, h*s, x*s, y*s}')"

# Record the main display; stop later with SIGINT to finalize the file.
ffmpeg -y -f avfoundation -capture_cursor 0 -framerate 30 -i "$SCREEN_IDX" \
    "$TMP/rec.mov" >"$TMP/ff.log" 2>&1 &
FF_PID=$!

sleep 2  # warm up ffmpeg + show the initial buffer

# Drive the demo: open the pipe prompt, type "sort", run it.
osascript <<OSA
tell application "System Events"
    set frontmost of (first process whose unix id is $APP_PID) to true
    delay 0.4
    keystroke "|" using {command down, shift down}
    delay 0.9
    keystroke "sort"
    delay 1.0
    key code 36
end tell
OSA

sleep 2.2  # let the sorted result sit on screen

kill -INT "$FF_PID" 2>/dev/null || true
wait "$FF_PID" 2>/dev/null || true

# Encode to GIF: crop to the window, scale down, two-pass palette for quality.
VF="$CROP,fps=15,scale=$WIDTH:-1:flags=lanczos"
ffmpeg -y -i "$TMP/rec.mov" -vf "$VF,palettegen=stats_mode=diff" "$TMP/pal.png" >>"$TMP/ff.log" 2>&1
ffmpeg -y -i "$TMP/rec.mov" -i "$TMP/pal.png" \
    -lavfi "$VF [v]; [v][1:v] paletteuse=dither=bayer:bayer_scale=3" \
    "$OUT" >>"$TMP/ff.log" 2>&1

echo "Saved $OUT"
