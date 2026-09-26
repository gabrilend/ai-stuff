#!/bin/bash
# run-frame.sh - the fabricated frame, three ways (issue 515h)
#
# In plain terms: builds and times a made-up but realistic game frame --
# uneven stages that depend on each other, pathfinding requests of wildly
# different lengths, and decoding work in the background -- run on one
# thread, run by hand-written threads stage by stage (two ways), and run as
# a ceramic map where each stage starts the moment its inputs are ready.
# All ways run the same functions on the same plan and must agree on every
# frame's checksum. It also counts how much threading code each way needed.
#
# Steps: measure how many rounds of work make a microsecond here (so every
# program does the same work), build the box file and the map, build the
# ceramic program on the kept engine copy (issue 515g) and the hand-written
# one, run each way with and without background work, and count the lines
# marked as threading code.
#
# The ceramic graph also runs "after" (issue 515i): its frame stations in a
# destination every worker serves before the default, where background
# decoding stays. Each parallel way runs sleeping and spinning (threads that sleep between
# stages wake on cores the power governor has slowed; see frame-hand.c),
# with and without background work, REPEATS times, since runs this short
# wander. frame-bounds works out the floor: the frame's longest chain of
# dependent work, and its total work spread over every core.
#
# Usage: run-frame.sh [DIR] [FRAMES] [REPEATS]
#   writes tmp/shared-memory/ceramic/frame.tsv, frame-loc.tsv, frame-bounds.tsv,
#   frame-tuning.tsv

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
FRAMES="${2:-300}"
REPEATS="${3:-3}"
SORAMECH="/home/ritz/programming/ai-playground/minimal-soramech"
SRC="${DIR}/src/render/ceramic/frame"
BENCH="${DIR}/src/render/ceramic/bench"
FORK="${DIR}/src/render/ceramic/engine"
BUILD="${DIR}/tmp/ceramic/frame"
OUT="${DIR}/tmp/shared-memory/ceramic"
SERAC="${DIR}/tmp/ceramic/serac"
set -e
mkdir -p "${BUILD}" "${OUT}"

if [ ! -x "${SERAC}" ]; then
    bash "${SORAMECH}/scripts/147-build-serac.sh" "${SORAMECH}" -o "${SERAC}" > /dev/null
fi

# how many rounds of work make a microsecond on this machine
cc -std=gnu11 -O2 -I"${SRC}" "${SRC}/calibrate.c" -o "${BUILD}/calibrate"
ROUNDS=$("${BUILD}/calibrate")
echo "rounds per microsecond: ${ROUNDS}"

# the box file: the pose math (types spliced) followed by the frame's boxes
types=$(luajit "${BENCH}/pose-types.lua")
awk -v t="${types}" '{ if ($0 == "/* @@POSE-TYPES@@ */") print t; else print }' \
    "${BENCH}/pose-boxes.c" > "${BUILD}/frame-boxes.c"
cat "${SRC}/frame-boxes.c" >> "${BUILD}/frame-boxes.c"
cp "${SRC}/frame-plan.h" "${BUILD}/"
luajit "${SRC}/frame-gen.lua" > "${BUILD}/frame.map"

# the ceramic program: the map's construction code with its emitted main
# cut off, the host's main in its place, and the kept engine copy
"${SERAC}" --emit-c "${BUILD}/frame.map"
mv "${BUILD}/frame.c" "${BUILD}/frame.emitted.c"
cut_at=$(grep -n '^int main(int argc, char \*\*argv)' "${BUILD}/frame.emitted.c" | cut -d: -f1)
if [ -z "${cut_at}" ]; then
    echo "the emitted frame program has no main to replace" >&2
    exit 1
fi
head -n $((cut_at - 1)) "${BUILD}/frame.emitted.c" > "${BUILD}/frame-ceramic.c"
cat "${SRC}/frame-host.c" >> "${BUILD}/frame-ceramic.c"
cc -std=gnu11 -O2 -pthread -DROUNDS_PER_US="${ROUNDS}" -ffunction-sections -fdata-sections \
    -Wl,--export-dynamic-symbol='cera_*' -Wl,--gc-sections \
    -I"${FORK}" -I"${BUILD}" "${BUILD}/frame-ceramic.c" "${FORK}/cera.c" -o "${BUILD}/frame-ceramic" -lm

# the hand-written program, compiled beside the combined box file
cp "${SRC}/frame-hand.c" "${BUILD}/frame-hand.c"
cc -std=gnu11 -O2 -pthread -DROUNDS_PER_US="${ROUNDS}" "${BUILD}/frame-hand.c" -o "${BUILD}/frame-hand" -lm

# the floor, from the plan
cp "${SRC}/frame-bounds.c" "${BUILD}/frame-bounds.c"
cc -std=gnu11 -O2 -DROUNDS_PER_US="${ROUNDS}" "${BUILD}/frame-bounds.c" -o "${BUILD}/frame-bounds" -lm
"${BUILD}/frame-bounds" "${FRAMES}" "$(nproc)" > "${OUT}/frame-bounds.tsv"

W=$(( $(nproc) - 1 ))

# The stronger opponents (issue 515j) are given their best setting, not a
# guess: each spin-then-sleep way is tried at several spin lengths, the
# fastest mean wins, and the trial is kept (frame-tuning.tsv).
TUNE="${OUT}/frame-tuning.tsv"
: > "${TUNE}"
declare -A BEST_SPIN
for way in jobs systems-hybrid levels-hybrid; do
    best=""; best_mean=""
    for us in 50 200 1000 5000; do
        mean=$(FRAME_SPIN_US="${us}" "${BUILD}/frame-hand" "${way}" 150 $(( W + 1 )) 0 | cut -f5)
        printf '%s\t%s\t%s\n' "${way}" "${us}" "${mean}" >> "${TUNE}"
        if [ -z "${best_mean}" ] || awk -v a="${mean}" -v b="${best_mean}" 'BEGIN { exit !(a < b) }'; then
            best="${us}"; best_mean="${mean}"
        fi
    done
    BEST_SPIN["${way}"]="${best}"
    echo "${way}: best spin ${best} us (${best_mean} us a frame)"
done

T="${OUT}/frame.tsv"
: > "${T}"
"${BUILD}/frame-hand" serial "${FRAMES}" 1 0 >> "${T}"
for repeat in $(seq "${REPEATS}"); do
    for bg in 0 1; do
        for way in systems systems-spin levels levels-spin; do
            "${BUILD}/frame-hand" "${way}" "${FRAMES}" $(( W + 1 )) "${bg}" >> "${T}"
        done
        # the stronger opponents, each at its best spin
        for way in jobs systems-hybrid levels-hybrid; do
            FRAME_SPIN_US="${BEST_SPIN[${way}]}" "${BUILD}/frame-hand" "${way}" "${FRAMES}" $(( W + 1 )) "${bg}" >> "${T}"
        done
        "${BUILD}/frame-ceramic" "${FRAMES}" "${W}" "${bg}" >> "${T}"
        CERAMIC_SPIN=10000 "${BUILD}/frame-ceramic" "${FRAMES}" "${W}" "${bg}" >> "${T}"
        # after: the frame's stations in their own destination (issue 515i)
        FRAME_DESTINATIONS=1 "${BUILD}/frame-ceramic" "${FRAMES}" "${W}" "${bg}" >> "${T}"
        # and with only one worker serving the background
        FRAME_DESTINATIONS=2 "${BUILD}/frame-ceramic" "${FRAMES}" "${W}" "${bg}" >> "${T}"
    done
done
printf 'rounds\t%s\n' "${ROUNDS}" >> "${T}"

# threading code: the lines between THREADING markers in each program,
# and every line of the map that isn't blank or a comment
L="${OUT}/frame-loc.tsv"
count_marked() { awk '/THREADING \{/ { on = 1; next } /\} THREADING/ { on = 0 } on && NF' "$1" | wc -l; }
printf 'hand-written\t%s\n' "$(count_marked "${SRC}/frame-hand.c")" > "${L}"
printf 'ceramic host\t%s\n' "$(count_marked "${SRC}/frame-host.c")" >> "${L}"
printf 'ceramic map\t%s\n' "$(grep -cvE '^[[:space:]]*(#|$)' "${BUILD}/frame.map")" >> "${L}"
echo "done: ${T}"
