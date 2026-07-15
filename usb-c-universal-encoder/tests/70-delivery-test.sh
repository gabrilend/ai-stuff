#!/usr/bin/env bash
#
# 70-delivery-test.sh — end-to-end proof that the cable delivers working software.
#
# It packages the project into a cable image, installs that image into a scratch
# location, and then runs the delivered launcher from there — asserting the smoke
# test passes and the goodbye is written. In short: it simulates "plug it in, run
# one command, it works", with nothing touching the real system.
#
# Run:  tests/70-delivery-test.sh

set -euo pipefail

# ${DIR} is the project root (tests/ sits directly under it). Self-derived so this
# runs from anywhere; override with DIR= if needed.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${DIR:-$(dirname "$HERE")}"

# All scratch lives under the RAM-backed tmp/ so the test leaves no disk residue.
WORK="$DIR/tmp/delivery-test"
rm -rf "$WORK"
mkdir -p "$WORK"
OUT="$WORK/cable-image"
TARGET="$WORK/installed"
BIN="$WORK/bin"

echo "delivery-test:"

echo "  [1/4] package the cable image"
"$DIR/delivery/package-cable.sh" "$OUT"
[ -f "$OUT/install.sh" ]           || { echo "  FAIL: image has no install.sh"; exit 1; }
[ -f "$OUT/launch.sh" ]            || { echo "  FAIL: image has no launch.sh"; exit 1; }
[ -f "$OUT/src/00-ram-arena.lua" ] || { echo "  FAIL: image payload missing src"; exit 1; }
echo "  ok - image contains installer, launcher, and payload"

echo "  [2/4] install the image into a scratch location"
"$OUT/install.sh" --yes --target "$TARGET" --bindir "$BIN"
[ -x "$BIN/usb-c-encoder" ]  || { echo "  FAIL: launcher not created"; exit 1; }
[ -f "$TARGET/launch.sh" ]   || { echo "  FAIL: bundle not installed"; exit 1; }
echo "  ok - launcher on PATH and bundle installed"

echo "  [3/4] run the delivered software via the launcher"
RESULT="$("$BIN/usb-c-encoder" smoke)"
echo "$RESULT" | sed 's/^/      | /'
case "$RESULT" in
    *"checks passed"*) echo "  ok - delivered smoke test passed" ;;
    *) echo "  FAIL: delivered software did not pass its smoke test"; exit 1 ;;
esac

echo "  [4/4] house-style goodbye was written"
[ -f "$TARGET/output/goodbye" ] || { echo "  FAIL: no goodbye written"; exit 1; }
echo "  ok - goodbye recorded"

echo "delivery-test: PASS"
