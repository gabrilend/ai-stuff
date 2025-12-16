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
