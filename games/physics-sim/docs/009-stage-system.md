# 009 - Stage System

## Overview

The stage system enables dynamic board expansion during gameplay. Players
can purchase additional stages that extend the board vertically, adding
new obstacle types and scoring opportunities.

## Architecture

### Core Concepts

**Stage**: A discrete section of the board containing obstacles (pegs or
ramps). Stages stack vertically and are separated by gate rows.

**Gate Row**: A row of scoring gates between stages. Each gate row has a
value multiplier that increases with depth (2x, 3x, etc.).

**Stage Manager**: Central coordinator that tracks all stages and gate
rows for both player and adversary.

### Data Structures

```c
// {{{ typedef struct Stage
typedef struct Stage {
    StageType type;        // PEGS, RAMPS, or CUSTOM
    float y_top, y_bottom; // Vertical bounds
    float height;

    // Obstacles (one type per stage)
    Peg* pegs;
    int peg_count;
    Ramp* ramps;
    int ramp_count;
} Stage;
// }}}

// {{{ typedef struct GateRow
typedef struct GateRow {
    float y_top, y_bottom;
    ScoreZone* zones;
    int zone_count;
    Bumper* bumpers_top;    // Deflect falling balls
    Bumper* bumpers_bottom; // Deflect rising balls
    int value_multiplier;   // Applied to base zone points
} GateRow;
// }}}
```

## Stage Types

| Type | Description | Obstacles |
|------|-------------|-----------|
| STAGE_TYPE_PEGS | Standard peg grid | Staggered peg arrangement |
| STAGE_TYPE_RAMPS | Horizontal ramps | Diagonal deflectors |
| STAGE_TYPE_CUSTOM | JSON-loaded | Any combination |

### Stage 2: Ramp Layout

The default second stage uses converging ramps that funnel balls toward
the center:

```
    ╲          ╱
      ╲      ╱
        ╲  ╱
```

This creates a funneling effect that concentrates balls into the center
gates, making gameplay more strategic.

## Expansion Flow

When a player purchases a new stage:

1. **Pause Physics**: Ball updates halt during expansion
2. **Shift Content**: Existing world shifts to make room
3. **Insert Stage**: New stage appears between existing content
4. **Add Gate Row**: New scoring gates with increased multiplier
5. **Animate**: Camera zooms out to show new area
6. **Resume**: Physics resumes with expanded world

### Expansion Animation

The ExpansionAnimState structure manages the smooth transition:

```c
typedef struct ExpansionAnimState {
    bool active;
    float progress;         // 0.0 to 1.0
    float duration;         // Animation length
    float target_zoom;      // Camera zoom target
    float content_shift;    // Pixels to shift existing content
} ExpansionAnimState;
```

## Gate System

Gate rows serve multiple purposes:

1. **Scoring**: Balls passing through gates earn points
2. **Multipliers**: Deeper gates have higher multipliers
3. **Ball Passage**: Shared gates allow cross-board travel
4. **Defense**: Bumpers make gate passage challenging

### Gate Row Layout

```
|  10  |  50  | 100 | 500 | 100 |  50  |  10  |
   ▲      ▲     ▲     ▲     ▲      ▲      ▲
Bumpers between each zone deflect balls
```

## Integration Points

### Upgrade System

Stage purchases integrate with the upgrade menu:

```c
// In upgrade callbacks
case UPGRADE_NEXT_STAGE:
    world_begin_expansion(world);
    expansion_anim_start(&expansion_state);
    break;
```

### Ball Physics

Ball update tasks check for:
- Stage boundary collisions
- Gate zone scoring
- Bumper deflections
- Screen wrapping at stage boundaries

### Rendering

The stage manager provides unified rendering:

```c
stage_manager_render_all(manager);
// Renders all stages, gates, bumpers in correct order
```

## Files

| File | Purpose |
|------|---------|
| 014-stage.h | Stage, GateRow, StageManager structures |
| 015-stage.c | Stage system implementation |
| 016-ramp.h | Ramp obstacle type |
| 017-ramp.c | Ramp collision physics |
| 018-expansion-anim.h | Animation state machine |
| 019-expansion-anim.c | Animation update and camera |
