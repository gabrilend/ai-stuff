#!/usr/bin/env bash
#
# run.sh — phase 2's demo: the endurance test, on the laptop twin.
# summary: the engine runs an ordinary program for as long as you let it, and proves it lost nothing
#
# General description: builds the laptop twin, then runs the endurance
# program twice — once on four cores, once on one — for the number of
# seconds given (ten by default). Each run fans values out to one chain of
# stations per core and back into a counting sink, parks and restarts the
# whole program halfway, lets one box refuse a value and then puts it back
# into service, and feeds one station unevenly so its buffer must grow.
# Each run checks its count and sum against arithmetic and says PASS or
# FAIL. The script then prints how much faster four cores were than one,
# writes the screens of both runs as pictures, and (if a desktop is
# available) opens the four-core picture.
#
# The device half of this demo — the same program on the handheld's four
# real cores, flashed and streamed over USB — waits on issues 201 and 202,
# which are written but unverified on hardware.
#
# Usage: run.sh [project-dir] [seconds]

DIR="/mnt/mtwo/programming/ai-stuff/soren-ds"
if [ -n "$1" ] && [ -d "$1" ]; then
    DIR="$1"
    shift
fi
SECONDS_TO_RUN="${1:-10}"

"${DIR}/scripts/ensure-tmp" "${DIR}" || exit 1
export SOREN_DIR="${DIR}"
OUT="${DIR}/tmp/shared-memory/demos/phase-2"
mkdir -p "${OUT}"

echo "building the twin..."
make -s -C "${DIR}/twin" VARIANT=fast DIR="${DIR}" programs || exit 1
BUILD="$(make -s -C "${DIR}/twin" VARIANT=fast DIR="${DIR}" print-build)"
PROGRAM="${BUILD}/programs/059-endurance"

echo
echo "=== four cores, ${SECONDS_TO_RUN} seconds ==="
"${PROGRAM}" --cores 4 --seconds "${SECONDS_TO_RUN}" --png "${OUT}/four-cores.png" | tee "${OUT}/four-cores.log"
four=${PIPESTATUS[0]}

echo
echo "=== one core, ${SECONDS_TO_RUN} seconds ==="
"${PROGRAM}" --cores 1 --seconds "${SECONDS_TO_RUN}" --quiet --png "${OUT}/one-core.png" | tee "${OUT}/one-core.log"
one=${PIPESTATUS[0]}

rate_four="$(sed -n 's/^runs [0-9]* at \([0-9]*\) per second.*/\1/p' "${OUT}/four-cores.log")"
rate_one="$(sed -n 's/^runs [0-9]* at \([0-9]*\) per second.*/\1/p' "${OUT}/one-core.log")"
echo
if [ -n "${rate_four}" ] && [ -n "${rate_one}" ]; then
    speedup="$(lua -e "print(string.format('%.2f', ${rate_four} / ${rate_one}))")"
    echo "four cores ran ${speedup} times as many box runs per second as one."
fi
echo "pictures: ${OUT}/four-cores.png ${OUT}/one-core.png"
echo "numbers:  ${DIR}/tmp/shared-memory/metrics/059-endurance-*.tsv"

if [ -n "${DISPLAY}${WAYLAND_DISPLAY}" ] && command -v xdg-open > /dev/null; then
    xdg-open "${OUT}/four-cores.png" > /dev/null 2>&1 &
fi

if [ "${four}" -eq 0 ] && [ "${one}" -eq 0 ]; then
    echo "PASS"
    exit 0
fi
echo "FAIL"
exit 1
