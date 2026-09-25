#!/usr/bin/env bash
# balance-history.sh — make the balance history page: every stock number of Warcraft III, across every version
#
# In plain terms: reads the game's data tables from every version the
# project has built (the patch layers, discs to 1.29.2), writes down each
# number that ever changed, and puts a page beside it that draws the
# history. Everything lands in the project's RAM scratch space
# (tmp/shared-memory/balance-history/), is made from the player's own
# install, and stays on this machine.
#
# Usage:
#   scripts/balance-history.sh [DIR] [--open]
#
#   DIR      project root (default: the path below)
#   --open   open the page in Firefox afterwards
#
# Issue: issues/completed/115-balance-history-explorer.md

set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [[ $# -gt 0 && "$1" != --* ]]; then
    DIR="$1"
    shift
fi
OPEN=0
[[ "${1:-}" == "--open" ]] && OPEN=1

# The RAM tiers vanish on reboot; put them back before writing into them.
source /home/ritz/programming/ai-stuff/scripts/libs/ensure-ram-tiers
ensure_ram_tiers "$DIR" || exit 1

OUT="$DIR/tmp/shared-memory/balance-history"
luajit "$DIR/src/cli/balance-history.lua" --dir "$DIR" "$OUT"
cp "$DIR/src/viewers/balance-history.html" "$OUT/index.html"
echo "open: $OUT/index.html"
if [[ $OPEN -eq 1 ]]; then
    firefox "$OUT/index.html" >/dev/null 2>&1 &
fi
