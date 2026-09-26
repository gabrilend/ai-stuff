#!/bin/bash
# run-host.sh - build the ceramic host loop, check it, and take its picture (issues 515b, 515c)
#
# In plain terms: builds the first renderer program whose frame is worked
# out by the ceramic engine and drawn with raylib, then proves it two ways
# nobody has to watch: a check that every unit the engine placed is where
# the same arithmetic puts it directly, taken through the mailbox the draw
# thread reads while the engine races to fill it, and a picture of the
# drawn frame.
# With "window" it opens the window instead, to watch it run.
#
# Steps: the lane's value type is written as named fields and spliced into
# the box file; the map is written; serac emits the map's C; the emitted
# main is cut off and the host's appended; it is compiled against the kept
# engine copy (src/render/ceramic/engine) with the mailbox
# (src/render/ceramic/mailbox) and linked with raylib.
#
# Usage: run-host.sh [DIR] [window]
#   writes tmp/shared-memory/ceramic/host-check.txt and host-shot.png

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
MODE="${2:-check}"
SORAMECH="/home/ritz/programming/ai-playground/minimal-soramech"
SRC="${DIR}/src/render/ceramic/host"
FORK="${DIR}/src/render/ceramic/engine"
MAILBOX="${DIR}/src/render/ceramic/mailbox"
BUILD="${DIR}/tmp/ceramic/host"
OUT="${DIR}/tmp/shared-memory/ceramic"
SERAC="${DIR}/tmp/ceramic/serac"
RAYLIB="/home/ritz/programming/c/libs/raylib/src"
set -e
mkdir -p "${BUILD}" "${OUT}"

if [ ! -x "${SERAC}" ]; then
    bash "${SORAMECH}/scripts/147-build-serac.sh" "${SORAMECH}" -o "${SERAC}" > /dev/null
fi

# the box file, with the lane's answer type spliced in; the map
types=$(luajit "${SRC}/units-types.lua")
awk -v t="${types}" '{ if ($0 == "/* @@UNITS-TYPES@@ */") print t; else print }' \
    "${SRC}/units-boxes.c" > "${BUILD}/units-boxes.c"
luajit "${SRC}/units-gen.lua" > "${BUILD}/units.map"

# the program: construction code, the host's main, the engine copy, raylib
"${SERAC}" --emit-c "${BUILD}/units.map"
mv "${BUILD}/units.c" "${BUILD}/units.emitted.c"
cut_at=$(grep -n '^int main(int argc, char \*\*argv)' "${BUILD}/units.emitted.c" | cut -d: -f1)
if [ -z "${cut_at}" ]; then
    echo "the emitted program has no main to replace" >&2
    exit 1
fi
head -n $((cut_at - 1)) "${BUILD}/units.emitted.c" > "${BUILD}/units-host.c"
cat "${SRC}/units-host.c" >> "${BUILD}/units-host.c"
cc -std=gnu11 -O2 -pthread -ffunction-sections -fdata-sections \
    -Wl,--export-dynamic-symbol='cera_*' -Wl,--gc-sections \
    -I"${FORK}" -I"${MAILBOX}" -I"${BUILD}" -I"${RAYLIB}" "${BUILD}/units-host.c" "${FORK}/cera.c" \
    -L"${RAYLIB}" -lraylib -lGL -lm -lpthread -ldl -lrt -lX11 -o "${BUILD}/units-host"

if [ "${MODE}" = "window" ]; then
    exec "${BUILD}/units-host"
fi
# the check (no window) and the picture (a hidden window)
"${BUILD}/units-host" --check 600 | tee "${OUT}/host-check.txt"
"${BUILD}/units-host" --shot 240 "${OUT}/host-shot.png"
echo "picture: ${OUT}/host-shot.png"
