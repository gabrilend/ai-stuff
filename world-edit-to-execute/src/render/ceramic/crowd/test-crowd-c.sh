#!/bin/bash
# test-crowd-c.sh - checks the C crowd moves every unit exactly as the Lua crowd does (issue 515k)
#
# In plain terms: the benchmark runs the crowd in C, and the Lua crowd is
# the reference. This builds the C runner, writes crossing scenes at two
# sizes, runs each on both crowds, and compares every unit's position at
# sampled ticks, digit for digit.
#
# Usage: test-crowd-c.sh [DIR]

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
SRC="${DIR}/src/render/ceramic/crowd"
BUILD="${DIR}/tmp/ceramic/crowd"
mkdir -p "${BUILD}"
set -e
cc -std=gnu11 -O2 -Wall -Wextra -o "${BUILD}/crowd-run" "${SRC}/crowd-run.c" "${SRC}/crowd.c" -lm
set +e
failed=0
# {{{ the sizes: 40 a side for 3,000 ticks (a crossing and back), 250 a side for 1,500
for pair in "40 3000" "250 1500"; do
    set -- ${pair}
    luajit "${SRC}/crowd-scene.lua" "${DIR}" "$1" > "${BUILD}/scene-$1.txt"
    luajit "${SRC}/crowd-lua-run.lua" "${DIR}" "${BUILD}/scene-$1.txt" "$2" 50 > "${BUILD}/lua-$1.txt"
    "${BUILD}/crowd-run" "${BUILD}/scene-$1.txt" "$2" 50 > "${BUILD}/c-$1.txt"
    if cmp -s "${BUILD}/lua-$1.txt" "${BUILD}/c-$1.txt"; then
        echo "pass  $1 a side, $2 ticks: every position the same"
    else
        echo "FAIL  $1 a side, $2 ticks: first difference:"
        diff "${BUILD}/lua-$1.txt" "${BUILD}/c-$1.txt" | head -4
        failed=1
    fi
done
# }}}
exit ${failed}
