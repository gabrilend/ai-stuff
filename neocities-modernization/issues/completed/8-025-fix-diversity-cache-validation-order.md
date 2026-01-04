# Issue 8-025: Fix Diversity Cache Validation Order Bug

## Current Behavior

Running `./run.sh --generate-diversity` reports "Sequences to compute: 0" and generates an empty cache file, even when all embeddings are present.

Output shows:
```
📄 Poems: 7793
🧮 Embeddings: 7793 (dim=768)
...
🔢 Sequences to compute: 0
```

## Root Cause

In `scripts/precompute-diversity-sequences`, the code flow is:

1. Line 377: `embeddings_data = nil` (release after building effil.table)
2. Line 388-402: Loop to build `valid_poem_ids`, checks `elseif embeddings_data and ...`

Since `embeddings_data` is `nil` by the time the validation loop runs, the condition on line 395 always fails in production mode:

```lua
elseif embeddings_data and embeddings_data.embeddings[i] and embeddings_data.embeddings[i].embedding then
```

## Fix

Move the `valid_poem_ids` construction loop to run BEFORE `embeddings_data` is released (before line 376).

## Secondary Issue: Thread Count Not Passed

`run.sh` exports `DIVERSITY_THREADS` but the script reads threads from `arg[2]`. Either:
- Add CLI argument passthrough in run.sh, OR
- Have the script read the environment variable

## Files Modified

| File | Change |
|------|--------|
| `scripts/precompute-diversity-sequences` | Move validation loop before embeddings_data release |
| `run.sh` | Pass --threads to precompute-diversity-sequences |

---

**Phase**: 8 (Website Completion)

**Priority**: High (blocking diversity cache generation)

**Created**: 2026-01-04

**Completed**: 2026-01-04

**Status**: Completed

**Type**: Bug Fix
