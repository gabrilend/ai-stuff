#!/bin/bash
# run.sh — the front door of Filesystem Tapestry.
#
# What it is (for a general): this one script both BUILDS the record of when every
# file on your data drives was born and last changed, and lets you WALK that
# record and open files. Building fans out one walker per drive so all your disks
# are read at once, then staples their notes into a single catalog. Walking hands
# that catalog to an interactive browser. Point it elsewhere by setting DIR.
#
# Usage:
#   ./run.sh                # walk (scans first only if no catalog exists yet)
#   ./run.sh --scan         # (re)build the catalog, then stop
#   ./run.sh --walk         # walk the existing catalog
#   ./run.sh --scan --walk  # rebuild, then walk
#   DIR=/somewhere ./run.sh # relocate the whole project
#   ./run.sh --dir /somewhere ...

set -u

# The one hard-coded location, overridable by the DIR environment variable or a
# --dir flag. Everything else is derived from it, so the project can be moved.
DIR="${DIR:-/home/ritz/programming/ai-stuff/filesystem-tapestry}"

DO_SCAN=false
DO_WALK=false

# -- {{{ parse_args
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --scan) DO_SCAN=true ;;
            --walk) DO_WALK=true ;;
            --dir)  shift; DIR="$1" ;;
            *) echo "unknown option: $1" >&2; exit 1 ;;
        esac
        shift
    done
}
# }}}

# -- {{{ ensure_ram_tmp
# tmp/ is a symlink into a RAM-backed directory under /tmp so shards and logs
# live in memory, not on disk. Recreate the target and the link if either is
# missing, because a reboot clears /tmp.
ensure_ram_tmp() {
    local ram="/tmp/filesystem-tapestry-tmp"
    mkdir -p "$ram"
    if [ ! -L "$DIR/tmp" ]; then
        rm -rf "$DIR/tmp"
        ln -s "$ram" "$DIR/tmp"
    fi
}
# }}}

# -- {{{ scan
# Fan out one cataloger per configured root, all at once (the drives are
# independent, so five walkers run in parallel instead of one grinding through
# them in turn), wait for every walker, then merge the shards into the catalog.
scan() {
    local roots
    roots="$(TAPESTRY_DIR="$DIR" luajit "$DIR/scripts/print-roots.lua")"
    echo "[run] scanning roots in parallel:"
    echo "$roots" | sed 's/^/         /'

    local pids=()
    while IFS= read -r root; do
        [ -z "$root" ] && continue
        if [ ! -d "$root" ]; then
            echo "[run] WARN: root not present, skipping: $root" >&2
            continue
        fi
        TAPESTRY_DIR="$DIR" luajit "$DIR/src/03-cataloger.lua" "$root" &
        pids+=("$!")
    done <<< "$roots"

    local pid
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    echo "[run] merging shards ..."
    TAPESTRY_DIR="$DIR" luajit "$DIR/scripts/merge-catalog.lua"
}
# }}}

# -- {{{ walk
walk() {
    TAPESTRY_DIR="$DIR" luajit "$DIR/src/10-main.lua"
}
# }}}

# -- {{{ main
main() {
    parse_args "$@"
    ensure_ram_tmp

    # Default behaviour: if neither flag was given, walk -- but scan first when
    # there is no catalog yet, so a first run just works.
    if ! $DO_SCAN && ! $DO_WALK; then
        if [ -f "$DIR/assets/catalog.jsonl" ]; then
            DO_WALK=true
        else
            echo "[run] no catalog yet -- scanning first."
            DO_SCAN=true
            DO_WALK=true
        fi
    fi

    $DO_SCAN && scan
    $DO_WALK && walk
}
# }}}

main "$@"
