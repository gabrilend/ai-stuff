#!/usr/bin/env bash
#
# run.sh — phase 3's demo: a program written down, on the laptop twin.
# summary: a map file becomes a running program, and the program becomes a map file again
#
# General description: builds the laptop twin (which first runs the box
# generator over src/boxes/), then plays nine scenes: the greeting map
# loaded, run, and written back out identically; a misspelled box, the
# four disagreements between the ends of a wire, a wire joining two
# widths, and a map with one of every mistake — each refused, with every
# problem named in one list; a counter built from an arrow that points
# backwards; every way a station can choose an exit, with its measured
# distribution; one map placed twice inside another; and a box taking
# itself out of service and coming back when its input is restored. Each
# scene is measured first and told afterwards. The two screens are written
# as a picture; the developer's line (what the device would stream over
# USB) is kept as a log.
#
# The device half — the same maps compiled into the kernel image and read
# on the handheld — waits on phase 2's device issues (201, 202).
#
# Usage: run.sh [project-dir]

DIR="/mnt/mtwo/programming/ai-stuff/soren-ds"
if [ -n "$1" ] && [ -d "$1" ]; then
    DIR="$1"
fi

"${DIR}/scripts/ensure-tmp" "${DIR}" || exit 1
export SOREN_DIR="${DIR}"
OUT="${DIR}/tmp/shared-memory/demos/phase-3"
mkdir -p "${OUT}"

echo "building the twin (the box generator runs first)..."
make -s -C "${DIR}/twin" VARIANT=debug DIR="${DIR}" all || exit 1
BUILD="$(make -s -C "${DIR}/twin" VARIANT=debug DIR="${DIR}" print-build)"

echo
echo "the boxes the generator found:"
make -s -C "${DIR}/twin" DIR="${DIR}" describe-boxes | sed -n 's/^box  /  /p'
echo

"${BUILD}/programs/076-written-down" --png "${OUT}/written-down.png"
result=$?

echo
echo "picture: ${OUT}/written-down.png"
echo "the developer's line: ${OUT}/developer-line.log"
if [ -n "${DISPLAY}${WAYLAND_DISPLAY}" ] && command -v xdg-open > /dev/null; then
    xdg-open "${OUT}/written-down.png" > /dev/null 2>&1 &
fi
exit "${result}"
