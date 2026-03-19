# 1002 - Stage System Architecture

## Current Behavior

The world has a fixed two-board layout:
- Player board (top): pegs in staggered grid
- Shared gates: single row of score zones with bumpers
- Adversary board (bottom): mirrored pegs

This structure is static and cannot be expanded at runtime. The World struct holds flat arrays for pegs, zones, and bumpers with no concept of "stages" or "levels" within a board.

```c
// src/004-world.h - current structure
typedef struct World {
    Peg* pegs;             // All player pegs in one array
    ScoreZone* zones;      // Single row of zones
    Bumper* bumpers;       // Single row of bumpers
    // ... adversary equivalents
} World;
```

## Intended Behavior

Introduce a Stage abstraction that encapsulates a discrete section of the board. Each player (and adversary) can have multiple stages stacked vertically. Stages can be added dynamically at runtime when the player purchases upgrades.

**Stage structure:**
- Each stage has its own peg array and obstacle array
- Stages are ordered (stage 1, stage 2, etc.)
- Player stages stack downward (stage 2 below stage 1)
- Adversary stages stack upward (stage 2 above stage 1, visually below player stage 2)
- Gate rows separate stages

**Stage types:**
- `STAGE_TYPE_PEGS` - Standard peg grid (current stage 1)
- `STAGE_TYPE_RAMPS` - Horizontal ramp obstacles (stage 2)
- Future types: bumper fields, spinner obstacles, etc.

## Suggested Implementation Steps

### Step 1: Define Stage struct

```c
// New in 004-world.h

typedef enum StageType {
    STAGE_TYPE_PEGS,   // Standard peg grid
    STAGE_TYPE_RAMPS,  // Horizontal ramps
    STAGE_TYPE_COUNT
} StageType;

typedef struct Stage {
    StageType type;
    float y_top;           // Top of this stage
    float y_bottom;        // Bottom of this stage
    float height;          // Stage height in pixels

    // Stage-specific obstacles
    Peg* pegs;             // Pegs (if STAGE_TYPE_PEGS)
    int peg_count;

    Ramp* ramps;           // Ramps (if STAGE_TYPE_RAMPS)
    int ramp_count;

    // Gate row at bottom of stage
    ScoreZone* gates;      // Gates below this stage
    int gate_count;
    Bumper* bumpers;       // Bumpers for these gates
    int bumper_count;
    int gate_value_multiplier;  // 1x, 2x, etc.
} Stage;
```

### Step 2: Define StageManager

```c
typedef struct StageManager {
    Stage* player_stages;      // Array of player stages (grows down)
    int player_stage_count;

    Stage* adversary_stages;   // Array of adversary stages (grows up)
    int adversary_stage_count;

    // Shared middle gates (between player and adversary stage 2s)
    ScoreZone* middle_gates;
    int middle_gate_count;
    Bumper* middle_bumpers_top;
    Bumper* middle_bumpers_bottom;
    int middle_bumper_count;
    int middle_gate_multiplier;
} StageManager;
```

### Step 3: Integrate with World

Add StageManager pointer to World, keeping backward compatibility:

```c
typedef struct World {
    // ... existing fields for legacy single-stage

    StageManager* stages;  // NULL initially, created when first upgrade purchased
} World;
```

### Step 4: Stage creation functions

```c
Stage* stage_create(StageType type, float width, float height);
void stage_destroy(Stage* stage);
void stage_generate_pegs(Stage* stage, int rows, int cols, float spacing);
void stage_generate_ramps(Stage* stage, /* ramp config */);
void stage_generate_gates(Stage* stage, int count, float zone_height, int multiplier);
```

### Step 5: StageManager functions

```c
StageManager* stage_manager_create(void);
void stage_manager_destroy(StageManager* manager);
void stage_manager_add_player_stage(StageManager* manager, StageType type);
void stage_manager_add_adversary_stage(StageManager* manager, StageType type);
```

## Files to Create

- `src/014-stage.h` - Stage and StageManager structures
- `src/015-stage.c` - Stage management implementation

## Files to Modify

- `src/004-world.h` - Add StageManager pointer
- `src/005-world.c` - Destroy StageManager on world cleanup

## Dependencies

None - this is the foundational issue for the stage system.

## Related Issues

- 1003 - Dynamic world vertical expansion
- 1004 - Multi-row gate system
- 1005 - Ramp obstacle type
