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

- [x] `QUEUE_DIR`, `QUEUE_COUNTER`, `STREAM_INDEX`, `STREAMER_PID` variables exist
- [x] `setup_queue()` creates temp directory and initializes counters
- [x] `cleanup_queue()` removes temp directory and kills streamer
- [x] Exit trap ensures cleanup on script termination
- [x] Can be called multiple times without error

---

## Notes

*This sub-issue was auto-generated from analysis recommendations.*
This is the foundation that 002b and 002c both depend on.

---

## Implementation Notes

*Completed 2025-12-16*

### Changes Made

1. Added Queue Configuration section at lines 65-70 in issue-splitter.sh:
   - `QUEUE_DIR=""` - temp directory path
   - `QUEUE_COUNTER=0` - slot numbering for queue items
   - `STREAM_INDEX=0` - streamer position tracking
   - `STREAMER_PID=""` - background streamer process ID

2. Added `setup_queue()` function (lines 72-79):
   - Creates temp directory via `mktemp -d`
   - Resets all counters to initial state
   - Clears STREAMER_PID

3. Added `cleanup_queue()` function (lines 81-95):
   - Kills streamer process if running (with proper wait)
   - Removes temp directory recursively
   - Resets variables to empty (idempotent)

4. Added exit trap (line 98):
   - Triggers cleanup on EXIT, INT, TERM signals

### Testing

Created `src/tests/test_002a_queue_infrastructure.sh` which verifies:
- setup_queue creates valid temp directory
- cleanup_queue removes directory
- Multiple cleanup calls don't error (idempotent)
- Each setup creates unique directory

All tests pass.
