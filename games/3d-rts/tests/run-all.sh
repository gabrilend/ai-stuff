#!/bin/bash
# tests/run-all.sh
#
# Compile and run every test file in this directory in turn. Each
# test is a standalone C program that exercises one specific piece
# of library functionality (per the tests/000-index.md mapping).
# Reports PASS / FAIL per test and exits non-zero if any test failed.
#
# Designed to be runnable from any directory. The hard-coded DIR
# below points at the project root; pass an alternate path as the
# first argument to override (e.g. `bash tests/run-all.sh /elsewhere/3d-rts`).

set -u

DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/3d-rts}"
TESTS_DIR="${DIR}/tests"
BUILD_DIR="${TESTS_DIR}/build"

mkdir -p "${BUILD_DIR}"

CFLAGS="-Wall -Wextra -Wpedantic -std=c11 -D_XOPEN_SOURCE=600"
LIB_C="${DIR}/libs/900-task-pool.c"
TIMEOUT_SECS=10

pass_count=0
fail_count=0
fail_list=""

# Iterate test files in numeric order (filenames start with NNN).
shopt -s nullglob
for src in "${TESTS_DIR}"/[0-9][0-9][0-9]-*.c; do
    name=$(basename "${src}" .c)
    bin="${BUILD_DIR}/${name}"

    echo "=== ${name} ==="

    # Compile.
    compile_log="${BUILD_DIR}/${name}.compile.log"
    if ! gcc ${CFLAGS} "${src}" "${LIB_C}" -lpthread -o "${bin}" 2>"${compile_log}"; then
        echo "FAIL (compile error; see ${compile_log}):"
        cat "${compile_log}"
        fail_count=$((fail_count + 1))
        fail_list="${fail_list} ${name}"
        continue
    fi

    # Run with timeout.
    if timeout "${TIMEOUT_SECS}" "${bin}"; then
        pass_count=$((pass_count + 1))
    else
        rc=$?
        if [ "${rc}" -eq 124 ]; then
            echo "FAIL (timeout after ${TIMEOUT_SECS}s)"
        else
            echo "FAIL (exit ${rc})"
        fi
        fail_count=$((fail_count + 1))
        fail_list="${fail_list} ${name}"
    fi
    echo
done

echo "----"
echo "summary: ${pass_count} passed, ${fail_count} failed"
if [ "${fail_count}" -gt 0 ]; then
    echo "failed tests:${fail_list}"
    exit 1
fi
exit 0
