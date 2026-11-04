#!/bin/bash
# run-crowd.sh - measures the crowd on every threading design (issue 515k)
#
# In plain terms: two armies swap sides through a gap, every unit routing
# round every other -- real game work whose cost nobody chose. This runs
# that crowd one tick at a time on one thread, on the usual hand-written
# designs, and on the ceramic engine, at 500, 2,000 and 5,000 units, and
# writes what each took. Every design must end with exactly the same
# positions as every other (a checksum), or the run stops.
#
# Steps:
#   build     the scenes (crowd-scene.lua), the hand-written designs
#             (crowd-hand.c) and the ceramic program (serac on crowd.map,
#             its main replaced by crowd-host.c)
#   parts     a serial run timing each phase: crowd-parts.tsv
#   runs      every design at every size, ROUNDS times, interleaved:
#             crowd.tsv
#   timelines who ran which chunk when, four ticks as the 2,000-unit armies
#             meet, every design: timeline-WAY.tsv
#   lines     the threading code each design needed: crowd-loc.tsv
#
# Usage: run-crowd.sh [DIR] [ROUNDS]
#   writes tmp/shared-memory/ceramic/crowd/

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
ROUNDS="${2:-2}"
SORAMECH="/home/ritz/programming/ai-playground/minimal-soramech"
SRC="${DIR}/src/render/ceramic/crowd"
FORK="${DIR}/src/render/ceramic/engine"
BUILD="${DIR}/tmp/ceramic/crowd"
OUT="${DIR}/tmp/shared-memory/ceramic/crowd"
SERAC="${DIR}/tmp/ceramic/serac"
set -e
mkdir -p "${BUILD}" "${OUT}"

# the sizes (units a side) and how many ticks each runs: long enough for
# the armies to walk to the middle and meet, where the work is most uneven
SIZES=(250 1000 2500)
declare -A TICKS=([250]=2000 [1000]=4000 [2500]=6500)
THREADS=$(nproc)
WORKERS=$(( THREADS - 1 ))   # the ceramic host's own thread waits; the hand-written main thread works

# {{{ build
if [ ! -x "${SERAC}" ]; then
    bash "${SORAMECH}/scripts/147-build-serac.sh" "${SORAMECH}" -o "${SERAC}" > /dev/null
fi
for n in "${SIZES[@]}"; do luajit "${SRC}/crowd-scene.lua" "${DIR}" "${n}" > "${BUILD}/scene-${n}.txt"; done
cc -std=gnu11 -O2 -Wall -Wextra -pthread -o "${BUILD}/crowd-hand" "${SRC}/crowd-hand.c" "${SRC}/crowd.c" -lm
cp "${SRC}/crowd-boxes.c" "${BUILD}/crowd-boxes.c"
luajit "${SRC}/crowd-gen.lua" > "${BUILD}/crowd.map"
"${SERAC}" --emit-c "${BUILD}/crowd.map"
mv "${BUILD}/crowd.c" "${BUILD}/crowd.emitted.c"
cut_at=$(grep -n '^int main(int argc, char \*\*argv)' "${BUILD}/crowd.emitted.c" | cut -d: -f1)
if [ -z "${cut_at}" ]; then echo "the emitted crowd program has no main to replace" >&2; exit 1; fi
head -n $((cut_at - 1)) "${BUILD}/crowd.emitted.c" > "${BUILD}/crowd-ceramic.c"
cat "${SRC}/crowd-host.c" >> "${BUILD}/crowd-ceramic.c"
cc -std=gnu11 -O2 -pthread -ffunction-sections -fdata-sections \
    -Wl,--export-dynamic-symbol='cera_*' -Wl,--gc-sections \
    -I"${FORK}" -I"${SRC}" -I"${BUILD}" "${BUILD}/crowd-ceramic.c" "${FORK}/cera.c" "${SRC}/crowd.c" \
    -o "${BUILD}/crowd-ceramic" -lm
# }}}
set +e

# {{{ run_way WAY SIZE [ENV...]: one run, one line
run_way() {
    local way="$1" n="$2"
    local scene="${BUILD}/scene-${n}.txt" t="${TICKS[$n]}"
    case "${way}" in
        serial) "${BUILD}/crowd-hand" serial "${scene}" "${t}" 1 ;;
        ceramic) "${BUILD}/crowd-ceramic" "${scene}" "${t}" "${WORKERS}" ;;
        ceramic-spin) CERAMIC_SPIN=10000 "${BUILD}/crowd-ceramic" "${scene}" "${t}" "${WORKERS}" ;;
        *) "${BUILD}/crowd-hand" "${way}" "${scene}" "${t}" "${THREADS}" ;;
    esac
}
# }}}

WAYS=(serial slices-sleep slices-hybrid counter-sleep counter-hybrid jobs ceramic ceramic-spin)

# {{{ parts
echo -e "units\tticks\tsnapshot_ms\tdecide_ms\tsettle_ms\torders_ms\tfloor_ms\tlongest_unit_ms\thw_threads\tcrossings" > "${OUT}/crowd-parts.tsv"
for n in "${SIZES[@]}"; do
    "${BUILD}/crowd-hand" measure "${BUILD}/scene-${n}.txt" "${TICKS[$n]}" 1 | cut -f2- >> "${OUT}/crowd-parts.tsv"
    echo "parts: ${n} a side done" >&2
done
# }}}

# {{{ runs, interleaved: every way once, then again
echo -e "way\tthreads\tunits\tticks\tmean_ms\tmedian_ms\tp99_ms\tworst_ms\tchecksum\tround" > "${OUT}/crowd.tsv"
for round in $(seq 1 "${ROUNDS}"); do
    for n in "${SIZES[@]}"; do
        for way in "${WAYS[@]}"; do
            line=$(run_way "${way}" "${n}")
            echo -e "${line}\t${round}" >> "${OUT}/crowd.tsv"
            echo "round ${round}, ${n} a side: ${line}" >&2
        done
    done
done
# every way at a size must agree on every position
bad=$(awk -F'\t' 'NR > 1 { if (!($3 in sum)) sum[$3] = $9; else if (sum[$3] != $9) print $3 }' "${OUT}/crowd.tsv" | sort -u)
if [ -n "${bad}" ]; then echo "the designs disagree on where units ended, at units: ${bad}" >&2; exit 1; fi
# }}}

# {{{ timelines: four ticks as the 2,000-unit armies meet
for way in slices-hybrid counter-hybrid jobs ceramic; do
    CROWD_TIMELINE="${OUT}/timeline-${way}.tsv" CROWD_TIMELINE_AT=1400 \
        TICKS_OVERRIDE=1 bash -c ':'
    case "${way}" in
        ceramic) CROWD_TIMELINE="${OUT}/timeline-${way}.tsv" CROWD_TIMELINE_AT=1400 "${BUILD}/crowd-ceramic" "${BUILD}/scene-1000.txt" 1404 "${WORKERS}" > /dev/null ;;
        *) CROWD_TIMELINE="${OUT}/timeline-${way}.tsv" CROWD_TIMELINE_AT=1400 "${BUILD}/crowd-hand" "${way}" "${BUILD}/scene-1000.txt" 1404 "${THREADS}" > /dev/null ;;
    esac
done
# }}}

# {{{ lines: the THREADING regions of each program
count_threading() { awk '/THREADING \{/ { on = 1 } on { n++ } /\} THREADING/ { on = 0 } END { print n + 0 }' "$1"; }
{
    echo -e "program\tthreading_lines"
    echo -e "crowd-hand.c (every hand-written way)\t$(count_threading "${SRC}/crowd-hand.c")"
    echo -e "crowd-host.c (the ceramic host)\t$(count_threading "${SRC}/crowd-host.c")"
    echo -e "crowd.map\t$(wc -l < "${BUILD}/crowd.map")"
} > "${OUT}/crowd-loc.tsv"
# }}}
echo "written: ${OUT}"
