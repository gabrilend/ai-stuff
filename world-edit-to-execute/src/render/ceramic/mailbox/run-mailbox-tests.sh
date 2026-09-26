#!/bin/bash
# run-mailbox-tests.sh - builds and runs the mailbox's tests three ways (issue 515c)
#
# In plain terms: the mailbox passes finished frames from the engine to the
# drawing thread. This proves three things: the real mailbox never shows a
# half-written frame; a deliberately broken one is caught (so the tests can
# tell the difference); and a race detector watching the real one finds
# nothing.
#
# Usage: run-mailbox-tests.sh [DIR]
#   writes tmp/shared-memory/ceramic/mailbox-tests.txt

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
SRC="${DIR}/src/render/ceramic/mailbox"
BUILD="${DIR}/tmp/ceramic/mailbox"
OUT="${DIR}/tmp/shared-memory/ceramic"
mkdir -p "${BUILD}" "${OUT}"
LOG="${OUT}/mailbox-tests.txt"
: > "${LOG}"
set -e
cc -std=gnu11 -O2 -pthread -Wall -Wextra "${SRC}/test-mailbox.c" -o "${BUILD}/test-mailbox"
clang -std=gnu11 -O1 -g -pthread -fsanitize=thread "${SRC}/test-mailbox.c" -o "${BUILD}/test-mailbox-tsan"
set +e

failed=0
echo "== the real mailbox" | tee -a "${LOG}"
"${BUILD}/test-mailbox" | tee -a "${LOG}"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then failed=1; fi

# the broken mailbox must be caught, by name: a crash would not count
echo "== the broken mailbox (must be caught)" | tee -a "${LOG}"
caught=$("${BUILD}/test-mailbox" --broken)
echo "${caught}" | tee -a "${LOG}"
if echo "${caught}" | grep -q -e '^torn$' -e '^out of order$'; then
    echo "pass  the broken mailbox was caught" | tee -a "${LOG}"
else
    echo "FAIL  the broken mailbox went unnoticed" | tee -a "${LOG}"
    failed=1
fi

echo "== the real mailbox under ThreadSanitizer" | tee -a "${LOG}"
TSAN_OPTIONS="halt_on_error=1" "${BUILD}/test-mailbox-tsan" 20000 2>&1 | tee -a "${LOG}"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then failed=1; fi

if [ "${failed}" -ne 0 ]; then echo "mailbox tests FAILED (log: ${LOG})"; exit 1; fi
echo "mailbox tests passed (log: ${LOG})"
