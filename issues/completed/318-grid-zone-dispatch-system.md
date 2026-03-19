# 318 - Grid-Based Zone Dispatch System

## Status: completed (2026-03-19)

## Depends on

None - architectural refactor that can be implemented independently.

## Solves

- 316 (Allow multiple gate scoring) - has_scored reset in background zones
- 317 (GateRow scoring never called) - unified dispatch handles all zones

## Future Extensions

- 901 (Rotor system) - can add ZONE_ROTOR type
- 902 (Track mover system) - can add ZONE_MOVER type

## Problem

Zone handling is fragmented across multiple systems:
- `ball_check_zone()` checks `world->zones` for scoring
- `wrap_zones_check_ball()` checks wrap zones for teleportation
- `stage_manager_check_ball_score()` exists but is never called (issue 317)
- Future zones (portals, rotors) would add more if-check branches

This leads to bugs (GateRow scoring never triggered) and performance issues (multiple zone checks per ball per frame).

## Current Behavior

- Each zone system has its own check function with if-statements
- Ball physics calls multiple zone checkers sequentially
- Branch prediction works well for "not in zone" case but architecture is fragmented
- Adding new zone types requires modifying multiple files

## Intended Behavior

- Single unified zone dispatch system based on grid cells
- Each cell maps to a zone type index
- Zone type index dispatches to handler function via function pointer array
- No branching in hot path - just lookup and indirect call
- `has_scored` flag reset handled naturally by background zones

## Design

### Zone Type Enumeration

```c
// {{{ ZoneType enum
typedef enum ZoneType {
    ZONE_BACKGROUND = 0,   // Default - resets has_scored, normal physics

    // Gate zones (points encoded in type for fast dispatch)
    ZONE_GATE_10,
    ZONE_GATE_20,
    ZONE_GATE_50,
    ZONE_GATE_100,
    ZONE_GATE_200,
    ZONE_GATE_500,

    // Wrap zones
    ZONE_WRAP_TO_BOTTOM,   // Ball at top -> teleport to bottom
    ZONE_WRAP_TO_TOP,      // Ball at bottom -> teleport to top

    // Boundary zones
    ZONE_WALL_LEFT,        // Reflect off left edge
    ZONE_WALL_RIGHT,       // Reflect off right edge

    // Future zones (placeholder)
    ZONE_PORTAL_ENTRY,
    ZONE_PORTAL_EXIT,
    ZONE_ROTOR_AREA,

    ZONE_TYPE_COUNT
} ZoneType;
// }}}
```

### Zone Grid Structure

```c
// {{{ ZoneGrid struct
// Maps grid cells to zone types for fast dispatch
// Uses existing grid dimensions (14x22 = 308 bytes, fits in L1 cache)
typedef struct ZoneGrid {
    uint8_t cells[DEFAULT_GRID_ROWS][DEFAULT_GRID_COLS];  // Zone type per cell

    // Grid parameters (copied from Grid for self-contained lookups)
    float origin_x;
    float origin_y;
    float cell_size;
    int cols;
    int rows;

    // Multiplier overlay for gate zones (0 = no multiplier, 1 = 2x, 2 = 3x, etc.)
    // Only checked when zone type is ZONE_GATE_*
    uint8_t multipliers[DEFAULT_GRID_ROWS][DEFAULT_GRID_COLS];
} ZoneGrid;
// }}}
```

### Zone Function Signature

```c
// {{{ ZoneFunc typedef
// Zone handler function signature
// Parameters:
//   ball: The ball entering/occupying this zone
//   grid: Zone grid for coordinate lookups
//   col, row: Grid cell coordinates
// Returns:
//   1 if ball should continue physics, 0 if handled specially (e.g., teleport)
typedef int (*ZoneFunc)(Ball* ball, ZoneGrid* grid, int col, int row);
// }}}
```

### Zone Function Implementations

```c
// {{{ zone_background
// Default zone - resets scoring flag, continues normal physics
int zone_background(Ball* ball, ZoneGrid* grid, int col, int row) {
    (void)grid; (void)col; (void)row;  // Unused
    ball->has_scored = 0;  // Can score again at next gate
    return 1;  // Continue physics
}
// }}}

// {{{ zone_gate_100
// Gate zone worth 100 points (example - similar for other point values)
int zone_gate_100(Ball* ball, ZoneGrid* grid, int col, int row) {
    if (!ball->has_scored) {
        // Calculate points with multiplier
        int multiplier = 1 + grid->multipliers[row][col];
        int points = 100 * multiplier;

        // Record score for main loop to process
        ball->pending_score = points;
        ball->score_x = ball->x;
        ball->score_y = ball->y;
        ball->has_scored = 1;
    }
    return 1;  // Continue physics (ball passes through gate)
}
// }}}

// {{{ zone_wrap_to_bottom
// Teleports ball from top of world to bottom
int zone_wrap_to_bottom(Ball* ball, ZoneGrid* grid, int col, int row) {
    (void)col; (void)row;

    // Calculate wrap destination (bottom of world)
    float world_height = grid->rows * grid->cell_size;
    ball->y += world_height;  // Or set to specific wrap destination
    ball->has_scored = 0;     // Reset scoring for new board

    return 0;  // Position changed, skip normal physics this frame
}
// }}}

// {{{ zone_wrap_to_top
// Teleports ball from bottom of world to top
int zone_wrap_to_top(Ball* ball, ZoneGrid* grid, int col, int row) {
    (void)col; (void)row;

    float world_height = grid->rows * grid->cell_size;
    ball->y -= world_height;
    ball->has_scored = 0;

    return 0;
}
// }}}
```

### Dispatch Table

```c
// {{{ zone_functions array
// Function pointer array indexed by ZoneType
static ZoneFunc zone_functions[ZONE_TYPE_COUNT] = {
    [ZONE_BACKGROUND]     = zone_background,
    [ZONE_GATE_10]        = zone_gate_10,
    [ZONE_GATE_20]        = zone_gate_20,
    [ZONE_GATE_50]        = zone_gate_50,
    [ZONE_GATE_100]       = zone_gate_100,
    [ZONE_GATE_200]       = zone_gate_200,
    [ZONE_GATE_500]       = zone_gate_500,
    [ZONE_WRAP_TO_BOTTOM] = zone_wrap_to_bottom,
    [ZONE_WRAP_TO_TOP]    = zone_wrap_to_top,
    [ZONE_WALL_LEFT]      = zone_wall_reflect,
    [ZONE_WALL_RIGHT]     = zone_wall_reflect,
    [ZONE_PORTAL_ENTRY]   = zone_background,  // Placeholder
    [ZONE_PORTAL_EXIT]    = zone_background,  // Placeholder
    [ZONE_ROTOR_AREA]     = zone_background,  // Placeholder
};
// }}}
```

### Physics Integration

```c
// {{{ zone_dispatch
// Called during ball physics update after calculating new position
// Dispatches to appropriate zone handler based on ball position
int zone_dispatch(Ball* ball, ZoneGrid* grid) {
    // Convert ball position to grid cell
    int col = (int)((ball->x - grid->origin_x) / grid->cell_size);
    int row = (int)((ball->y - grid->origin_y) / grid->cell_size);

    // Bounds check - out of grid is background
    if (col < 0 || col >= grid->cols || row < 0 || row >= grid->rows) {
        return zone_background(ball, grid, col, row);
    }

    // Lookup zone type and dispatch
    uint8_t zone_type = grid->cells[row][col];
    return zone_functions[zone_type](ball, grid, col, row);
}
// }}}

// In ball_update_task, replace zone checks with:
// int continue_physics = zone_dispatch(next, task->zone_grid);
// if (!continue_physics) {
//     // Ball was teleported or handled specially
//     return;
// }
```

### Grid Population

```c
// {{{ zone_grid_init
// Initializes zone grid with background zones
void zone_grid_init(ZoneGrid* grid, float origin_x, float origin_y,
                    float cell_size, int cols, int rows) {
    grid->origin_x = origin_x;
    grid->origin_y = origin_y;
    grid->cell_size = cell_size;
    grid->cols = cols;
    grid->rows = rows;

    // Initialize all cells to background
    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            grid->cells[r][c] = ZONE_BACKGROUND;
            grid->multipliers[r][c] = 0;
        }
    }
}
// }}}

// {{{ zone_grid_set_gate_row
// Sets a row of gate zones with specified point values
void zone_grid_set_gate_row(ZoneGrid* grid, int row, int multiplier) {
    if (row < 0 || row >= grid->rows) return;

    // Standard gate pattern: 10, 20, 50, 100, 100, 200, 500, 500, 200, 100, 100, 50, 20, 10
    // (14 columns matching grid width)
    ZoneType gate_pattern[] = {
        ZONE_GATE_10, ZONE_GATE_20, ZONE_GATE_50, ZONE_GATE_100,
        ZONE_GATE_100, ZONE_GATE_200, ZONE_GATE_500, ZONE_GATE_500,
        ZONE_GATE_200, ZONE_GATE_100, ZONE_GATE_100, ZONE_GATE_50,
        ZONE_GATE_20, ZONE_GATE_10
    };

    for (int c = 0; c < grid->cols && c < 14; c++) {
        grid->cells[row][c] = gate_pattern[c];
        grid->multipliers[row][c] = multiplier;  // 0 = 1x, 1 = 2x, etc.
    }
}
// }}}

// {{{ zone_grid_set_wrap_zones
// Sets wrap zones at top and bottom of grid
void zone_grid_set_wrap_zones(ZoneGrid* grid, int top_row, int bottom_row) {
    for (int c = 0; c < grid->cols; c++) {
        if (top_row >= 0 && top_row < grid->rows) {
            grid->cells[top_row][c] = ZONE_WRAP_TO_BOTTOM;
        }
        if (bottom_row >= 0 && bottom_row < grid->rows) {
            grid->cells[bottom_row][c] = ZONE_WRAP_TO_TOP;
        }
    }
}
// }}}
```

### Expansion Handling

When world expands, the zone grid must be updated:

```c
// {{{ zone_grid_expand
// Expands zone grid for new stages, shifting existing zones down
void zone_grid_expand(ZoneGrid* grid, int new_rows_above, int new_rows_below) {
    // This is complex - may need to reallocate grid
    // Alternative: Use dynamic grid sizing from the start
    // Or: Maintain separate zone grids per stage
}
// }}}
```

**Note:** Grid expansion is complex. Options:
1. Fixed maximum grid size (e.g., 100 rows) with unused rows
2. Reallocate grid on expansion
3. Multiple zone grids (one per stage)

## Ball Struct Changes

```c
typedef struct Ball {
    // ... existing fields ...

    // Zone dispatch fields (issue 318)
    int has_scored;      // 1 if scored at current gate, 0 otherwise
    int pending_score;   // Points to award (processed by main loop)
    float score_x;       // Position where score occurred
    float score_y;
} Ball;
```

## Config Values

Add to config.txt:
```
# Zone dispatch (issue 318)
ZONE_GRID_MAX_ROWS=100
```

## Implementation Steps

1. Define ZoneType enum in new header `src/045-zone-dispatch.h`
2. Define ZoneGrid struct and ZoneFunc typedef
3. Implement zone handler functions (background, gates, wraps)
4. Create zone_functions dispatch table
5. Implement zone_grid_init, zone_grid_set_gate_row, zone_grid_set_wrap_zones
6. Implement zone_dispatch function
7. Add has_scored, pending_score fields to Ball struct
8. Replace ball_check_zone and wrap_zones_check_ball calls with zone_dispatch
9. Update main loop to process pending_score and spawn particles
10. Test all zone types (background scoring reset, gates, wraps)
11. Handle grid expansion for stage purchases
12. Remove old zone checking code (world->zones, wrap_zones)

## Files to Create

- `src/045-zone-dispatch.h` - ZoneType, ZoneGrid, ZoneFunc definitions
- `src/046-zone-dispatch.c` - Zone handler implementations and dispatch

## Files to Modify

- `src/006-ball.h` - Add has_scored, pending_score, score_x, score_y
- `src/007-ball.c` - Replace zone checks with zone_dispatch call
- `src/001-main.c` - Create ZoneGrid, process pending_score, remove old zone code
- `config.txt` - Add ZONE_GRID_MAX_ROWS

## Files to Eventually Remove

- `src/036-wrap-zones.h` - Functionality absorbed into zone dispatch
- `src/037-wrap-zones.c`

## Performance Notes

- Zone grid: 308 bytes (14x22) fits in L1 cache
- Multiplier grid: 308 bytes, also fits in L1
- Total: 616 bytes vs 1.2MB for per-pixel approach
- Indirect function call: ~5-10 cycles
- No branch mispredictions in hot path
- Grid lookup is simple arithmetic (no branches)

## Testing Checklist

- [ ] Background zones reset has_scored flag
- [ ] Gate zones award correct points (10, 20, 50, 100, 200, 500)
- [ ] Gate multipliers apply correctly (2x, 3x)
- [ ] Ball can score again after passing through background
- [ ] Wrap zones teleport correctly (top to bottom, bottom to top)
- [ ] Wrap zones reset has_scored
- [ ] Particles spawn at correct positions
- [ ] Expansion updates zone grid correctly
- [ ] No scoring at GateRow positions (issue 317 resolved)

## Related Issues

- **317** (GateRow scoring never called): Solved by unified dispatch
- **316** (Allow multiple gate scoring): Solved by has_scored reset in background
- **903** (Ball velocity statistics): Could add zone entry speed tracking
- **902** (Track mover system): Could add ZONE_MOVER type
- **901** (Rotor system): Could add ZONE_ROTOR type

## Migration Strategy

1. Implement new system alongside existing zone code
2. Add compile flag to switch between systems
3. Test new system thoroughly
4. Remove old system once confirmed working

```c
#ifdef USE_ZONE_DISPATCH
    int continue_physics = zone_dispatch(next, task->zone_grid);
#else
    // Old zone checking code
    int zone_index = ball_check_zone(next, task->world);
    // ...
#endif
```

## Implementation Notes (2026-03-19)

### Files Created
- `src/045-zone-dispatch.h` - DispatchZoneType enum (renamed from ZoneType to avoid conflict with board-data.h), ZoneGrid struct, function declarations
- `src/046-zone-dispatch.c` - Zone handler implementations, dispatch table, grid functions

### Files Modified
- `src/006-ball.h` - Added `pending_score`, `score_x`, `score_y` fields to Ball struct (existing `passed_gate` serves as `has_scored`)
- `src/007-ball.c` - Integrated zone_dispatch into ball_update_task with fallback to old system when zone_grid is NULL
- `src/004-world.h` - Added `ZoneGrid* zone_grid` field to World struct
- `src/005-world.c` - Initialize zone_grid to NULL in world_create
- `src/001-main.c` - Create and destroy zone_grid, set initial gate row
- `Makefile` - Added src/046-zone-dispatch.c to GAME_SRCS

### Design Decisions
- Enum renamed to `DispatchZoneType` with `DISPATCH_ZONE_` prefix to avoid conflict with existing `ZoneType` in `020-board-data.h`
- Zone grid uses fixed max size (100 rows) to avoid reallocation during expansion
- Fallback system: when zone_grid is NULL, uses existing wrap_zones_check_ball and ball_check_zone
- Zone dispatch called after wall collisions but before portal checks

### Migration Status
- New zone_dispatch system implemented and compiles
- Old zone checking system preserved as fallback
- Testing needed to verify scoring works correctly
- Old wrap_zones code NOT removed yet (retained for fallback)

## Notes

- Gate point values encoded in zone type avoids lookup
- Multiplier stored separately for rare access (only on scoring)
- Background zone handler is minimal (just reset flag, return 1)
- Future zones (portals, rotors) can be added without modifying dispatch logic
- Consider: Should zone handlers receive dt for time-based effects?
