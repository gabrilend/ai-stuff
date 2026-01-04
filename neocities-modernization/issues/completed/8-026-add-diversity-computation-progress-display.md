# Issue 8-026: Add Diversity Computation Progress Display

## Current Behavior

The diversity pre-computation shows minimal feedback during batch processing:

```
Batch 1: sequences 1-16
```

Then nothing until the entire batch completes (can take 10+ minutes per batch). Users have no visibility into whether work is happening.

## Intended Behavior

Display real-time progress for each thread in the batch:

```
Batch 1: sequences 1-16
   [1] 450/1500  [2] 423/1500  [3] 489/1500  [4] 401/1500
   [5] 512/1500  [6] 478/1500  [7] 445/1500  [8] 467/1500
   ...
```

Or a condensed single-line display:

```
Batch 1: [####------] 412/1500 avg | T1:450 T2:423 T3:489 ... | 2m15s elapsed
```

## Implementation

1. Create shared effil.table for progress: `progress[thread_idx] = iteration_count`
2. Workers update their slot every N iterations (e.g., every 10)
3. Main thread uses `effil.thread:wait(timeout)` instead of blocking `get()`
4. Poll progress table and refresh display every 500ms

## Technical Notes

- effil.table is thread-safe and can be written from workers, read from main
- Use `\r` to overwrite progress line without newlines
- Non-blocking wait: `thread:wait(500)` returns true if done, false if timeout

---

**Phase**: 8 (Website Completion)

**Priority**: Low (UX improvement)

**Created**: 2026-01-04

**Completed**: 2026-01-04

**Status**: Completed

**Type**: Enhancement
