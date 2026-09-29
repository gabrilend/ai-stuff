#!/bin/bash
# test-gif-viewer.sh - proves the gif viewer reads and shows gifs correctly.
#
# In general terms: first checks the viewer's gif reader on its own, against
# three independent witnesses (the gif-generator's encoder, a gif built by
# hand, and ImageMagick on the real files). Then opens the real window for a
# moment, lets it load every gif, saves a picture of each view, and closes
# it -- proof the window itself runs, not just its parts.
# Exercises the success criteria of issue 062.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

VIEWER="$DIR/delta-version/scripts/gif-viewer"
FOLDER="/home/ritz/pictures/shape-gifs"

source "$DIR/scripts/libs/ensure-ram-tiers"
ensure_ram_tiers "$DIR/delta-version" || exit 1
SCRATCH="$DIR/delta-version/tmp/shared-memory/gif-viewer-test"
mkdir -p "$SCRATCH"

echo "gif-viewer: the reader"
luajit "$VIEWER/gif-decode-test.lua" "$DIR" "$FOLDER" "$SCRATCH"
reader_status=$?

echo ""
echo "gif-viewer: the window"
# Two paths: a display to open a window on (run it), or none (say so and
# count it as a failure -- a window test that silently skips proves nothing).
if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    echo "  FAIL - no display to open the window on"
    window_status=1
else
    report=$(timeout 150 "$VIEWER/view-gifs" --selftest --screenshots="$SCRATCH" 2>&1)
    window_status=$?
    echo "  $report" | tail -1
    [ -s "$SCRATCH/single.png" ] && echo "  ok   - the single view was drawn ($SCRATCH/single.png)" || { echo "  FAIL - no single-view picture"; window_status=1; }
    [ -s "$SCRATCH/grid.png" ] && echo "  ok   - the grid was drawn ($SCRATCH/grid.png)" || { echo "  FAIL - no grid picture"; window_status=1; }
fi

[ "$reader_status" -eq 0 ] && [ "$window_status" -eq 0 ]
