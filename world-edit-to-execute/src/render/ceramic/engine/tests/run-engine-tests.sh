#!/bin/bash
# run-engine-tests.sh - builds and runs the kept engine copy's own tests (issue 515g)
#
# In plain terms: the renderer keeps its own copy of the ceramic engine with a
# task queue that takes no lock. This builds that copy together with each test
# program and runs them, stopping at the first failure. The engine needs the
# tables a build generates; they are emitted by serac from a one-box map, with
# the emitted main cut off so the test's own main is the program.
#
# Usage: run-engine-tests.sh [DIR]

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
SORAMECH="/home/ritz/programming/ai-playground/minimal-soramech"
ENGINE="${DIR}/src/render/ceramic/engine"
BUILD="${DIR}/tmp/ceramic/engine-tests"
SERAC="${DIR}/tmp/ceramic/serac"
set -e
mkdir -p "${BUILD}"

if [ ! -x "${SERAC}" ]; then
    bash "${SORAMECH}/scripts/147-build-serac.sh" "${SORAMECH}" -o "${SERAC}" > /dev/null
fi

# the generated tables, from the stub map
cp "${ENGINE}/tests/stub.map" "${ENGINE}/tests/stub-boxes.c" "${BUILD}/"
"${SERAC}" --emit-c "${BUILD}/stub.map"
cut_at=$(grep -n '^int main(int argc, char \*\*argv)' "${BUILD}/stub.c" | cut -d: -f1)
if [ -z "${cut_at}" ]; then
    echo "the emitted stub has no main to cut off" >&2
    exit 1
fi
head -n $((cut_at - 1)) "${BUILD}/stub.c" > "${BUILD}/stub-tables.c"

for test in "${ENGINE}"/tests/test-*.c; do
    name=$(basename "${test}" .c)
    cc -std=gnu11 -O2 -g -pthread -Wall -Wextra -Werror -I"${ENGINE}" \
        "${test}" "${BUILD}/stub-tables.c" "${ENGINE}/cera.c" -o "${BUILD}/${name}" -lm
    echo "== ${name}"
    "${BUILD}/${name}"
done
echo "every engine test passed"
