#!/bin/bash
# test_002c_streamer_process.sh
# Tests the stream_queue consumer function from issue 002c.
# Pre-populates queue with mock data to test ordering and termination.
#
# Usage: ./test_002c_streamer_process.sh

set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"

# Queue variables
QUEUE_DIR=""
STREAM_DELAY=0  # No delay for testing

# {{{ setup_queue
setup_queue() {
    QUEUE_DIR=$(mktemp -d)
}
# }}}

# {{{ cleanup_queue
cleanup_queue() {
    if [[ -n "$QUEUE_DIR" ]] && [[ -d "$QUEUE_DIR" ]]; then
        rm -rf "$QUEUE_DIR"
        QUEUE_DIR=""
    fi
}
# }}}

trap cleanup_queue EXIT INT TERM

# {{{ stream_queue
stream_queue() {
    local done_file="$QUEUE_DIR/done"
    local stream_idx=0
    local idle_count=0
    local max_idle=5  # Reduced for testing (1 second)

    while true; do
        local ready_file="$QUEUE_DIR/${stream_idx}.ready"

        if [[ -f "$ready_file" ]]; then
            idle_count=0
            local output_file="$QUEUE_DIR/${stream_idx}.output"
            local meta_file="$QUEUE_DIR/${stream_idx}.meta"
            local issue_path
            local status
            issue_path=$(head -1 "$meta_file")
            status=$(tail -1 "$meta_file")
            local basename
            basename=$(basename "$issue_path")

            echo ""
            echo "┌─────────────────────────────────────────────────────────────"
            echo "│ Response for: $basename [$status]"
            echo "└─────────────────────────────────────────────────────────────"
            echo ""
            cat "$output_file"
            echo ""
            echo "─────────────────────────────────────────────────────────────────"

            ((++stream_idx))

            if [[ ! -f "$done_file" ]] || [[ -f "$QUEUE_DIR/${stream_idx}.ready" ]]; then
                sleep "${STREAM_DELAY:-0}"
            fi
        else
            if [[ -f "$done_file" ]]; then
                ((++idle_count))
                if [[ $idle_count -ge $max_idle ]]; then
                    break
                fi
            fi
            sleep 0.2
        fi
    done
}
# }}}

# {{{ populate_queue_item
populate_queue_item() {
    local idx="$1"
    local path="$2"
    local content="$3"
    local status="${4:-success}"

    echo "$content" > "$QUEUE_DIR/${idx}.output"
    echo "$path" > "$QUEUE_DIR/${idx}.meta"
    echo "$status" >> "$QUEUE_DIR/${idx}.meta"
    touch "$QUEUE_DIR/${idx}.ready"
}
# }}}

# {{{ test_outputs_in_order
test_outputs_in_order() {
    echo "=== Test: stream_queue outputs items in order ==="
    setup_queue

    # Populate 3 items
    populate_queue_item 0 "/test/first.md" "First response"
    populate_queue_item 1 "/test/second.md" "Second response"
    populate_queue_item 2 "/test/third.md" "Third response"
    touch "$QUEUE_DIR/done"

    # Capture output
    local output
    output=$(stream_queue 2>&1)

    # Check order
    local first_pos second_pos third_pos
    first_pos=$(echo "$output" | grep -n "First response" | head -1 | cut -d: -f1)
    second_pos=$(echo "$output" | grep -n "Second response" | head -1 | cut -d: -f1)
    third_pos=$(echo "$output" | grep -n "Third response" | head -1 | cut -d: -f1)

    if [[ $first_pos -lt $second_pos ]] && [[ $second_pos -lt $third_pos ]]; then
        echo "PASS: outputs in order"
    else
        echo "FAIL: outputs not in order (positions: $first_pos, $second_pos, $third_pos)"
        return 1
    fi

    cleanup_queue
}
# }}}

# {{{ test_shows_status
test_shows_status() {
    echo "=== Test: stream_queue shows status in header ==="
    setup_queue

    populate_queue_item 0 "/test/pass.md" "Pass content" "success"
    populate_queue_item 1 "/test/fail.md" "Fail content" "failed"
    touch "$QUEUE_DIR/done"

    local output
    output=$(stream_queue 2>&1)

    if echo "$output" | grep -q "\[success\]" && echo "$output" | grep -q "\[failed\]"; then
        echo "PASS: shows status"
    else
        echo "FAIL: status not shown in headers"
        return 1
    fi

    cleanup_queue
}
# }}}

# {{{ test_terminates_on_done
test_terminates_on_done() {
    echo "=== Test: stream_queue terminates when done ==="
    setup_queue

    populate_queue_item 0 "/test/only.md" "Only item"
    touch "$QUEUE_DIR/done"

    # Should terminate within reasonable time
    local start_time
    start_time=$(date +%s)

    stream_queue >/dev/null 2>&1

    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    if [[ $elapsed -lt 5 ]]; then
        echo "PASS: terminates on done (${elapsed}s)"
    else
        echo "FAIL: took too long to terminate (${elapsed}s)"
        return 1
    fi

    cleanup_queue
}
# }}}

# {{{ test_empty_queue
test_empty_queue() {
    echo "=== Test: stream_queue handles empty queue ==="
    setup_queue
    touch "$QUEUE_DIR/done"

    local start_time
    start_time=$(date +%s)

    stream_queue >/dev/null 2>&1

    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    if [[ $elapsed -lt 5 ]]; then
        echo "PASS: handles empty queue (${elapsed}s)"
    else
        echo "FAIL: took too long on empty queue (${elapsed}s)"
        return 1
    fi

    cleanup_queue
}
# }}}

# {{{ main
main() {
    echo "Testing Issue 002c: Streamer Process"
    echo "====================================="
    echo ""

    local failed=0

    test_outputs_in_order || ((failed++))
    test_shows_status || ((failed++))
    test_terminates_on_done || ((failed++))
    test_empty_queue || ((failed++))

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
