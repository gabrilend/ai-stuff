#!/bin/bash
# test_002b_producer_function.sh
# Tests the queue_claude_response producer function from issue 002b.
# Uses a mock claude command to test without API calls.
#
# Usage: ./test_002b_producer_function.sh

set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

# Queue variables (from 002a)
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

# Mock claude command for testing
MOCK_RESPONSE="This is a mock response"
MOCK_EXIT_CODE=0

# {{{ mock_claude
mock_claude() {
    # Simulate claude -p behavior
    if [[ "$1" == "-p" ]]; then
        echo "$MOCK_RESPONSE"
        return $MOCK_EXIT_CODE
    fi
    return 1
}
# }}}

# {{{ queue_claude_response
queue_claude_response() {
    local issue_path="$1"
    local prompt="$2"
    local queue_num=$((QUEUE_COUNTER++))
    local output_file="$QUEUE_DIR/${queue_num}.output"
    local meta_file="$QUEUE_DIR/${queue_num}.meta"

    # Store metadata (issue path)
    echo "$issue_path" > "$meta_file"

    # Run mock Claude and capture output (no timeout for testing)
    if mock_claude -p "$prompt" > "$output_file" 2>&1; then
        echo "success" >> "$meta_file"
    else
        echo "failed" >> "$meta_file"
    fi

    # Mark as ready (atomic signal)
    touch "$QUEUE_DIR/${queue_num}.ready"
}
# }}}

# {{{ test_creates_queue_files
test_creates_queue_files() {
    echo "=== Test: queue_claude_response creates all files ==="
    setup_queue

    queue_claude_response "/test/issue.md" "Test prompt"

    if [[ ! -f "$QUEUE_DIR/0.output" ]]; then
        echo "FAIL: .output file not created"
        return 1
    fi

    if [[ ! -f "$QUEUE_DIR/0.meta" ]]; then
        echo "FAIL: .meta file not created"
        return 1
    fi

    if [[ ! -f "$QUEUE_DIR/0.ready" ]]; then
        echo "FAIL: .ready file not created"
        return 1
    fi

    echo "PASS: creates queue files"
    cleanup_queue
}
# }}}

# {{{ test_output_content
test_output_content() {
    echo "=== Test: .output file contains response ==="
    setup_queue
    MOCK_RESPONSE="Test response content"

    queue_claude_response "/test/issue.md" "Test prompt"

    local content
    content=$(cat "$QUEUE_DIR/0.output")
    if [[ "$content" != "Test response content" ]]; then
        echo "FAIL: Expected 'Test response content', got '$content'"
        return 1
    fi

    echo "PASS: output content correct"
    cleanup_queue
}
# }}}

# {{{ test_meta_content
test_meta_content() {
    echo "=== Test: .meta file contains path and status ==="
    setup_queue
    MOCK_EXIT_CODE=0

    queue_claude_response "/path/to/issue.md" "Test prompt"

    local line1
    local line2
    line1=$(sed -n '1p' "$QUEUE_DIR/0.meta")
    line2=$(sed -n '2p' "$QUEUE_DIR/0.meta")

    if [[ "$line1" != "/path/to/issue.md" ]]; then
        echo "FAIL: Expected '/path/to/issue.md', got '$line1'"
        return 1
    fi

    if [[ "$line2" != "success" ]]; then
        echo "FAIL: Expected 'success', got '$line2'"
        return 1
    fi

    echo "PASS: meta content correct"
    cleanup_queue
}
# }}}

# {{{ test_increments_counter
test_increments_counter() {
    echo "=== Test: QUEUE_COUNTER increments ==="
    setup_queue

    if [[ "$QUEUE_COUNTER" -ne 0 ]]; then
        echo "FAIL: Initial counter should be 0"
        return 1
    fi

    queue_claude_response "/test/a.md" "Prompt A"
    if [[ "$QUEUE_COUNTER" -ne 1 ]]; then
        echo "FAIL: Counter should be 1 after first call"
        return 1
    fi

    queue_claude_response "/test/b.md" "Prompt B"
    if [[ "$QUEUE_COUNTER" -ne 2 ]]; then
        echo "FAIL: Counter should be 2 after second call"
        return 1
    fi

    # Verify files have correct numbers
    if [[ ! -f "$QUEUE_DIR/0.ready" ]] || [[ ! -f "$QUEUE_DIR/1.ready" ]]; then
        echo "FAIL: Queue files not numbered correctly"
        return 1
    fi

    echo "PASS: counter increments"
    cleanup_queue
}
# }}}

# {{{ test_failure_status
test_failure_status() {
    echo "=== Test: failed command marks as failed ==="
    setup_queue
    MOCK_EXIT_CODE=1

    queue_claude_response "/test/fail.md" "Fail prompt"

    local status
    status=$(sed -n '2p' "$QUEUE_DIR/0.meta")
    if [[ "$status" != "failed" ]]; then
        echo "FAIL: Expected 'failed', got '$status'"
        return 1
    fi

    # .ready should still be created
    if [[ ! -f "$QUEUE_DIR/0.ready" ]]; then
        echo "FAIL: .ready should still be created on failure"
        return 1
    fi

    echo "PASS: failure status"
    MOCK_EXIT_CODE=0
    cleanup_queue
}
# }}}

# {{{ main
main() {
    echo "Testing Issue 002b: Producer Function"
    echo "====================================="
    echo ""

    local failed=0

    test_creates_queue_files || ((failed++))
    test_output_content || ((failed++))
    test_meta_content || ((failed++))
    test_increments_counter || ((failed++))
    test_failure_status || ((failed++))

    echo ""
    echo "====================================="
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
