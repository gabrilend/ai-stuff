# Issue 002a: Add Queue Infrastructure

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** None (within 002)

---

## Current Behavior

The issue-splitter.sh script has no queue system - it processes issues strictly sequentially with no parallel processing capability.

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

### 1. Add Queue Variables to Configuration

```bash
# {{{ Queue Configuration
QUEUE_DIR=""
QUEUE_COUNTER=0
STREAM_INDEX=0
STREAMER_PID=""
# }}}
```

### 2. Create Setup Function

```bash
# {{{ setup_queue
setup_queue() {
    QUEUE_DIR=$(mktemp -d)
    QUEUE_COUNTER=0
    STREAM_INDEX=0
}
# }}}
```

### 3. Create Cleanup Function

```bash
# {{{ cleanup_queue
cleanup_queue() {
    [[ -n "$STREAMER_PID" ]] && kill "$STREAMER_PID" 2>/dev/null
    [[ -d "$QUEUE_DIR" ]] && rm -rf "$QUEUE_DIR"
}
# }}}
```

### 4. Add Exit Trap

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
