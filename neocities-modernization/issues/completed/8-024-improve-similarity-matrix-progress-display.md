# Issue 8-024: Improve Similarity Matrix Progress Display

## Current Behavior

The similarity matrix generation prints every single "Processing poem" line:

```
[INFO] Processing poem 901/7793 (ID: 960)
[INFO] Processing poem 902/7793 (ID: 961)
[INFO] Processing poem 903/7793 (ID: 962)
... (thousands of lines)
```

This floods the terminal with 7,793 lines of output, making it hard to see the important progress percentage updates.

## Intended Behavior

- "Processing poem X/Y" lines should overwrite each other in-place using carriage return
- "Progress: X%" lines should remain as permanent log entries
- Cleaner, more readable output during long-running matrix generation

Expected output:
```
[INFO] Progress: 10.0% (3036152/30361528 comparisons)
[INFO] Processing poem 800/7793 (ID: 850)     <- This line updates in-place
[INFO] Progress: 20.0% (6072305/30361528 comparisons)
```

## Implementation

1. Replace `utils.log_info()` with `io.write()` + `\r` for "Processing poem" lines
2. Add `io.flush()` to ensure immediate display
3. Print a newline before "Progress:" lines to preserve them
4. Clear the line with spaces to prevent leftover characters

## Files Modified

| File | Change |
|------|--------|
| `src/similarity-engine.lua` | Modified progress display in two functions |

---

**Phase**: 8 (Website Completion)

**Priority**: Low (cosmetic improvement)

**Created**: 2026-01-04

**Completed**: 2026-01-04

**Status**: Completed

**Type**: Enhancement
