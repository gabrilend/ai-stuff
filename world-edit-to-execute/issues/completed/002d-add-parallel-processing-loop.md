# Issue 002d: Add Parallel Processing Loop

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** 002a, 002b, 002c

---

## Current Behavior

The issue-splitter.sh script processes issues in a sequential for loop, waiting for each Claude call to complete before starting the next.

---

## Intended Behavior

Create the `parallel_process_issues()` orchestrator function that:

1. **Initializes queue system**
2. **Starts streamer in background**
3. **Launches parallel workers with job limiting**
4. **Uses `wait -n` for job slot management**
5. **Signals completion and waits for streamer**

---

## Suggested Implementation Steps

### 1. Create Parallel Processing Function

```bash
# {{{ parallel_process_issues
parallel_process_issues() {
    local issues=("$@")
    local max_parallel="${PARALLEL_COUNT:-3}"
    local running=0
    local pids=()

    setup_queue

    # Start streamer in background
    stream_queue &
    STREAMER_PID=$!

    for issue in "${issues[@]}"; do
        # Skip ineligible issues (sub-issues, roots with subs, etc.)
        local basename=$(basename "$issue")
        local root_id=$(get_root_id "$basename")

        if is_subissue "$basename"; then
            continue
        fi
        if has_subissues "$root_id"; then
            ROOTS_WITH_SUBS+=("$issue")
            continue
        fi
        if [[ "$SKIP_EXISTING" == true ]] && has_subissue_analysis "$issue"; then
            continue
        fi

        # Wait if at max parallel
        while (( running >= max_parallel )); do
            wait -n  # Wait for any child to finish
            ((--running))
        done

        # Start processing in background
        (
            local prompt=$(build_prompt "$issue")
            queue_claude_response "$issue" "$prompt"
        ) &
        pids+=($!)
        ((++running))
    done

    # Wait for all producers to complete
    wait "${pids[@]}"

    # Signal streamer we're done producing
    touch "$QUEUE_DIR/done"

    # Wait for streamer to finish displaying
    wait "$STREAMER_PID"
}
# }}}
```

### 2. Integration with Existing Flow

- Replace or wrap the existing sequential for loop
- Maintain compatibility with dry-run and review-only modes
- Ensure ROOTS_WITH_SUBS is still populated for Phase 2

---

## Testing

Integration test:
1. Create test issues
2. Run with `--parallel 2`
3. Verify multiple Claude calls in flight
4. Verify output streams in order
5. Verify all analyses appended correctly

---

## Related Documents

- issues/002-add-streaming-queue-to-issue-splitter.md (parent issue)
- issues/002a-add-queue-infrastructure.md (dependency)
- issues/002b-add-producer-function.md (dependency)
- issues/002c-add-streamer-process.md (dependency)
- src/cli/issue-splitter.sh

---

## Acceptance Criteria

- [x] `parallel_process_issues()` function exists
- [x] Respects `PARALLEL_COUNT` for max concurrent jobs
- [x] Uses `wait -n` for efficient job slot management
- [x] Starts and manages streamer process lifecycle
- [x] Signals completion properly to streamer
- [x] Still populates `ROOTS_WITH_SUBS` for Phase 2 review
- [x] Analyses still appended to issue files correctly

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
This is the integration point that brings together the queue, producer, and streamer.
The `wait -n` command requires Bash 4.3+.

---

## Implementation Notes

*Completed 2025-12-16*

### Changes Made

1. Added configuration variables in Queue Configuration section:
   - `PARALLEL_COUNT=3` - max concurrent jobs
   - `STREAM_DELAY=5` - delay between streamed outputs
   - `STREAMING_MODE=false` - flag for enabling streaming (002e)

2. Added `process_issue_parallel()` function (lines 181-224):
   - Combines queue_claude_response functionality with file appending
   - Writes to queue (.output, .meta, .ready files)
   - Appends Sub-Issue Analysis section to issue file on success
   - Handles archive mode if enabled

3. Added `parallel_process_issues()` function (lines 227-290):
   - Initializes queue and starts streamer in background
   - Iterates issues with skip logic (sub-issues, roots with subs, already analyzed)
   - Uses `wait -n` for job slot management
   - Tracks ROOTS_WITH_SUBS for Phase 2 review
   - Signals completion via done file and waits for streamer

### Design Decisions

- Separated `process_issue_parallel()` from `queue_claude_response()` to keep
  queue primitives simple while handling file I/O in the wrapper
- Error handling with `|| true` to prevent script exit on background job errors
- Uses `wait -n` for efficient slot management (requires Bash 4.3+)

### Testing

Created `src/tests/test_002d_parallel_processing.sh` which verifies:
- All eligible issues are processed
- Sub-issues are skipped
- Roots with existing sub-issues tracked to ROOTS_WITH_SUBS
- PARALLEL_COUNT is respected

All tests pass (using inline mock for claude).
