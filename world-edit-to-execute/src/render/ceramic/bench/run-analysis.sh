#!/bin/bash
# run-analysis.sh - the ceramic engine's performance analysis (issue 515a)
#
# In plain terms: times the ceramic engine doing a renderer's per-frame work
# (posing skeletons) in many shapes, beside hand-written thread loops doing
# the same work, and writes every measurement to one table. Two engines are
# measured: the stock one (built by serac from the soramech repository) and
# the kept copy with the lock-free task queue (src/render/ceramic/engine,
# issue 515g), whose sweeps carry "@fork" after their name.
#   anatomy  what one task costs, taken apart: an empty task, the work with
#            a 4-byte answer, the work with its 2 KB answer
#   size     what a task's answer costs by size (16 bytes to 1 MB)
#   chunk    how many units one task should cover (1 to 2048, the whole
#            army in one task), beside the hand-written shared-counter loop
#            taking the same number of units at a time
#   scale    how the time falls as workers are added (1 to 11)
#   army     how the time grows with the number of units (128 to 8192)
#   herd     the stock program with one change to a scratch copy of the
#            engine: each hand-in to the task queue wakes one sleeping
#            worker instead of all of them
#   batch    (kept copy only) a frame's requests handed in to the task
#            queue in one call, by units per task and by workers
#   spin     (kept copy only) idle workers look at the task queue again
#            1000 times before sleeping (CERAMIC_SPIN), so a steady stream
#            of hand-ins rarely has to wake anyone
#   landing  (kept copy only) the engine's count of collected results
#            trusted with no workaround wait: every checksum must agree
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
ALL_SWEEPS="anatomy size chunk scale army herd batch spin landing"
SWEEPS="${3:-${ALL_SWEEPS}}"
FORK="${DIR}/src/render/ceramic/engine"
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
# the same program on the kept copy of the engine (issue 515g)
cc -std=gnu11 -O2 -pthread -ffunction-sections -fdata-sections \
    -Wl,--export-dynamic-symbol='cera_*' -Wl,--gc-sections \
    -I"${FORK}" "${BUILD}/analysis.c" "${FORK}/cera.c" -o "${BUILD}/analysis-fork" -lm

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
AF="${BUILD}/analysis-fork"
A1="${BUILD}/analysis-wake-one"
P="${BUILD}/plain"
W=$(( $(nproc) - 1 ))
T="${OUT}/analysis.tsv"
# all sweeps: a fresh table; some: keep the other sweeps' rows
if [ "${SWEEPS}" = "${ALL_SWEEPS}" ] || [ ! -f "${T}" ]; then
    : > "${T}"
else
    for s in ${SWEEPS}; do
        # a sweep and its tagged variants (herd-wake-one, chunk@fork)
        grep -v -E "^${s}([-@][a-z-]+)?"$'\t' "${T}" > "${T}.keep" || true
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

# {{{ both SWEEP ARGS... : one ceramic measurement on each engine
both() {
    local sweep="$1"; shift
    run "${sweep}" "${A}" "$@"
    run "${sweep}@fork" "${AF}" "$@"
}
# }}}

if wanted anatomy; then
    echo "anatomy"
    for v in noop pose_fold pose_unit pose_chunk_64 pose_chunk; do both anatomy "${v}" 2048 "${FRAMES}" "${W}"; done
    run anatomy "${P}" plain 2048 "${FRAMES}"
    run anatomy "${P}" parallel 2048 "${FRAMES}"
    run anatomy "${P}" counter 2048 "${FRAMES}" $(( W + 1 )) 32
fi

if wanted size; then
    echo "size"
    for n in 16 256 2048 16384 65536 122880 262144 524288 1048576; do both size "make_blob_${n}" 256 "${FRAMES}" "${W}"; done
    both size noop 256 "${FRAMES}" "${W}"
fi

if wanted chunk; then
    echo "chunk"
    for k in 1 2 4 8 16 32 64 128 256 512 1024 2048; do
        both chunk "pose_chunk_${k}" 2048 "${FRAMES}" "${W}"
        run chunk "${P}" counter 2048 "${FRAMES}" $(( W + 1 )) "${k}"
    done
    run chunk "${P}" parallel 2048 "${FRAMES}"
    run chunk "${P}" plain 2048 "${FRAMES}"
fi

if wanted scale; then
    echo "scale"
    for w in 1 2 3 4 6 8 11; do
        both scale pose_chunk_32 2048 "${FRAMES}" "${w}"
        both scale pose_fold 2048 "${FRAMES}" "${w}"
        run scale "${P}" parallel 2048 "${FRAMES}" $(( w == 11 ? 12 : w ))
        run scale "${P}" counter 2048 "${FRAMES}" $(( w == 11 ? 12 : w )) 32
    done
    run scale "${P}" plain 2048 "${FRAMES}"
fi

if wanted army; then
    echo "army"
    for u in 128 512 2048 8192; do
        run army "${P}" plain "${u}" "${FRAMES}"
        run army "${P}" parallel "${u}" "${FRAMES}"
        run army "${P}" counter "${u}" "${FRAMES}" $(( W + 1 )) 32
        both army pose_fold "${u}" "${FRAMES}" "${W}"
        both army pose_chunk_32 "${u}" "${FRAMES}" "${W}"
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

if wanted batch; then
    echo "batch"
    for k in 1 2 4 8 16 32 64 128 256; do
        run batch "${AF}" "pose_chunk_${k}" 2048 "${FRAMES}" "${W}" batch
    done
    for w in 1 2 3 4 6 8 11; do
        run batch "${AF}" pose_fold 2048 "${FRAMES}" "${w}" batch
    done
fi

if wanted spin; then
    echo "spin"
    for k in 1 2 4 8 16 32 64 128 256; do
        CERAMIC_SPIN=1000 run spin "${AF}" "pose_chunk_${k}" 2048 "${FRAMES}" "${W}"
    done
    for w in 1 2 3 4 6 8 11; do
        CERAMIC_SPIN=1000 run spin "${AF}" pose_fold 2048 "${FRAMES}" "${w}"
    done
fi

if wanted landing; then
    echo "landing"
    for v in pose_unit pose_chunk; do
        ANALYSIS_TRUST_COUNT=1 run landing "${AF}" "${v}" 2048 "${FRAMES}" "${W}"
    done
fi

echo "done: ${T}"
