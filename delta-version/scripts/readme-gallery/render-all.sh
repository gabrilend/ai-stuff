#!/bin/bash
# render-all.sh - films every gallery scene, four at a time.
#
# In general terms: each scene is an independent short film, so instead of
# making them one after another, this films four side by side -- never more
# than four processes at once, the owner's limit -- and waits for the last to
# finish. By default the films land in RAM as candidates for a person to look
# over; `--library` instead films every one of them into the owner's picture
# library, with a still of each in a stills/ folder beside them -- the
# collection the owner keeps.
#
# Usage: render-all.sh [DIR] [--library] [extra options passed to each job, e.g. --still]
#   --library   film into LIBRARY (below), stills into LIBRARY/stills
#
# To rebuild the whole library after a change:  render-all.sh --library

DIR="/mnt/mtwo/programming/ai-stuff/delta-version/scripts/readme-gallery"
LIBRARY="/home/ritz/pictures/shape-gifs"
if [ -n "${1:-}" ] && [ -d "$1" ]; then
    DIR="$1"
    shift
fi

# Two destinations: the library (every film and its still, kept), or
# whatever the options say (RAM candidates by default).
options=()
if [ "${1:-}" = "--library" ]; then
    shift
    options=(--out="$LIBRARY" --stills="$LIBRARY/stills")
fi

scene_names=$(ls "$DIR/scenes" | sed -n 's/\.lua$//p')
# At most four processes at once, whatever the machine has (the owner's
# limit, 2026-09-26: "use up to 4 threads"). Four scenes film side by side,
# each as a single process (--jobs=1, so a scene that would split its own
# frames across workers does not multiply the count).
MAX_PROCESSES=4

# -- {{{ film_each
# Hands every scene name to its own luajit process, four at a time.
function film_each() {
    printf '%s\n' $scene_names | xargs -P "$MAX_PROCESSES" -I{} luajit "$DIR/readme-gallery.lua" "$DIR" {} --jobs=1 "$@"
}
# }}}

film_each "${options[@]}" "$@"
