# Conversation Summary: 70a7061f-8911-4194-8e45-3475610d5e92

Generated on: Tue Dec 30 09:35:01 PM PST 2025

--------------------------------------------------------------------------------

### User Request 1

Hello computer, all is well. Can you analyze this issue and suggest how it could
be split into sub-issues?

For each suggested sub-issue, provide:
1. A suggested ID following the pattern {PARENT_ID}{letter} (e.g., if parent is
103, sub-issues are 103a, 103b, etc.)
2. A short dash-separated name
3. A brief description of what it covers
4. Dependencies on other sub-issues

If the issue is already small enough or doesn't benefit from splitting, say so.

Here is the issue file located at:
/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/issues/002-add-streaming-queue-to-issue-splitter.md

---

# Issue 002: Add Streaming Queue to Issue Splitter

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement
**Priority:** Medium
**Affects:** src/cli/issue-splitter.sh
**Dependencies:** 001-fix-issue-splitter-output-handling

---

## Current Behavior

The issue-splitter.sh script processes issues sequentially:
1. Send prompt to Claude Code
2. Wait for complete response
3. Save/append response
4. Move to next issue

No output is shown until each issue completes, and processing is strictly
sequential with no parallelism.

---

## Intended Behavior

Implement a producer-consumer queue system with streaming output:

1. **Parallel Processing:**
   - Start processing next issue while previous is still streaming
   - Multiple Claude Code calls can be in-flight simultaneously

2. **Queued Streaming Output:**
   - As each Claude response completes, add it to an output queue
   - A streamer process displays outputs in order as they become available
   - 5-second delay between queued outputs (like grocery store dividers)

3. **Grocery Store Divider Pattern:**
   ```
   [output1] [STOP] [output2] [STOP] [output3] [STOP]

   - When a response finishes, add it to queue
   - Remove STOP from front (if present)
   - Add STOP to end
   - Streamer reads: output → STOP (wait 5s) → output → STOP (wait 5s) → ...
   ```

---

## Suggested Implementation Steps

## 1. Create Queue Infrastructure

```bash
# {{{ Queue Setup
QUEUE_DIR=""
QUEUE_COUNTER=0
STREAM_INDEX=0
STREAMER_PID=""

setup_queue() {
    QUEUE_DIR=$(mktemp -d)
    QUEUE_COUNTER=0
    STREAM_INDEX=0
}

cleanup_queue() {
    [[ -n "$STREAMER_PID" ]] && kill "$STREAMER_PID" 2>/dev/null
    [[ -d "$QUEUE_DIR" ]] && rm -rf "$QUEUE_DIR"
}
trap cleanup_queue EXIT
# }}}
```

## 2. Create Producer Function

```bash
# {{{ queue_claude_response
queue_claude_response() {
    local issue_path="$1"
    local prompt="$2"
    local queue_num=$((QUEUE_COUNTER++))
    local output_file="$QUEUE_DIR/${queue_num}.output"
    local meta_file="$QUEUE_DIR/${queue_num}.meta"

    # Store metadata
    echo "$issue_path" > "$meta_file"

    # Run Claude and capture output
    if timeout 300 claude -p "$prompt" > "$output_file" 2>&1; then
        echo "success" >> "$meta_file"
    else
        echo "failed" >> "$meta_file"
    fi

    # Mark as ready (atomic)
    touch "$QUEUE_DIR/${queue_num}.ready"
}
# }}}
```

## 3. Create Streamer Process

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
            echo
"┌─────────────────────────────────────────────────────────────"
            echo "│ Response for: $basename"
            echo
"└─────────────────────────────────────────────────────────────"
            echo ""

            # Stream content (can add character-by-character if desired)
            cat "$output_file"

            echo ""
            echo
"─────────────────────────────────────────────────────────────────"

            ((STREAM_INDEX++))

            # Wait before next (the "divider")
            if [[ $STREAM_INDEX -lt $QUEUE_COUNTER ]] || [[ ! -f "$done_file"
]]; then
                sleep 5
            fi
        else
            # Poll interval
            sleep 0.2
        fi
    done
}
# }}}
```

## 4. Modify Main Processing Loop

```bash
# {{{ parallel_process_issues
parallel_process_issues() {
    local issues=("$@")
    local max_parallel=3  # Configurable
    local running=0
    local pids=()

    setup_queue

    # Start streamer in background
    stream_queue &
    STREAMER_PID=$!

    for issue in "${issues[@]}"; do
        # Wait if at max parallel
        while (( running >= max_parallel )); do
            wait -n  # Wait for any child
            ((running--))
        done

        # Start processing in background
        (
            local prompt=$(build_prompt "$issue")
            queue_claude_response "$issue" "$prompt"
        ) &
        pids+=($!)
        ((running++))
    done

    # Wait for all producers
    wait "${pids[@]}"

    # Signal streamer we're done
    touch "$QUEUE_DIR/done"
    wait "$STREAMER_PID"
}
# }}}
```

## 5. Add Configuration Options

```bash
# In Configuration section:
PARALLEL_COUNT=3
STREAM_DELAY=5

# In parse_args:
--parallel)
    PARALLEL_COUNT="$2"
    shift 2
    ;;
--delay)
    STREAM_DELAY="$2"
    shift 2
    ;;
```

---

## Technical Notes

## Race Condition Prevention

- Use atomic file operations (touch, mv) for signaling
- Each queue slot has: .output (content), .meta (metadata), .ready (signal)
- Streamer only reads after .ready exists

## Memory Considerations

- Temp files cleaned up after streaming
- Queue directory removed on exit (trap)

## Character-by-Character Streaming (Optional Enhancement)

```bash
stream_slowly() {
    local file="$1"
    local delay="${2:-0.01}"
    while IFS= read -r -n1 char; do
        printf '%s' "$char"
        sleep "$delay"
    done < "$file"
}
```

---

## Related Documents

- src/cli/issue-splitter.sh
- issues/001-fix-issue-splitter-output-handling.md (prerequisite)
- CLAUDE.md (tool documentation)

---

## Acceptance Criteria

- [ ] Multiple Claude calls can run in parallel
- [ ] Output streams to terminal as responses complete
- [ ] 5-second delay between outputs (configurable with --delay)
- [ ] --parallel flag controls max concurrent calls
- [ ] Queue properly handles fast/slow responses
- [ ] Clean shutdown on Ctrl+C (trap cleanup)
- [ ] Responses still appended to issue files correctly

---

## Notes

This transforms the tool from a batch processor to a more interactive experience
where you can watch responses come in. The grocery store divider metaphor helps
visualize the queue: items (responses) line up, dividers (delays) separate them,
and the cashier (streamer) processes them in order.

Consider adding a --no-stream flag for headless/CI usage that reverts to
sequential processing.

--------------------------------------------------------------------------------

### Assistant Response 1

Based on my analysis of the issue, this is a well-scoped enhancement that **does
benefit from splitting into sub-issues**. The implementation involves several
distinct components that can be developed and tested independently.

## Sub-Issue Analysis for Issue 002

## Recommended Split

| Sub-Issue | Name | Description | Dependencies |
|-----------|------|-------------|--------------|
| **002a** | `add-queue-infrastructure` | Implement the foundational queue
system: temp directory management, counter variables, setup/cleanup functions,
and EXIT trap handling | None (within 002) |
| **002b** | `add-producer-function` | Create the `queue_claude_response()`
function that handles capturing Claude output to queue files with metadata and
atomic ready signaling | 002a |
| **002c** | `add-streamer-process` | Implement `stream_queue()` that polls for
ready outputs and displays them in order with configurable delays between items
| 002a |
| **002d** | `add-parallel-processing-loop` | Modify main processing to use
`parallel_process_issues()` with background subshells, job limiting via `wait
-n`, and streamer coordination | 002a, 002b, 002c |
| **002e** | `add-streaming-config-flags` | Add `--parallel`, `--delay`, and
`--no-stream` command-line options with help text updates | 002d |

---

## Detailed Breakdown

**002a - add-queue-infrastructure**
- Create `QUEUE_DIR`, `QUEUE_COUNTER`, `STREAM_INDEX`, `STREAMER_PID` variables
- Implement `setup_queue()` to create temp directory
- Implement `cleanup_queue()` with proper process/directory cleanup
- Add `trap cleanup_queue EXIT` for graceful shutdown
- Can be tested in isolation by verifying temp dir creation/cleanup

**002b - add-producer-function**
- Implement `queue_claude_response()` 
- Handle .output file (Claude response), .meta file (issue path + status), .ready file (completion signal)
- Include timeout handling for Claude calls
- Can be unit-tested by mocking Claude output

**002c - add-streamer-process**
- Implement `stream_queue()` consumer loop
- Poll for .ready files, display headers/content in order
- Handle configurable delay between outputs
- Proper termination when done file exists and all items processed
- Can be tested independently with pre-populated queue directories

**002d - add-parallel-processing-loop**
- Implement `parallel_process_issues()` orchestrator
- Background job management with max parallel limit
- `wait -n` for job slot management
- Streamer process lifecycle (start, signal done, wait)
- Integration of producers + consumer

**002e - add-streaming-config-flags**
- Add `PARALLEL_COUNT` and `STREAM_DELAY` configuration variables
- Parse `--parallel N` and `--delay N` arguments
- Add `--no-stream` flag for headless/sequential mode
- Update help text

---

## Dependency Graph

```
002a ──┬──> 002b ──┐
       │          ├──> 002d ──> 002e
       └──> 002c ──┘
```

This split allows 002b and 002c to be developed in parallel after 002a is
complete, with 002d integrating everything, and 002e adding the polish.

--------------------------------------------------------------------------------
