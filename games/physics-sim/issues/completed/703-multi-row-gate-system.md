# 703 - Multi-Row Gate System with Value Multipliers

## Current Behavior

There is a single row of gates (ScoreZones) shared between player and adversary boards:

```c
// src/004-world.h
ScoreZone* zones;      // Array of score zones (shared)
int zone_count;        // Number of zones
Bumper* bumpers;       // Array of gate bumpers (top of zones)
Bumper* adversary_bumpers;  // Array of gate bumpers (bottom of zones)
```

All gates have point values assigned based on position (higher in center, lower at edges). There is no concept of gate rows or value multipliers.

## Intended Behavior

Multiple gate rows that separate stages, with configurable value multipliers:

**After purchasing stage 2:**
- Gate row 1: Below player stage 1 (1x multiplier - original gates)
- Gate row 2: Below player stage 2 / above adversary stage 2 (2x multiplier)
- Gate row 3: Below adversary stage 2 / above adversary stage 1 (1x multiplier)

**Gate row structure:**
- Each row has its own ScoreZone array
- Each row has top and bottom bumper arrays
- Each row has a value multiplier applied to base point values

**Scoring:**
- Player balls score when passing through gate rows going downward
- Adversary balls score when passing through gate rows going upward
- Points = base_points * row_multiplier

## Suggested Implementation Steps

### Step 1: Define GateRow struct

```c
// New in 004-world.h or 014-stage.h

typedef struct GateRow {
    float y_top;           // Top edge of gate row
    float y_bottom;        // Bottom edge of gate row
    float height;          // Gate row height

    ScoreZone* zones;      // Score zones for this row
    int zone_count;

    Bumper* bumpers_top;   // Bumpers on top edge (for balls falling down)
    Bumper* bumpers_bottom;// Bumpers on bottom edge (for balls rising up)
    int bumper_count;

    int value_multiplier;  // 1, 2, 3, etc.
} GateRow;
```

### Step 2: Update zone point calculation

```c
// Modify world_generate_zones or create gate_row_generate_zones
void gate_row_generate_zones(GateRow* row, int count, float width,
                             float table_x, int multiplier) {
    // Calculate base points (5, 10, 25, 50, 100, 50, 25, 10, 5 pattern)
    int base_points[] = {5, 10, 25, 50, 100, 50, 25, 10, 5};

    for (int i = 0; i < count; i++) {
        row->zones[i].points = base_points[i] * multiplier;
    }
    row->value_multiplier = multiplier;
}
```

### Step 3: Track gate rows in StageManager

```c
typedef struct StageManager {
    // ... stage arrays

    GateRow* gate_rows;    // All gate rows in order
    int gate_row_count;
} StageManager;
```

### Step 4: Update ball scoring logic

```c
// In ball_check_zone or equivalent
int ball_check_gate_rows(Ball* ball, GateRow* rows, int row_count,
                         int direction) {
    // direction: +1 for falling (player), -1 for rising (adversary)
    for (int r = 0; r < row_count; r++) {
        GateRow* row = &rows[r];

        // Check if ball crossed this row in correct direction
        if (ball_crossed_row(ball, row, direction)) {
            for (int z = 0; z < row->zone_count; z++) {
                if (ball_in_zone(ball, &row->zones[z])) {
                    return row->zones[z].points;  // Already includes multiplier
                }
            }
        }
    }
    return 0;
}
```

### Step 5: Render multiple gate rows

```c
void world_render_all_gate_rows(World* world) {
    if (!world->stages) {
        // Legacy single-row rendering
        world_render_zones(world);
        return;
    }

    for (int i = 0; i < world->stages->gate_row_count; i++) {
        gate_row_render(&world->stages->gate_rows[i]);
    }
}
```

### Step 6: Visual differentiation for multiplied gates

Gates with higher multipliers should be visually distinct:
- 2x gates: Brighter colors, possibly glow effect
- Zone text shows multiplied value

## Files to Modify

- `src/004-world.h` - Add GateRow struct
- `src/005-world.c` - Gate row generation and rendering
- `src/007-ball.c` - Multi-row scoring logic
- `src/014-stage.h` - Gate row tracking in StageManager

## Dependencies

- Issue 1002 (Stage system architecture)
- Issue 1003 (Dynamic world expansion)

## Testing

1. Verify base gates (1x) work as before
2. Verify 2x gates award double points
3. Verify both player and adversary balls score correctly
4. Verify visual distinction between gate rows
5. Verify bumper collisions work on all gate rows
