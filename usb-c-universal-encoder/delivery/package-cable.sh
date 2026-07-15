#!/usr/bin/env bash
#
# package-cable.sh — assemble the "cable image".
#
# In one sentence: it gathers everything we have written into a single portable
# folder — the exact contents you would drop onto a USB-C cable's storage — so that
# plugging the cable in gives the other machine both the data pipe and the software
# that runs it. The image carries its own one-command installer and a launcher, and
# is re-run whenever the project grows so the cable always bears the current system.
#
# Usage:  package-cable.sh [OUTPUT_DIR]
#   OUTPUT_DIR  where to write the image (default: ${DIR}/output/cable-image)
#   Override the project root by exporting DIR=/path before running.

set -euo pipefail

# ${DIR} is the project root. We derive it from this script's own location (so the
# script runs from any directory), and still allow an explicit override via the DIR
# environment variable. Every path below is relative to ${DIR}.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${DIR:-$(dirname "$HERE")}"

OUT="${1:-$DIR/output/cable-image}"

# The non-ephemeral project: what actually travels on the cable. tmp/ and output/
# are left behind on purpose — they are scratch, not software.
SHIP=(src libs docs notes issues tests assets delivery .file-index-counter)

echo "[package] project root : $DIR"
echo "[package] image output : $OUT"

# Start from a clean image so a removed source file never lingers in the bundle.
rm -rf "$OUT"
mkdir -p "$OUT"

# Copy each shippable item that exists. Missing optional items are skipped quietly;
# a truly required item missing would surface later as a failed smoke test.
for item in "${SHIP[@]}"; do
    if [ -e "$DIR/$item" ]; then
        cp -a "$DIR/$item" "$OUT/"
    fi
done

# Place the installer and launcher at the image root, where a person mounting the
# cable will see them first. These are the two entry points of the whole bundle.
cp -a "$DIR/delivery/install.sh" "$OUT/install.sh"
cp -a "$DIR/delivery/launch.sh" "$OUT/launch.sh"
chmod +x "$OUT/install.sh" "$OUT/launch.sh"

# A version stamp so an installed copy can say where it came from. Best-effort git
# hash (the project lives inside a larger repo); date is a plain build timestamp.
BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GIT_REF="$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
printf 'usb-c-universal-encoder\nbuilt: %s\ncommit: %s\n' "$BUILD_TIME" "$GIT_REF" > "$OUT/VERSION"

# A manifest of everything shipped, so the receiving side can see the payload.
( cd "$OUT" && find . -type f | sort ) > "$OUT/MANIFEST"

# A short human note at the root of the cable, in plain sight.
cat > "$OUT/README" <<'EOF'
USB-C Universal Encoder — cable image.

This folder is self-contained. To use it:
  * Run in place, no install:   ./launch.sh smoke
  * Or install with one command: ./install.sh
There is deliberately NO autorun: running code off a plugged-in device without
your say-so is the exact attack this project refuses. One command is the "easy".
EOF

BYTES="$(du -sb "$OUT" | cut -f1)"
echo "[package] wrote image: $(cat "$OUT/MANIFEST" | wc -l) files, ${BYTES} bytes"
echo "[package] done -> $OUT"
