# Issue 10-028: Lower Pipeline Process Priority for UI Responsiveness

## Status
- **Phase**: 10
- **Priority**: Low
- **Type**: Enhancement (Quick Win)
- **Status**: Open
- **Created**: 2026-03-18

## Current Behavior

When the pipeline runs compute-heavy operations (embedding generation, similarity matrix computation, HTML generation), the system becomes sluggish. The OS scheduler gives equal priority to pipeline threads and UI/desktop applications, causing:

- Mouse lag and stuttering
- Terminal input delays
- Desktop responsiveness degradation
- Poor user experience during long-running operations

This is particularly noticeable during:
- GPU similarity computation
- Diversity cache generation
- Parallel HTML generation

## Intended Behavior

Pipeline processes should run at a lower scheduling priority (higher nice value), allowing the OS to prioritize UI threads. The pipeline takes slightly longer but the system remains responsive.

Benefits:
- Smoother desktop experience during pipeline runs
- Terminal remains responsive for monitoring
- User can continue other work while pipeline executes

## Suggested Implementation Steps

### Option A: Nice Value at Script Level (Simplest)

Wrap the main pipeline invocation with `nice`:

```bash
# In run.sh or phase-demo.sh
nice -n 10 lua src/main.lua "$@"
```

Nice values range from -20 (highest priority) to 19 (lowest). A value of 10-15 is reasonable for background work.

### Option B: Ionice for I/O Priority (For I/O-bound stages)

```bash
# Lower both CPU and I/O priority
nice -n 10 ionice -c 3 lua src/main.lua "$@"
```

`ionice -c 3` sets "idle" class - only uses I/O when system is otherwise idle.

### Option C: Configurable via CLI Flag

```bash
# Add --background or --low-priority flag
./run.sh --low-priority --generate

# Implementation in run.sh:
if [[ "$*" == *"--low-priority"* ]]; then
    NICE_PREFIX="nice -n 15"
else
    NICE_PREFIX=""
fi
$NICE_PREFIX lua src/main.lua "$@"
```

### Option D: Auto-Detect Heavy Operations

The pipeline could automatically lower priority when entering compute-heavy stages:

```lua
-- In similarity-engine.lua or main.lua
local function set_low_priority()
    os.execute("renice -n 15 -p " .. tostring(require("ffi").C.getpid()))
end
```

Note: `renice` requires the process to already be running.

## Files to Modify

- `run.sh` - Main entry point (Option A/B/C)
- `scripts/phase-demo.sh` - Demo runner
- `scripts/precompute-diversity-sequences-gpu` - Heavy GPU work
- `src/main.lua` - For Option D auto-detection

## Testing Checklist

- [ ] Run pipeline with `nice -n 10` prefix
- [ ] Verify desktop remains responsive during GPU computation
- [ ] Verify terminal input is not delayed
- [ ] Measure execution time impact (should be minimal, <5%)
- [ ] Test with and without ionice

## Related Issues

- 10-001: TUI integration (affected by responsiveness)
- 9-001: Vulkan compute infrastructure (heavy GPU work)
- 9-003: Centroid calculation parallelization (CPU-heavy)

## Notes

This is a "quick win" - minimal code change with immediate UX improvement. The `nice` command is standard on all Unix systems and requires no dependencies.

For Windows users (if relevant), similar functionality exists via `start /low` or PowerShell's `Start-Process -Priority BelowNormal`.

---

## Implementation Log

**2026-03-18: COMPLETED**

Implemented Option C (configurable via CLI flag) in `run.sh`:

1. Added `LOW_PRIORITY=false` flag variable (line 171)
2. Added `--low-priority` CLI flag handler (lines 273-276)
3. Added help text explaining the flag (lines 103-104)
4. Set up `NICE_PREFIX` variable after argument parsing (lines 475-481)
5. Applied `$NICE_PREFIX` to all heavy operations:
   - Stage 6: `generate-embeddings.sh` and word embeddings generation
   - Stage 8: GPU and CPU diversity cache generation
   - Stage 9: HTML generation, word cloud, and word pages

**Usage**: `./run.sh --low-priority --generate-html`

When `--low-priority` is set, all compute-heavy stages run with `nice -n 10`, allowing the OS scheduler to prioritize UI/desktop responsiveness.

**Status**: ✅ COMPLETED
