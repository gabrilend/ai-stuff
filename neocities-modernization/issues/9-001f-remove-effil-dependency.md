# Issue 9-001f: Remove effil Dependency

## Parent Issue
9-001: Implement Vulkan Compute Infrastructure

## Current Behavior
The project uses effil library for multi-threading in:
- `scripts/generate-html-parallel` - HTML page generation
- `scripts/precompute-diversity-sequences` - Diversity sequence pre-computation

effil proved unsuitable due to catastrophic performance with shared table access (~17 billion synchronization operations per sequence).

## Intended Behavior
- All effil usage replaced with either:
  - Vulkan GPU compute (for vector operations)
  - Process-based parallelism (for I/O-bound operations like HTML generation)
- effil library removed from project dependencies
- package.cpath no longer references effil

## Implementation Steps

### Step 1: Audit effil Usage
- [ ] List all files that import effil
- [ ] Categorize by operation type (vector math vs I/O)

### Step 2: Replace Diversity Pre-computation
- [ ] Port to Vulkan compute (via 9-001d)
- [ ] Update `scripts/precompute-diversity-sequences` to use Vulkan

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
