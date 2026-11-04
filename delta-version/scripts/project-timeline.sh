#!/usr/bin/env bash
# project-timeline.sh - Draws when every project in the repository was born
# and which days it was worked on.
#
# In plain terms: it runs three small programs in a row. The first reads the
# repository's history (commits and saved conversations) and writes down, for
# each project, its first day and its working days. The second paints that as
# PNG pictures, one per way of laying out the axes. The third builds an HTML
# page where the same chart can be restyled, filtered and saved by hand.
# Everything lands in assets/project-timeline/.
#
# Usage: project-timeline.sh [DIR] [--help]
#   DIR   the delta-version folder (default: the hard-coded path below)
# Issue 067.

DIR="/mnt/mtwo/programming/ai-stuff/delta-version"

# {{{ print_help
print_help() {
    sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}
# }}}

for argument in "$@"; do
    case "$argument" in
        --help|-h) print_help; exit 0 ;;
        -*) echo "project-timeline.sh: unknown option: $argument" >&2; exit 2 ;;
        *) DIR="$argument" ;;
    esac
done

set -e
ASSET_DIR="$DIR/assets/project-timeline"
mkdir -p "$ASSET_DIR"

luajit "$DIR/scripts/project-timeline-gather.lua" --dir="$DIR" --out="$ASSET_DIR/timeline.json"
# all four layouts: two placements on each axis
for x_mode in order time; do
    for y_mode in age calendar; do
        luajit "$DIR/scripts/project-timeline-png.lua" --dir="$DIR" --x="$x_mode" --y="$y_mode"
    done
done
luajit "$DIR/scripts/project-timeline-page.lua" --dir="$DIR"
