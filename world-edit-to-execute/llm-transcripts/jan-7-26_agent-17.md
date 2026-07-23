# Conversation Summary: 37497cb7-4f88-476f-8012-f53a2f06fdb0

Generated on: Tue Dec 30 09:34:58 PM PST 2025

--------------------------------------------------------------------------------

### User Request 1

Hello computer, all is well. I have a root issue that already has sub-issues.
Please review it and suggest:

1. Whether any existing sub-issues should be broken down further
2. Whether the root issue needs additional sub-issues to cover gaps
3. Any structural improvements to the sub-issue organization

For each suggestion, provide the issue ID and your recommendation.

Here is the root issue and its sub-issues:

═══════════════════════════════════════════════════════════════
ROOT ISSUE: 002-add-streaming-queue-to-issue-splitter.md
═══════════════════════════════════════════════════════════════

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

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 00:05*

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

---

## Generated Sub-Issues

*Auto-generated on 2025-12-16*

- 002a-add-queue-infrastructure.md
- 002b-add-producer-function.md
- 002c-add-streamer-process.md
- 002d-add-parallel-processing-loop.md
- 002e-add-streaming-config-flags.md

SUB-ISSUES:

───────────────────────────────────────────────────────────────
002a-add-queue-infrastructure.md
───────────────────────────────────────────────────────────────

# Issue 002a: Add Queue Infrastructure

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** None (within 002)

---

## Current Behavior

The issue-splitter.sh script has no queue system - it processes issues strictly
sequentially with no parallel processing capability.

---

## Intended Behavior

Create the foundational queue system that will enable parallel processing:

1. **Queue directory management:**
   - Temp directory for queue files
   - Counter for queue slot numbering
   - Index tracking for streamer position

2. **Setup function:**
   - Create temp directory with `mktemp -d`
   - Initialize counters to 0

3. **Cleanup function:**
   - Kill streamer process if running
   - Remove temp directory and all contents

4. **Exit trap:**
   - Ensure cleanup runs on EXIT, INT, TERM signals

---

## Suggested Implementation Steps

## 1. Add Queue Variables to Configuration

```bash
# {{{ Queue Configuration
QUEUE_DIR=""
QUEUE_COUNTER=0
STREAM_INDEX=0
STREAMER_PID=""
# }}}
```

## 2. Create Setup Function

```bash
# {{{ setup_queue
setup_queue() {
    QUEUE_DIR=$(mktemp -d)
    QUEUE_COUNTER=0
    STREAM_INDEX=0
}
# }}}
```

## 3. Create Cleanup Function

```bash
# {{{ cleanup_queue
cleanup_queue() {
    [[ -n "$STREAMER_PID" ]] && kill "$STREAMER_PID" 2>/dev/null
    [[ -d "$QUEUE_DIR" ]] && rm -rf "$QUEUE_DIR"
}
# }}}
```

## 4. Add Exit Trap

```bash
trap cleanup_queue EXIT INT TERM
```

---

## Testing

Can be tested in isolation by:
1. Calling `setup_queue`
2. Verifying `$QUEUE_DIR` exists and is a directory
3. Calling `cleanup_queue`
4. Verifying `$QUEUE_DIR` no longer exists

---

## Related Documents

- issues/002-add-streaming-queue-to-issue-splitter.md (parent issue)
- src/cli/issue-splitter.sh

---

## Acceptance Criteria

- [ ] `QUEUE_DIR`, `QUEUE_COUNTER`, `STREAM_INDEX`, `STREAMER_PID` variables exist
- [ ] `setup_queue()` creates temp directory and initializes counters
- [ ] `cleanup_queue()` removes temp directory and kills streamer
- [ ] Exit trap ensures cleanup on script termination
- [ ] Can be called multiple times without error

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
This is the foundation that 002b and 002c both depend on.

───────────────────────────────────────────────────────────────
002b-add-producer-function.md
───────────────────────────────────────────────────────────────

# Issue 002b: Add Producer Function

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** 002a

---

## Current Behavior

The issue-splitter.sh script calls Claude directly and waits for the response
before continuing. There is no mechanism to queue responses for later display.

---

## Intended Behavior

Create the `queue_claude_response()` producer function that:

1. **Accepts issue path and prompt**
2. **Assigns queue slot number**
3. **Creates queue files:**
   - `.output` - Claude's response content
   - `.meta` - Issue path and status
   - `.ready` - Atomic completion signal
4. **Handles timeout/failure gracefully**

---

## Suggested Implementation Steps

## 1. Create Producer Function

```bash
# {{{ queue_claude_response
queue_claude_response() {
    local issue_path="$1"
    local prompt="$2"
    local queue_num=$((QUEUE_COUNTER++))
    local output_file="$QUEUE_DIR/${queue_num}.output"
    local meta_file="$QUEUE_DIR/${queue_num}.meta"

    # Store metadata (issue path)
    echo "$issue_path" > "$meta_file"

    # Run Claude and capture output
    if timeout 300 claude -p "$prompt" > "$output_file" 2>&1; then
        echo "success" >> "$meta_file"
    else
        echo "failed" >> "$meta_file"
    fi

    # Mark as ready (atomic signal)
    touch "$QUEUE_DIR/${queue_num}.ready"
}
# }}}
```

## 2. Queue File Format

Each queue slot `N` has three files:
- `N.output` - The actual Claude response text
- `N.meta` - Line 1: issue path, Line 2: "success" or "failed"
- `N.ready` - Empty file, existence signals completion

---

## Testing

Can be unit-tested by:
1. Setting up queue with `setup_queue`
2. Mocking Claude output (or using a simple echo command)
3. Calling `queue_claude_response` with test data
4. Verifying all three files exist with expected content

---

## Related Documents

- issues/002-add-streaming-queue-to-issue-splitter.md (parent issue)
- issues/002a-add-queue-infrastructure.md (dependency)
- src/cli/issue-splitter.sh

---

## Acceptance Criteria

- [ ] `queue_claude_response()` function exists
- [ ] Function increments `QUEUE_COUNTER` atomically
- [ ] Creates `.output` file with Claude response
- [ ] Creates `.meta` file with issue path and status
- [ ] Creates `.ready` file only after completion (atomic signal)
- [ ] Handles Claude timeout gracefully (marks as failed)

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
The `.ready` file pattern ensures the streamer never reads incomplete output.

───────────────────────────────────────────────────────────────
002c-add-streamer-process.md
───────────────────────────────────────────────────────────────

# Issue 002c: Add Streamer Process

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** 002a

---

## Current Behavior

The issue-splitter.sh script has no streaming output - responses are only shown
after being appended to issue files, with no real-time display.

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

## 1. Create Streamer Function

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

            # Display content
            cat "$output_file"

            echo ""
            echo
"─────────────────────────────────────────────────────────────────"

            ((++STREAM_INDEX))

            # Wait before next (the "divider")
            if [[ $STREAM_INDEX -lt $QUEUE_COUNTER ]] || [[ ! -f "$done_file"
]]; then
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

## 2. Key Design Points

- **Ordered output:** Always displays items in queue order (0, 1, 2...)
- **Non-blocking poll:** Checks for `.ready` file, sleeps briefly if not found
- **Termination condition:** Exits when `done` file exists AND all items streamed
- **Configurable delay:** Uses `STREAM_DELAY` variable (default 5 seconds)

---

## Testing

Can be tested independently by:
1. Creating a queue directory with pre-populated `.output`, `.meta`, `.ready`
files
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
The "grocery store divider" pattern: items queue up, dividers (delays) separate
them,
the cashier (streamer) processes them in order.

───────────────────────────────────────────────────────────────
002d-add-parallel-processing-loop.md
───────────────────────────────────────────────────────────────

# Issue 002d: Add Parallel Processing Loop

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** 002a, 002b, 002c

---

## Current Behavior

The issue-splitter.sh script processes issues in a sequential for loop, waiting
for each Claude call to complete before starting the next.

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

## 1. Create Parallel Processing Function

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
        if [[ "$SKIP_EXISTING" == true ]] && has_subissue_analysis "$issue";
then
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

## 2. Integration with Existing Flow

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

- [ ] `parallel_process_issues()` function exists
- [ ] Respects `PARALLEL_COUNT` for max concurrent jobs
- [ ] Uses `wait -n` for efficient job slot management
- [ ] Starts and manages streamer process lifecycle
- [ ] Signals completion properly to streamer
- [ ] Still populates `ROOTS_WITH_SUBS` for Phase 2 review
- [ ] Analyses still appended to issue files correctly

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
This is the integration point that brings together the queue, producer, and
streamer.
The `wait -n` command requires Bash 4.3+.

───────────────────────────────────────────────────────────────
002e-add-streaming-config-flags.md
───────────────────────────────────────────────────────────────

# Issue 002e: Add Streaming Config Flags

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** 002d

---

## Current Behavior

The issue-splitter.sh script has no configuration options for parallel
processing or streaming output delays.

---

## Intended Behavior

Add command-line flags to control streaming behavior:

1. **`--parallel N`** - Set max concurrent Claude calls (default: 3)
2. **`--delay N`** - Set seconds between streamed outputs (default: 5)
3. **`--no-stream`** - Disable streaming, use sequential processing

---

## Suggested Implementation Steps

## 1. Add Configuration Variables

```bash
# In Configuration section:
PARALLEL_COUNT=3
STREAM_DELAY=5
STREAM_MODE=true
```

## 2. Add Argument Parsing

```bash
# In parse_args:
--parallel)
    PARALLEL_COUNT="$2"
    shift 2
    ;;
--delay)
    STREAM_DELAY="$2"
    shift 2
    ;;
--no-stream)
    STREAM_MODE=false
    shift
    ;;
```

## 3. Update Help Text

```bash
#   --parallel <n>        Max concurrent Claude calls (default: 3)
#   --delay <n>           Seconds between streamed outputs (default: 5)
#   --no-stream           Disable streaming, process sequentially
```

## 4. Conditional Processing in Main

```bash
if [[ "$STREAM_MODE" == true ]]; then
    parallel_process_issues "${SELECTED_ISSUES[@]}"
else
    # Use existing sequential loop
    for issue in "${SELECTED_ISSUES[@]}"; do
        process_issue "$issue"
    done
fi
```

---

## Testing

1. `./issue-splitter.sh --parallel 5` - Should allow 5 concurrent jobs
2. `./issue-splitter.sh --delay 10` - Should wait 10s between outputs
3. `./issue-splitter.sh --no-stream` - Should process sequentially

---

## Related Documents

- issues/002-add-streaming-queue-to-issue-splitter.md (parent issue)
- issues/002d-add-parallel-processing-loop.md (dependency)
- src/cli/issue-splitter.sh

---

## Acceptance Criteria

- [ ] `--parallel N` flag sets `PARALLEL_COUNT`
- [ ] `--delay N` flag sets `STREAM_DELAY`
- [ ] `--no-stream` flag disables parallel/streaming mode
- [ ] Help text documents all three flags
- [ ] Default values work when flags not provided
- [ ] Interactive mode could offer these as options (future enhancement)

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
The `--no-stream` flag is important for headless/CI usage where streaming
output may not be desired or may cause issues with log aggregation.

--------------------------------------------------------------------------------

### Assistant Response 1

Let me proceed with the analysis based on the issue content you provided.

---

## Analysis Summary

The root issue (002) and its sub-issues are well-structured with a clear
dependency graph. Here are my recommendations:

---

## 1. Sub-Issues That Could Be Further Broken Down

**002d - add-parallel-processing-loop** - Could potentially benefit from splitting

This sub-issue is the most complex, handling multiple responsibilities:
- Integration with existing issue filtering logic (skip sub-issues, roots with subs, etc.)
- Job slot management with `wait -n`
- Streamer lifecycle management
- Process ID tracking

**Recommendation:** Keep as-is. While complex, splitting would create artificial boundaries between tightly coupled logic. The dependencies (002a, 002b, 002c) are clean, and 002d serves as the natural integration point.

---

## 2. Potential Gap: Missing Sub-Issues

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

The acceptance criteria for 002 states "Responses still appended to issue files
correctly" but no sub-issue explicitly covers modifying the append logic to work
with the queue system. Currently this is assumed in 002b/002d but not explicitly
addressed.

**Recommendation:** Either:
1. Add explicit step to 002b for post-queue file operations, OR
2. Add `002g-integrate-queue-with-file-append.md` if the append logic is complex

**Gap C: Testing/Verification**

No sub-issue covers creating test infrastructure for the queue system.

**Recommendation:** Consider `002h-add-queue-test-harness.md` or defer to Phase 0 test demo requirements.

---

## 3. Structural Improvements

**Improvement A: Clarify STREAM_INDEX Scope**

In 002a, `STREAM_INDEX` is declared as a global variable, but 002c uses it with
`((++STREAM_INDEX))`. Since 002c's `stream_queue()` runs in a subshell
(backgrounded with `&`), it cannot modify the parent's `STREAM_INDEX`.

**Recommendation:** Update 002a and 002c to note that `STREAM_INDEX` should be local to the streamer, not a shared global. The streamer maintains its own counter.

**Improvement B: Dependency Clarity in 002d**

002d lists dependencies as "002a, 002b, 002c" but the implementation also needs:
- The existing `build_prompt()` function
- The existing `is_subissue()`, `get_root_id()`, `has_subissues()` functions
- The `ROOTS_WITH_SUBS` array

**Recommendation:** Add "Prerequisites" section to 002d noting these existing functions must remain unchanged or be adapted.

**Improvement C: Add Bash Version Requirement**

002d mentions `wait -n` requires Bash 4.3+ in Notes, but this should be elevated
to an acceptance criterion or documented in 002e's help output.

**Recommendation:** Add to 002e: "Help text includes Bash version requirement (4.3+) for streaming mode"

---

## Summary Table

| ID | Recommendation | Priority |
|----|----------------|----------|
| 002d | Keep as-is (integration point) | N/A |
| **NEW 002f** | Add error handling sub-issue | Medium |
| 002b | Clarify file append integration | Low |
| 002a/002c | Fix STREAM_INDEX scope documentation | Low |
| 002d | Add prerequisites section | Low |
| 002e | Add Bash version to help/acceptance criteria | Low |

---

## Suggested New Sub-Issue: 002f

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

--------------------------------------------------------------------------------
