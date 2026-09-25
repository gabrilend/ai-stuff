#!/bin/bash
# run-copy-cost.sh - build and run the ceramic copy-cost benchmark (issue 515a)
#
# In plain terms: the same "pose every unit's skeleton" work is timed four
# ways -- one thread, a hand-written parallel loop, and the ceramic engine
# with one task per unit or one per 64 units -- at three army sizes, and the
# results land in a small report: the time per frame each way, and what the
# engine costs over the hand-written loop. All four must compute identical
# poses (a checksum per way), or the report says so and the run fails.
#
# Builds serac from the soramech sources into this project's RAM tier (that
# repository is only read), and everything else lands there too.
#
# Usage: run-copy-cost.sh [DIR] [FRAMES]

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
FRAMES="${2:-200}"
SORAMECH="/home/ritz/programming/ai-playground/minimal-soramech"
SRC="${DIR}/src/render/ceramic/bench"
BUILD="${DIR}/tmp/ceramic/bench"
REPORT_DIR="${DIR}/tmp/shared-memory/ceramic"
SERAC="${DIR}/tmp/ceramic/serac"
set -e

mkdir -p "${BUILD}" "${REPORT_DIR}"

# serac, once: it carries the engine inside it
if [ ! -x "${SERAC}" ]; then
    bash "${SORAMECH}/scripts/147-build-serac.sh" "${SORAMECH}" -o "${SERAC}" > /dev/null
fi

# the box file with its value types spliced in (the engine's value types
# can't hold number arrays, so they're written as named fields by a tool)
types=$(luajit "${SRC}/pose-types.lua")
awk -v t="${types}" '{ if ($0 == "/* @@POSE-TYPES@@ */") print t; else print }' \
    "${SRC}/pose-boxes.c" > "${BUILD}/pose-boxes.c"
cp "${SRC}/per-unit.map" "${SRC}/per-chunk.map" "${BUILD}/"

# The engine's own two files, written out by serac (the same bytes it
# carries inside itself).
mkdir -p "${BUILD}/engine"
"${SERAC}" --unpack "${BUILD}/engine" > /dev/null

# Each ceramic way: serac --emit-c writes the map's construction code and an
# emitted main beside the map (as <map name>.c). The emitted main is cut off
# at its first line and our host's main put in its place, then compiled with
# the engine, using serac's own flags plus -lm. (serac's documentation names
# a --main option that serac doesn't have, and it can't add linker flags;
# both are findings for soramech in issue 515a.)
for way in per-unit per-chunk; do
    "${SERAC}" --emit-c "${BUILD}/${way}.map"
    mv "${BUILD}/${way}.c" "${BUILD}/${way}.emitted.c"
    cut_at=$(grep -n '^int main(int argc, char \*\*argv)' "${BUILD}/${way}.emitted.c" | cut -d: -f1)
    if [ -z "${cut_at}" ]; then
        echo "the emitted program for ${way} has no main to replace" >&2
        exit 1
    fi
    head -n $((cut_at - 1)) "${BUILD}/${way}.emitted.c" > "${BUILD}/${way}.c"
    cat "${SRC}/ceramic-host.c" >> "${BUILD}/${way}.c"
    cc -std=gnu11 -O2 -pthread -ffunction-sections -fdata-sections \
        -Wl,--export-dynamic-symbol='cera_*' -Wl,--gc-sections \
        -I"${BUILD}/engine" "${BUILD}/${way}.c" "${BUILD}/engine/cera.c" -o "${BUILD}/${way}" -lm
done
# compiled from a copy beside the spliced box file: an #include in quotes
# looks beside the including file first, and the source folder's box file
# has no types in it yet
cp "${SRC}/plain.c" "${BUILD}/plain.c"
cc -std=gnu11 -O2 -pthread "${BUILD}/plain.c" -o "${BUILD}/plain" -lm

results="${REPORT_DIR}/copy-cost.tsv"
: > "${results}"
for units in 128 512 2048; do
    "${BUILD}/plain" plain "${units}" "${FRAMES}" >> "${results}"
    "${BUILD}/plain" parallel "${units}" "${FRAMES}" >> "${results}"
    "${BUILD}/per-unit" "${units}" "${FRAMES}" >> "${results}"
    "${BUILD}/per-chunk" "${units}" "${FRAMES}" >> "${results}"
done

# the report: a table per size, and whether every way agreed
luajit - "${results}" "${REPORT_DIR}/copy-cost.md" <<'LUA'
local results, out = arg[1], arg[2]
local rows, sizes, order = {}, {}, {}
for line in io.lines(results) do
    local way, units, frames, threads, mean, best, check = line:match("^(%S+)\t(%d+)\t(%d+)\t(%d+)\t([%d.]+)\t([%d.]+)\t(%x+)$")
    assert(way, "unreadable result line: " .. line)
    units = tonumber(units)
    if not rows[units] then rows[units] = {}; order[#order + 1] = units end
    rows[units][way] = { threads = threads, mean = tonumber(mean), best = tonumber(best), check = check, frames = frames }
end
local ways = { "plain-loop", "parallel-loop", "ceramic-per-unit", "ceramic-per-chunk" }
local lines, agree = {}, true
local function w(s) lines[#lines + 1] = s end
w("# Ceramic copy-cost benchmark (issue 515a)")
w("")
w("Posing every unit's 30-bone skeleton (1920 bytes of matrices per unit), per frame. Times in microseconds;")
w("a 60 fps frame is 16667. Overhead is the ceramic way's mean over the hand-written parallel loop.")
for _, units in ipairs(order) do
    local r = rows[units]
    w("")
    w(string.format("## %d units", units))
    w("")
    w("| Way | Threads | Mean | Best | Over the parallel loop | Share of a frame | Checksum |")
    w("|-----|---------|------|------|------------------------|------------------|----------|")
    local base = r["parallel-loop"].mean
    for _, way in ipairs(ways) do
        local x = r[way]
        local over = way:match("^ceramic") and string.format("%+.1f", x.mean - base) or ""
        w(string.format("| %s | %s | %.1f | %.1f | %s | %.2f%% | %s |", way, x.threads, x.mean, x.best, over, 100 * x.mean / 16667, x.check))
        if x.check ~= r["plain-loop"].check then agree = false end
    end
end
w("")
w(agree and "All four ways computed identical poses (checksums agree)." or "**The checksums disagree: some way computed different poses.**")
local f = assert(io.open(out, "w"))
f:write(table.concat(lines, "\n"), "\n")
f:close()
print(table.concat(lines, "\n"))
if not agree then os.exit(1) end
LUA
