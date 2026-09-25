#!/bin/bash
# run-analysis.sh - the ceramic engine's performance analysis (issue 515a)
#
# In plain terms: times the ceramic engine doing a renderer's per-frame work
# (posing skeletons) in many shapes, beside a hand-written thread loop doing
# the same work, and writes every measurement to one table:
#   anatomy  what one task costs, taken apart: an empty task, the work with
#            a 4-byte answer, the work with its 2 KB answer
#   size     what a task's answer costs by size (16 bytes to 120 KB)
#   chunk    how many units one task should cover (1 to 256)
#   scale    how the time falls as workers are added (1 to 11)
#   army     how the time grows with the number of units (128 to 8192)
#   herd     the same program with one change to a scratch copy of the
#            engine: each task handed in wakes one sleeping worker instead of
#            all of them (an experiment; the soramech repository is untouched)
# Every frame is timed, so each row carries percentiles and the worst frame
# too: steadiness matters to a renderer as much as the average.
#
# Nothing here writes into the soramech repository: serac is built from it
# into this project's RAM tier. The landing wait works around a fault in the
# engine (see analysis-host.c and issue 515a).
#
# Usage: run-analysis.sh [DIR] [FRAMES] [SWEEPS]
#   writes tmp/shared-memory/ceramic/analysis.tsv
#   SWEEPS: which sweeps, space-separated (default all). Running them all
#   starts the table afresh; running some replaces only their rows.

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
FRAMES="${2:-300}"
SWEEPS="${3:-anatomy size chunk scale army herd}"
SORAMECH="/home/ritz/programming/ai-playground/minimal-soramech"
SRC="${DIR}/src/render/ceramic/bench"
BUILD="${DIR}/tmp/ceramic/analysis"
OUT="${DIR}/tmp/shared-memory/ceramic"
SERAC="${DIR}/tmp/ceramic/serac"
set -e
mkdir -p "${BUILD}" "${OUT}"

if [ ! -x "${SERAC}" ]; then
    bash "${SORAMECH}/scripts/147-build-serac.sh" "${SORAMECH}" -o "${SERAC}" > /dev/null
fi
mkdir -p "${BUILD}/engine"
"${SERAC}" --unpack "${BUILD}/engine" > /dev/null

# The box file: pose-boxes.c with its value types spliced in, then the
# analysis's variants appended; the map placing one station per variant.
types=$(luajit "${SRC}/pose-types.lua")
awk -v t="${types}" '{ if ($0 == "/* @@POSE-TYPES@@ */") print t; else print }' \
    "${SRC}/pose-boxes.c" > "${BUILD}/analysis-boxes.c"
luajit "${SRC}/analysis-gen.lua" boxes >> "${BUILD}/analysis-boxes.c"
luajit "${SRC}/analysis-gen.lua" map > "${BUILD}/analysis.map"

# The program: the map's construction code with its emitted main cut off,
# then the analysis host with its variant table spliced in, and the engine.
"${SERAC}" --emit-c "${BUILD}/analysis.map"
mv "${BUILD}/analysis.c" "${BUILD}/analysis.emitted.c"
cut_at=$(grep -n '^int main(int argc, char \*\*argv)' "${BUILD}/analysis.emitted.c" | cut -d: -f1)
if [ -z "${cut_at}" ]; then
    echo "the emitted program has no main to replace" >&2
    exit 1
fi
head -n $((cut_at - 1)) "${BUILD}/analysis.emitted.c" > "${BUILD}/analysis.c"
table=$(luajit "${SRC}/analysis-gen.lua" table)
awk -v t="${table}" '{ if ($0 == "/* @@VARIANT-TABLE@@ */") print t; else print }' \
    "${SRC}/analysis-host.c" >> "${BUILD}/analysis.c"
cc -std=gnu11 -O2 -pthread -ffunction-sections -fdata-sections \
    -Wl,--export-dynamic-symbol='cera_*' -Wl,--gc-sections \
    -I"${BUILD}/engine" "${BUILD}/analysis.c" "${BUILD}/engine/cera.c" -o "${BUILD}/analysis" -lm

# The plain loops, compiled beside the spliced box file (see run-copy-cost.sh)
awk -v t="${types}" '{ if ($0 == "/* @@POSE-TYPES@@ */") print t; else print }' \
    "${SRC}/pose-boxes.c" > "${BUILD}/pose-boxes.c"
cp "${SRC}/plain.c" "${BUILD}/plain.c"
cc -std=gnu11 -O2 -pthread "${BUILD}/plain.c" -o "${BUILD}/plain" -lm

# The herd experiment's engine: the scratch copy, with the one line in the
# queue's push that wakes every sleeping worker changed to wake one.
mkdir -p "${BUILD}/herd"
push_at=$(grep -n '^void cera_pool_push' "${BUILD}/engine/cera.c" | cut -d: -f1)
wake_at=$(awk -v s="${push_at}" 'NR > s && /pthread_cond_broadcast\(&p->wake\);/ { print NR; exit }' "${BUILD}/engine/cera.c")
if [ -z "${push_at}" ] || [ -z "${wake_at}" ]; then
    echo "the engine's queue push, or its wake-everyone line, wasn't found" >&2
    exit 1
fi
sed "${wake_at}s|pthread_cond_broadcast(&p->wake);|pthread_cond_signal(\&p->wake);   /* experiment: wake one */|" \
    "${BUILD}/engine/cera.c" > "${BUILD}/herd/cera.c"
cc -std=gnu11 -O2 -pthread -ffunction-sections -fdata-sections \
    -Wl,--export-dynamic-symbol='cera_*' -Wl,--gc-sections \
    -I"${BUILD}/engine" "${BUILD}/analysis.c" "${BUILD}/herd/cera.c" -o "${BUILD}/analysis-wake-one" -lm

A="${BUILD}/analysis"
A1="${BUILD}/analysis-wake-one"
P="${BUILD}/plain"
W=$(( $(nproc) - 1 ))
T="${OUT}/analysis.tsv"
# all sweeps: a fresh table; some: keep the other sweeps' rows
if [ "${SWEEPS}" = "anatomy size chunk scale army herd" ] || [ ! -f "${T}" ]; then
    : > "${T}"
else
    for s in ${SWEEPS}; do
        # a sweep and its tagged variants (herd, herd-wake-one)
        grep -v -E "^${s}(-[a-z-]+)?"$'\t' "${T}" > "${T}.keep" || true
        mv "${T}.keep" "${T}"
    done
fi
# {{{ wanted SWEEP : whether this run includes the sweep
wanted() { case " ${SWEEPS} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
# }}}
# {{{ run SWEEP COMMAND... : one measurement, tagged with its sweep
run() {
    local sweep="$1"; shift
    local line
    line=$("$@")
    printf '%s\t%s\n' "${sweep}" "${line}" >> "${T}"
}
# }}}

if wanted anatomy; then
    echo "anatomy"
    for v in noop pose_fold pose_unit pose_chunk_64 pose_chunk; do run anatomy "${A}" "${v}" 2048 "${FRAMES}" "${W}"; done
    run anatomy "${P}" plain 2048 "${FRAMES}"
    run anatomy "${P}" parallel 2048 "${FRAMES}"
fi

if wanted size; then
    echo "size"
    for n in 16 256 2048 16384 122880; do run size "${A}" "make_blob_${n}" 256 "${FRAMES}" "${W}"; done
    run size "${A}" noop 256 "${FRAMES}" "${W}"
fi

if wanted chunk; then
    echo "chunk"
    for k in 1 2 4 8 16 32 64 128 256; do run chunk "${A}" "pose_chunk_${k}" 2048 "${FRAMES}" "${W}"; done
    run chunk "${P}" parallel 2048 "${FRAMES}"
fi

if wanted scale; then
    echo "scale"
    for w in 1 2 3 4 6 8 11; do
        run scale "${A}" pose_chunk_32 2048 "${FRAMES}" "${w}"
        run scale "${A}" pose_fold 2048 "${FRAMES}" "${w}"
        run scale "${P}" parallel 2048 "${FRAMES}" $(( w == 11 ? 12 : w ))
    done
    run scale "${P}" plain 2048 "${FRAMES}"
fi

if wanted army; then
    echo "army"
    for u in 128 512 2048 8192; do
        run army "${P}" plain "${u}" "${FRAMES}"
        run army "${P}" parallel "${u}" "${FRAMES}"
        run army "${A}" pose_fold "${u}" "${FRAMES}" "${W}"
        run army "${A}" pose_chunk_32 "${u}" "${FRAMES}" "${W}"
    done
fi

if wanted herd; then
    echo "herd"
    for v in noop pose_fold pose_unit pose_chunk_16; do
        run herd "${A}" "${v}" 2048 "${FRAMES}" "${W}"
        run herd-wake-one "${A1}" "${v}" 2048 "${FRAMES}" "${W}"
    done
    for w in 1 2 4 8 11; do
        run herd "${A}" pose_fold 2048 "${FRAMES}" "${w}"
        run herd-wake-one "${A1}" pose_fold 2048 "${FRAMES}" "${w}"
    done
fi

echo "done: ${T}"
