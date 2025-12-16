# Issue 002c: Add Streamer Process

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** 002a

---

## Current Behavior

The issue-splitter.sh script has no streaming output - responses are only shown after being appended to issue files, with no real-time display.

---

## Intended Behavior

Create the `stream_queue()` consumer function that:

1. **Runs as background process**
2. **Polls for ready outputs in order**
3. **Displays formatted response with header**
4. **Waits configurable delay between outputs (grocery store divider)**
5. **Terminates when done signal received and all items processed**

---

## Suggested Implementation Steps

### 1. Create Streamer Function

```bash
# {{{ stream_queue
stream_queue() {
    local done_file="$QUEUE_DIR/done"

    while [[ ! -f "$done_file" ]] || [[ $STREAM_INDEX -lt $QUEUE_COUNTER ]]; do
        local ready_file="$QUEUE_DIR/${STREAM_INDEX}.ready"

        if [[ -f "$ready_file" ]]; then
            local output_file="$QUEUE_DIR/${STREAM_INDEX}.output"
            local meta_file="$QUEUE_DIR/${STREAM_INDEX}.meta"
            local issue_path=$(head -1 "$meta_file")
            local status=$(tail -1 "$meta_file")
            local basename=$(basename "$issue_path")

            # Display header
            echo ""
            echo "┌─────────────────────────────────────────────────────────────"
            echo "│ Response for: $basename"
            echo "└─────────────────────────────────────────────────────────────"
            echo ""

            # Display content
            cat "$output_file"

            echo ""
            echo "─────────────────────────────────────────────────────────────────"

            ((++STREAM_INDEX))

            # Wait before next (the "divider")
            if [[ $STREAM_INDEX -lt $QUEUE_COUNTER ]] || [[ ! -f "$done_file" ]]; then
                sleep "${STREAM_DELAY:-5}"
            fi
        else
            # Poll interval
            sleep 0.2
        fi
    done
}
# }}}
```

### 2. Key Design Points

- **Ordered output:** Always displays items in queue order (0, 1, 2...)
- **Non-blocking poll:** Checks for `.ready` file, sleeps briefly if not found
- **Termination condition:** Exits when `done` file exists AND all items streamed
- **Configurable delay:** Uses `STREAM_DELAY` variable (default 5 seconds)

---

## Testing

Can be tested independently by:
1. Creating a queue directory with pre-populated `.output`, `.meta`, `.ready` files
2. Running `stream_queue` and verifying output order
3. Testing termination by creating `done` file

---

## Related Documents

- issues/002-add-streaming-queue-to-issue-splitter.md (parent issue)
- issues/002a-add-queue-infrastructure.md (dependency)
- src/cli/issue-splitter.sh

---

## Acceptance Criteria

- [ ] `stream_queue()` function exists
- [ ] Displays outputs in order (by queue index)
- [ ] Shows formatted header with issue name
- [ ] Respects `STREAM_DELAY` between outputs
- [ ] Terminates properly when done file exists and all items processed
- [ ] Polls efficiently (0.2s interval when waiting)

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
The "grocery store divider" pattern: items queue up, dividers (delays) separate them,
the cashier (streamer) processes them in order.
