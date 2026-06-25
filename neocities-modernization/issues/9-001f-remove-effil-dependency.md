# Issue 9-001f: Remove effil Dependency

## Parent Issue
9-001: Implement Vulkan Compute Infrastructure

## Current Behavior
effil proved unsuitable due to catastrophic performance with shared table access
(~17 billion synchronization operations per sequence).

PARTIALLY REMOVED (via Issue 10-057's GPU-only / cache-cap work). effil is now gone
from the entire SIMILARITY path:
- `src/similarity-engine-parallel.lua` (the CPU similarity engine) was DELETED.
- `libs/vulkan-compute/lua/vk_similarity.lua` no longer requires effil at all -- the
  CPU-sort helpers (`create_sort_write_task`, `generate_rankings_cache`,
  `load_similarities_from_files`) and the `package.cpath`/`require('effil')` block were
  removed; similarity is GPU-only.
- the CPU `scripts/precompute-diversity-sequences` was DELETED (GPU is mandatory now);
  the GPU `precompute-diversity-sequences-gpu` is the only diversity generator.

STILL USING effil (the remaining work, all HTML-generation threading -- this issue's
Step 3):
- `src/flat-html-generator.lua` - the parallel HTML orchestrator (effil workers).
- `scripts/generate-html-parallel` - the standalone parallel HTML script.
- `run.sh` - the effil `package.cpath` setup for the above.

So `grep -r effil src/ scripts/` still returns results; the QA criterion is not yet met.

## Intended Behavior
- All effil usage replaced with either:
  - Vulkan GPU compute (for vector operations)
  - Process-based parallelism (for I/O-bound operations like HTML generation)
- effil library removed from project dependencies
- package.cpath no longer references effil

## Implementation Steps

### Step 1: Audit effil Usage ✅ COMPLETED (2026-03-18)
- [x] List all files that import effil
- [x] Categorize by operation type (vector math vs I/O)

**Active Runtime Files Using effil:**
| File | Lines | Usage Type |
|------|-------|------------|
| `src/flat-html-generator.lua` | 41-48, 3153-4203 | Parallel HTML generation |
| `src/similarity-engine-parallel.lua` | 24-57, 165-681 | Parallel validation/processing |
| `scripts/generate-html-parallel` | 64-1614 | Full parallel HTML script |
| `run.sh` | 970 | cpath setup |

**Documentation/Install Files (keep for reference):**
- `docs/effil-usage-patterns.md` - Usage guide
- `docs/effil-vs-compute-shader-feasibility.md` - Feasibility analysis
- `scripts/install-deps.sh` - Installation script
- Various issue files documenting history

### Step 2: Replace Diversity Pre-computation ✅ COMPLETED (via 9-001d, 9-001g)
- [x] Port to Vulkan compute (via 9-001d)
- [x] Update `scripts/precompute-diversity-sequences` to use Vulkan
- Created `scripts/precompute-diversity-sequences-gpu` which replaces CPU effil approach

### Step 3: Replace HTML Generation Threading
- [ ] Convert to process-based parallelism (fork + merge)
- [ ] Or single-threaded with progress (HTML gen is I/O-bound, not compute-bound)
- [ ] Update `scripts/generate-html-parallel`

### Step 4: Remove effil References
- [ ] Remove `package.cpath` additions for effil
- [ ] Remove `require("effil")` statements
- [ ] Update documentation

### Step 5: Verify No Regressions
- [ ] Run full HTML generation pipeline
- [ ] Compare output to previous effil-based output
- [ ] Confirm no effil.so in any load path

## Files to Modify

| File | Current Usage | Replacement |
|------|---------------|-------------|
| `scripts/generate-html-parallel` | effil.thread for page generation | Process-based or single-threaded |
| `scripts/precompute-diversity-sequences` | effil.thread + effil.table | Vulkan compute |

## Quality Assurance Criteria

- [ ] `grep -r "effil" src/ scripts/` returns no results
- [ ] HTML generation produces identical output
- [ ] Diversity sequences match previous results
- [ ] No runtime errors about missing effil

## Dependencies

- 9-001e (Lua/C integration for Vulkan)
- Alternative: Process-based parallelism implementation

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-14

**Phase**: 9 (GPU Acceleration)

**Priority**: Low (after GPU infrastructure complete)
