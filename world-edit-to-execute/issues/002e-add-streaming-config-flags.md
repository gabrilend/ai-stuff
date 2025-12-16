# Issue 002e: Add Streaming Config Flags

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 002
**Priority:** Medium
**Dependencies:** 002d

---

## Current Behavior

The issue-splitter.sh script has no configuration options for parallel processing or streaming output delays.

---

## Intended Behavior

Add command-line flags to control streaming behavior:

1. **`--parallel N`** - Set max concurrent Claude calls (default: 3)
2. **`--delay N`** - Set seconds between streamed outputs (default: 5)
3. **`--no-stream`** - Disable streaming, use sequential processing

---

## Suggested Implementation Steps

### 1. Add Configuration Variables

```bash
# In Configuration section:
PARALLEL_COUNT=3
STREAM_DELAY=5
STREAM_MODE=true
```

### 2. Add Argument Parsing

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

### 3. Update Help Text

```bash
#   --parallel <n>        Max concurrent Claude calls (default: 3)
#   --delay <n>           Seconds between streamed outputs (default: 5)
#   --no-stream           Disable streaming, process sequentially
```

### 4. Conditional Processing in Main

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
