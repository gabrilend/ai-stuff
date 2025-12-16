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

### 1. Create Queue Infrastructure

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

### 2. Create Producer Function

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

### 3. Create Streamer Process

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

            # Stream content (can add character-by-character if desired)
            cat "$output_file"

            echo ""
            echo "─────────────────────────────────────────────────────────────────"

            ((STREAM_INDEX++))

            # Wait before next (the "divider")
            if [[ $STREAM_INDEX -lt $QUEUE_COUNTER ]] || [[ ! -f "$done_file" ]]; then
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

### 4. Modify Main Processing Loop

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

### 5. Add Configuration Options

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

### Race Condition Prevention

- Use atomic file operations (touch, mv) for signaling
- Each queue slot has: .output (content), .meta (metadata), .ready (signal)
- Streamer only reads after .ready exists

### Memory Considerations

- Temp files cleaned up after streaming
- Queue directory removed on exit (trap)

### Character-by-Character Streaming (Optional Enhancement)

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

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 00:05*

Based on my analysis of the issue, this is a well-scoped enhancement that **does benefit from splitting into sub-issues**. The implementation involves several distinct components that can be developed and tested independently.

## Sub-Issue Analysis for Issue 002

### Recommended Split

| Sub-Issue | Name | Description | Dependencies |
|-----------|------|-------------|--------------|
| **002a** | `add-queue-infrastructure` | Implement the foundational queue system: temp directory management, counter variables, setup/cleanup functions, and EXIT trap handling | None (within 002) |
| **002b** | `add-producer-function` | Create the `queue_claude_response()` function that handles capturing Claude output to queue files with metadata and atomic ready signaling | 002a |
| **002c** | `add-streamer-process` | Implement `stream_queue()` that polls for ready outputs and displays them in order with configurable delays between items | 002a |
| **002d** | `add-parallel-processing-loop` | Modify main processing to use `parallel_process_issues()` with background subshells, job limiting via `wait -n`, and streamer coordination | 002a, 002b, 002c |
| **002e** | `add-streaming-config-flags` | Add `--parallel`, `--delay`, and `--no-stream` command-line options with help text updates | 002d |

---

### Detailed Breakdown

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

### Dependency Graph

```
002a ──┬──> 002b ──┐
       │          ├──> 002d ──> 002e
       └──> 002c ──┘
```

This split allows 002b and 002c to be developed in parallel after 002a is complete, with 002d integrating everything, and 002e adding the polish.

---

## Generated Sub-Issues

*Auto-generated on 2025-12-16*

- 002a-add-queue-infrastructure.md
- 002b-add-producer-function.md
- 002c-add-streamer-process.md
- 002d-add-parallel-processing-loop.md
- 002e-add-streaming-config-flags.md

---

## Structure Review

*Generated by Claude Code on 2025-12-16 00:32*

Let me proceed with the analysis based on the issue content you provided.

---

## Analysis Summary

The root issue (002) and its sub-issues are well-structured with a clear dependency graph. Here are my recommendations:

---

### 1. Sub-Issues That Could Be Further Broken Down

**002d - add-parallel-processing-loop** - Could potentially benefit from splitting

This sub-issue is the most complex, handling multiple responsibilities:
- Integration with existing issue filtering logic (skip sub-issues, roots with subs, etc.)
- Job slot management with `wait -n`
- Streamer lifecycle management
- Process ID tracking

**Recommendation:** Keep as-is. While complex, splitting would create artificial boundaries between tightly coupled logic. The dependencies (002a, 002b, 002c) are clean, and 002d serves as the natural integration point.

---

### 2. Potential Gap: Missing Sub-Issues

**Gap A: Error Handling & Recovery (suggested: 002f)**

The current sub-issues don't address:
- What happens when Claude fails mid-queue (partial success scenario)
- How to handle streamer crashes
- Recovery from interrupted runs (e.g., resume capability)
- Distinction between "failed to reach Claude" vs "Claude returned error analysis"

**Recommendation:** Add `002f-add-queue-error-handling.md`
- Handle partial failures gracefully
- Display failed items with error context
- Consider `--continue-on-error` flag
- Log failed items for retry

**Gap B: File Append Integration**

The acceptance criteria for 002 states "Responses still appended to issue files correctly" but no sub-issue explicitly covers modifying the append logic to work with the queue system. Currently this is assumed in 002b/002d but not explicitly addressed.

**Recommendation:** Either:
1. Add explicit step to 002b for post-queue file operations, OR
2. Add `002g-integrate-queue-with-file-append.md` if the append logic is complex

**Gap C: Testing/Verification**

No sub-issue covers creating test infrastructure for the queue system.

**Recommendation:** Consider `002h-add-queue-test-harness.md` or defer to Phase 0 test demo requirements.

---

### 3. Structural Improvements

**Improvement A: Clarify STREAM_INDEX Scope**

In 002a, `STREAM_INDEX` is declared as a global variable, but 002c uses it with `((++STREAM_INDEX))`. Since 002c's `stream_queue()` runs in a subshell (backgrounded with `&`), it cannot modify the parent's `STREAM_INDEX`.

**Recommendation:** Update 002a and 002c to note that `STREAM_INDEX` should be local to the streamer, not a shared global. The streamer maintains its own counter.

**Improvement B: Dependency Clarity in 002d**

002d lists dependencies as "002a, 002b, 002c" but the implementation also needs:
- The existing `build_prompt()` function
- The existing `is_subissue()`, `get_root_id()`, `has_subissues()` functions
- The `ROOTS_WITH_SUBS` array

**Recommendation:** Add "Prerequisites" section to 002d noting these existing functions must remain unchanged or be adapted.

**Improvement C: Add Bash Version Requirement**

002d mentions `wait -n` requires Bash 4.3+ in Notes, but this should be elevated to an acceptance criterion or documented in 002e's help output.

**Recommendation:** Add to 002e: "Help text includes Bash version requirement (4.3+) for streaming mode"

---

### Summary Table

| ID | Recommendation | Priority |
|----|----------------|----------|
| 002d | Keep as-is (integration point) | N/A |
| **NEW 002f** | Add error handling sub-issue | Medium |
| 002b | Clarify file append integration | Low |
| 002a/002c | Fix STREAM_INDEX scope documentation | Low |
| 002d | Add prerequisites section | Low |
| 002e | Add Bash version to help/acceptance criteria | Low |

---

### Suggested New Sub-Issue: 002f

```
002f-add-queue-error-handling.md

Dependencies: 002b, 002c
Covers:
- Display "[FAILED]" indicator in streamer for failed items
- Track failed issues in array for summary
- Add --continue-on-error flag (default: true)
- Print summary at end: "X succeeded, Y failed"
- Consider --retry-failed flag for future enhancement
```
