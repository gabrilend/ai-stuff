# 1002 - Gate Rendering/Scoring Position Mismatch

## Status: Complete

## Current Behavior

Gates render at a different Y position than their scoring zones. The visual gate appears below where balls actually score.

## Root Cause

Two separate systems used different position calculations:

1. **World zones (world.c)** - Used for rendering
   - Used `world->table_bottom + 50` (gate_margin) as zone_y_min

2. **ZoneGrid (zone-dispatch.c)** - Used for scoring
   - Uses `world->table_top + gate_row * cell_size`
   - `gate_row = (int)((table_bottom - table_top) / cell_size)`

The 50px `gate_margin` caused rendering to be 50 pixels below the scoring zone.

## Resolution

Modified `world_generate_zones()` to use the same grid-aligned formula as `zone_grid_set_gate_row()`:

```c
// Before (misaligned):
float gate_margin = 50.0f;
float zone_y_min = world->table_bottom + gate_margin;

// After (aligned with zone_grid - issue 1002):
float cell_size = DEFAULT_GRID_CELL_SIZE;
int gate_row = (int)((world->table_bottom - world->table_top) / cell_size);
float zone_y_min = world->table_top + gate_row * cell_size;
```

Now both rendering and scoring use the same grid-aligned position calculation.

## Files Modified

- `src/005-world.c` - Added grid.h include, unified zone position calculation

## Related Issues

- Issue 1001b: Coordinate system unification
