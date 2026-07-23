#!/bin/bash
# validate.sh — the living statistics of the tapestry.
#
# What it is (for a general): instead of writing numbers into documents where
# they rot, we keep the numbers in one place you can re-run. This prints how big
# the catalog is, how many files were set aside as junk-directory noise, how many
# lost their birth date, the spread of kinds, and the oldest and newest moments
# on record. Point it elsewhere with DIR.
#
# Usage:
#   ./scripts/validate.sh --stats     # print catalog statistics
#   ./scripts/validate.sh             # same as --stats

set -u
DIR="${DIR:-/home/ritz/programming/ai-stuff/filesystem-tapestry}"
CATALOG="$DIR/assets/catalog.jsonl"

# -- {{{ require_catalog
require_catalog() {
    if [ ! -f "$CATALOG" ]; then
        echo "no catalog at $CATALOG -- run ./run.sh --scan first" >&2
        exit 1
    fi
}
# }}}

# -- {{{ stats
# Counts are read straight off the JSON-lines with wc/grep (fast on a big file),
# and the date range is found with a single awk pass. WHY awk here and not Lua:
# a pure count/min/max sweep is exactly what awk is for, and it never needs to
# hold the catalog in memory.
stats() {
    require_catalog
    local total excluded fallbacks
    total="$(wc -l < "$CATALOG")"
    excluded="$(grep -c '"excluded":true' "$CATALOG")"
    fallbacks="$(grep -c '"created_is_fallback":true' "$CATALOG")"

    echo "== filesystem tapestry: catalog statistics =="
    echo "catalog:            $CATALOG"
    echo "total files:        $total"
    echo "excluded (junk dir):$excluded   (still in the chronological record)"
    echo "birth-time missing: $fallbacks   (created date fell back to modified)"
    echo
    echo "-- by kind --"
    grep -o '"kind":"[a-z]*"' "$CATALOG" \
        | sed 's/"kind":"//; s/"//' \
        | sort | uniq -c | sort -rn \
        | awk '{ printf "  %-8s %s\n", $2, $1 }'
    echo
    echo "-- time span (modified) --"
    awk -F'"modified":' '
        { v = $2 + 0;
          if (min == "" || v < min) min = v;
          if (max == "" || v > max) max = v }
        END {
            if (min == "") { print "  (empty)"; exit }
            print "  oldest: " strftime("%Y-%m-%d %H:%M", min);
            print "  newest: " strftime("%Y-%m-%d %H:%M", max)
        }' "$CATALOG"
}
# }}}

case "${1:---stats}" in
    --stats) stats ;;
    *) echo "usage: $0 [--stats]" >&2; exit 1 ;;
esac
