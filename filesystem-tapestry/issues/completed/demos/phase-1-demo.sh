#!/bin/bash
# phase-1-demo.sh — "The Thread" demonstrated.
#
# What it shows (for a general): that we can take a real drive, write down when
# every file was born and last touched, and then walk that record through time
# and open any file in the right program. It leans on the statistics: how many
# files, of what kinds, spanning what years, and how often a file's birth date on
# THIS drive disagrees with its much older content date -- the clearest sign that
# capturing both dates was worth it.
#
# Runs read-only against whatever catalog already exists; if none does, it builds
# a small sample from one directory so the demo is quick. Override the sample
# with an argument, or DIR to relocate the project.

set -u
DIR="${DIR:-/home/ritz/programming/ai-stuff/filesystem-tapestry}"
SAMPLE_ROOT="${1:-/mnt/cmdo/ritz/my-recorded-videos}"
export TAPESTRY_DIR="$DIR"

# -- {{{ rule
rule() { printf '\n\033[36m== %s ==\033[0m\n' "$1"; }
# }}}

# -- {{{ ensure_catalog
# Use the existing catalog if present; otherwise scan a single sample directory
# (fast) so the demo always has something to show without walking every drive.
ensure_catalog() {
    if [ -f "$DIR/assets/catalog.jsonl" ]; then
        echo "using existing catalog."
        return
    fi
    echo "no catalog yet -- building a sample from: $SAMPLE_ROOT"
    mkdir -p "/tmp/filesystem-tapestry-tmp"
    [ -L "$DIR/tmp" ] || ln -s "/tmp/filesystem-tapestry-tmp" "$DIR/tmp"
    luajit "$DIR/src/03-cataloger.lua" "$SAMPLE_ROOT"
    luajit "$DIR/scripts/merge-catalog.lua"
}
# }}}

# -- {{{ demo_stats
demo_stats() {
    rule "1. The statistics of the thread"
    "$DIR/scripts/validate.sh" --stats
}
# }}}

# -- {{{ demo_walk
# Drive the navigator non-interactively to prove the walk: show a file, step
# forward, show a window, flip to the birth-date sort, reverse the direction, and
# ask for the two meaning-walks (which announce their Phase-2 fallback).
demo_walk() {
    rule "2. Walking the thread (scripted, no windows opened)"
    printf '%s\n' where next next list created reverse similar different quit \
        | luajit "$DIR/src/10-main.lua"
}
# }}}

# -- {{{ demo_divergence
# The headline datapoint: files whose creation date on THIS drive is much later
# than their content's modified date -- old things copied here recently. This is
# why the tapestry records both dates, not one. The work is done by a named
# script so this demo just presents it.
demo_divergence() {
    rule "3. Where 'created here' disagrees with 'last modified'"
    echo "(files copied onto the drive long after their content was written)"
    luajit "$DIR/scripts/find-divergence.lua" 5
}
# }}}

# -- {{{ main
main() {
    echo "FILESYSTEM TAPESTRY -- PHASE 1 DEMO: The Thread"
    ensure_catalog
    demo_stats
    demo_divergence
    demo_walk
    rule "done"
    echo "Phase 2 (similar/different by policy meaning) is scaffolded; the two"
    echo "meaning-walks above announced their fallback to chronological order."
}
# }}}

main
