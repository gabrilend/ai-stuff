#!/bin/bash
# run-crowd-gifs.sh - makes the crowd page's GIFs (issue 515k)
#
# In plain terms: the moving pictures for the crowd report. One GIF per
# army size shows the crossing from above (the crowd the benchmark timed);
# one GIF replays four ticks of every threading design side by side as the
# 2,000-unit armies meet, each thread's work drawn as bars. Frames are
# drawn by crowd-film.c and timeline-film.c with raylib, then joined by
# ffmpeg with a palette made for them. Run it after run-crowd.sh (it reads
# its timelines), and not during it (it would disturb the timings).
#
# Usage: run-crowd-gifs.sh [DIR]
#   writes tmp/shared-memory/ceramic/crowd/crowd-N.gif and timelines.gif

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
SRC="${DIR}/src/render/ceramic/crowd"
BUILD="${DIR}/tmp/ceramic/crowd"
OUT="${DIR}/tmp/shared-memory/ceramic/crowd"
RAYLIB="/home/ritz/programming/c/libs/raylib/src"
LIBS="-L${RAYLIB} -lraylib -lGL -lm -lpthread -ldl -lrt -lX11"
set -e
mkdir -p "${BUILD}" "${OUT}"
cc -std=gnu11 -O2 -pthread -I"${RAYLIB}" -I"${SRC}" "${SRC}/crowd-film.c" "${SRC}/crowd.c" ${LIBS} -o "${BUILD}/crowd-film"
cc -std=gnu11 -O2 -I"${RAYLIB}" "${SRC}/timeline-film.c" ${LIBS} -o "${BUILD}/timeline-film"

# {{{ to_gif FRAMES_DIR FPS OUT.gif: frames to a GIF with its own palette
to_gif() {
    ffmpeg -loglevel error -y -framerate "$2" -i "$1/frame-%04d.png" \
        -vf "split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" "$3"
}
# }}}

# the crossing, from above: every 6th tick, 10 frames a second (0.6 s of
# game a second of GIF), long enough for the armies to meet and pass
declare -A TICKS=([250]=2000 [1000]=3600 [2500]=6000)
declare -A WIDTH=([250]=560 [1000]=640 [2500]=720)
for n in 250 1000 2500; do
    rm -rf "${BUILD}/film-${n}"; mkdir -p "${BUILD}/film-${n}"
    "${BUILD}/crowd-film" "${BUILD}/scene-${n}.txt" "${TICKS[$n]}" 30 "${WIDTH[$n]}" "${BUILD}/film-${n}"
    to_gif "${BUILD}/film-${n}" 12 "${OUT}/crowd-$((n * 2)).gif"
done

# the designs' threads, side by side
rm -rf "${BUILD}/film-timelines"; mkdir -p "${BUILD}/film-timelines"
"${BUILD}/timeline-film" 90 900 "${BUILD}/film-timelines" \
    "slices (fixed shares)=${OUT}/timeline-slices-hybrid.tsv" \
    "counter (self-balancing)=${OUT}/timeline-counter-hybrid.tsv" \
    "job system=${OUT}/timeline-jobs.tsv" \
    "ceramic graph=${OUT}/timeline-ceramic.tsv"
to_gif "${BUILD}/film-timelines" 15 "${OUT}/timelines.gif"
ls -la "${OUT}"/*.gif
