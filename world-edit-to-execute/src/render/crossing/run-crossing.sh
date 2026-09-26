#!/bin/bash
# run-crossing.sh - build and run the crossing-armies demo, drawn from the server (issue 804)
#
# In plain terms: builds the window program in which two armies swap sides,
# every unit routing around every other, and every drawn unit having come
# from the game's server as bytes. Without a mode it proves itself without
# anyone watching: a check on a clean connection, a check on a troubled one,
# and a picture. With "window" it opens the window to play with.
#
# Steps: the C reader of the messages is generated from their Lua
# descriptions (src/net/messages-c.lua); the program is compiled with Lua
# built in (LuaJIT), the mailbox, and raylib.
#
# Usage: run-crossing.sh [DIR] [window | window-two-radii]
#   window-two-radii: units steer round each other's larger pathing radius
#   before touching (off by default: it slowed the crossing), to compare
#   writes tmp/shared-memory/crossing/check.txt, shot.png and shot-paused.png

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
MODE="${2:-check}"
SRC="${DIR}/src/render/crossing"
BUILD="${DIR}/tmp/crossing"
OUT="${DIR}/tmp/shared-memory/crossing"
RAYLIB="/home/ritz/programming/c/libs/raylib/src"
set -e
mkdir -p "${BUILD}" "${OUT}"

luajit "${DIR}/src/net/messages-c.lua" "${DIR}" > "${BUILD}/net-messages.h"
cc -std=gnu11 -O2 -Wall -Wextra -pthread \
    -I"${BUILD}" -I"${DIR}/src/render/ceramic/mailbox" -I"${RAYLIB}" -I/usr/include/luajit-2.1 \
    "${SRC}/crossing-host.c" \
    -L"${RAYLIB}" -lraylib -lluajit-5.1 -lGL -lm -lpthread -ldl -lrt -lX11 -o "${BUILD}/crossing-host"

export CROSSING_DIR="${DIR}"
if [ "${MODE}" = "window" ]; then
    exec "${BUILD}/crossing-host"
fi
if [ "${MODE}" = "window-two-radii" ]; then
    CROSSING_TWO_RADII=1 exec "${BUILD}/crossing-host"
fi
set +e
: > "${OUT}/check.txt"
failed=0
# a clean connection, then delay, jitter and loss together
"${BUILD}/crossing-host" --check 8 | tee -a "${OUT}/check.txt"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then failed=1; fi
"${BUILD}/crossing-host" --check 8 100 60 0.2 | tee -a "${OUT}/check.txt"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then failed=1; fi
"${BUILD}/crossing-host" --shot 9 "${OUT}/shot.png" 2>&1 | grep -v '^INFO'
# the waiting dialog: the stand-in goes silent, this player's slider at 0.5 s
"${BUILD}/crossing-host" --shot 3 "${OUT}/shot-paused.png" paused 2>&1 | grep -v '^INFO'
echo "pictures: ${OUT}/shot.png, ${OUT}/shot-paused.png"
if [ "${failed}" -ne 0 ]; then echo "crossing checks FAILED"; exit 1; fi
echo "crossing checks passed"
