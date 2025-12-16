# Issue 002b: Add Producer Function

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** 002a

---

## Current Behavior

The issue-splitter.sh script calls Claude directly and waits for the response before continuing. There is no mechanism to queue responses for later display.

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

### 1. Create Producer Function

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

### 2. Queue File Format

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

- [x] `queue_claude_response()` function exists
- [x] Function increments `QUEUE_COUNTER` atomically
- [x] Creates `.output` file with Claude response
- [x] Creates `.meta` file with issue path and status
- [x] Creates `.ready` file only after completion (atomic signal)
- [x] Handles Claude timeout gracefully (marks as failed)

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
The `.ready` file pattern ensures the streamer never reads incomplete output.

---

## Implementation Notes

*Completed 2025-12-16*

### Changes Made

Added `queue_claude_response()` function at lines 100-121 in issue-splitter.sh:
- Takes issue_path and prompt as arguments
- Assigns queue slot number via `$((QUEUE_COUNTER++))`
- Creates three files per slot:
  - `{N}.output` - Claude's response text
  - `{N}.meta` - Line 1: issue path, Line 2: "success" or "failed"
  - `{N}.ready` - Empty file, signals completion (atomic)
- Uses `timeout 300` for 5-minute limit on Claude calls
- Marks as "failed" if timeout or error occurs

### Testing

Created `src/tests/test_002b_producer_function.sh` which verifies:
- All three queue files are created
- Output file contains correct response
- Meta file contains path and status
- Counter increments correctly across calls
- Failure status recorded when command fails

All tests pass (using mock claude command).
