#!/bin/bash
# test_002a_queue_infrastructure.sh
# Tests the queue infrastructure added in issue 002a.
# Verifies setup_queue, cleanup_queue, and exit trap functionality.
#
# Usage: ./test_002a_queue_infrastructure.sh

set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
SCRIPT_DIR="/home/ritz/programming/ai-stuff/scripts"

# Source only the relevant parts (avoid running main)
source "${SCRIPT_DIR}/libs/tui.sh" 2>/dev/null || true
QUEUE_DIR=""
QUEUE_COUNTER=0
STREAM_INDEX=0
STREAMER_PID=""

# {{{ setup_queue
setup_queue() {
    QUEUE_DIR=$(mktemp -d)
    QUEUE_COUNTER=0
    STREAM_INDEX=0
    STREAMER_PID=""
}
# }}}

# {{{ cleanup_queue
cleanup_queue() {
    if [[ -n "$STREAMER_PID" ]]; then
        kill "$STREAMER_PID" 2>/dev/null || true
        wait "$STREAMER_PID" 2>/dev/null || true
        STREAMER_PID=""
    fi
    if [[ -n "$QUEUE_DIR" ]] && [[ -d "$QUEUE_DIR" ]]; then
        rm -rf "$QUEUE_DIR"
        QUEUE_DIR=""
    fi
}
# }}}

trap cleanup_queue EXIT INT TERM

# {{{ test_setup_queue
test_setup_queue() {
    echo "=== Test: setup_queue creates temp directory ==="
    setup_queue

    if [[ -z "$QUEUE_DIR" ]]; then
        echo "FAIL: QUEUE_DIR is empty"
        return 1
    fi

    if [[ ! -d "$QUEUE_DIR" ]]; then
        echo "FAIL: QUEUE_DIR does not exist as directory"
        return 1
    fi

    if [[ "$QUEUE_COUNTER" -ne 0 ]]; then
        echo "FAIL: QUEUE_COUNTER should be 0, got $QUEUE_COUNTER"
        return 1
    fi

    if [[ "$STREAM_INDEX" -ne 0 ]]; then
        echo "FAIL: STREAM_INDEX should be 0, got $STREAM_INDEX"
        return 1
    fi

    echo "PASS: setup_queue"
    cleanup_queue
}
# }}}

# {{{ test_cleanup_queue
test_cleanup_queue() {
    echo "=== Test: cleanup_queue removes temp directory ==="
    setup_queue
    local saved_dir="$QUEUE_DIR"

    cleanup_queue

    if [[ -d "$saved_dir" ]]; then
        echo "FAIL: Directory still exists after cleanup"
        return 1
    fi

    if [[ -n "$QUEUE_DIR" ]]; then
        echo "FAIL: QUEUE_DIR should be empty after cleanup"
        return 1
    fi

    echo "PASS: cleanup_queue"
}
# }}}

# {{{ test_idempotent_cleanup
test_idempotent_cleanup() {
    echo "=== Test: cleanup_queue can be called multiple times ==="
    setup_queue
    cleanup_queue
    cleanup_queue
    cleanup_queue

    echo "PASS: idempotent cleanup"
}
# }}}

# {{{ test_unique_directories
test_unique_directories() {
    echo "=== Test: each setup creates unique directory ==="
    setup_queue
    local d1="$QUEUE_DIR"
    cleanup_queue

    setup_queue
    local d2="$QUEUE_DIR"
    cleanup_queue

    if [[ "$d1" == "$d2" ]]; then
        echo "FAIL: Same directory reused"
        return 1
    fi

    echo "PASS: unique directories"
}
# }}}

# {{{ main
main() {
    echo "Testing Issue 002a: Queue Infrastructure"
    echo "========================================"
    echo ""

    local failed=0

    test_setup_queue || ((failed++))
    test_cleanup_queue || ((failed++))
    test_idempotent_cleanup || ((failed++))
    test_unique_directories || ((failed++))

    echo ""
    echo "========================================"
    if [[ $failed -eq 0 ]]; then
        echo "All tests passed!"
        exit 0
    else
        echo "$failed test(s) failed"
        exit 1
    fi
}
# }}}

main "$@"
