# 010 - Board Editor

## Overview

The board editor is a standalone application for creating pachinko boards
visually. Boards are stored as JSON files and loaded by the game at runtime.

## Applications

The project builds two separate executables:

| Binary | Purpose |
|--------|---------|
| bin/physics-sim | Game - loads boards from boards/ |
| bin/board-editor | Editor - creates/edits board files |

Both share common code for board data, grid system, and portal zones.

## Board Data Format

### JSON Structure

```json
{
    "version": 1,
    "name": "example-board",
    "cell_size": 60,
    "grid_cols": 10,
    "grid_rows": 15,
    "objects": [
        { "type": "peg", "col": 5, "row": 3, "r": 178, "g": 51, "b": 0 },
        { "type": "line", "col": 2, "row": 5, "end_col": 8, "end_row": 5,
          "thickness": 20, "r": 178, "g": 51, "b": 0 }
    ],
    "zones": [
        { "type": "portal", "col": 1, "row": 10, "width": 2, "height": 2,
          "channel": 1, "direction": "entry" }
    ]
}
```

### Object Types

**Peg**: Circle obstacle at a grid intersection
- Properties: col, row, radius, RGB

**Line**: Thick segment with rounded ends
- Properties: start (col, row), end (col, row), thickness, RGB

### Zone Types

**Score Zone**: Awards points when ball passes through
- Properties: position, size, points, multiplier

**Portal Zone**: Teleports balls to linked exit
- Properties: position, size, channel, direction (entry/exit)

## RGB Property System

Object properties are encoded as RGB values (0-255):

| Channel | Property | Effect |
|---------|----------|--------|
| R | Restitution | Bounciness (0=dead, 255=super bounce) |
| G | Friction | Surface grip (0=ice, 255=sticky) |
| B | Point Bonus | Score awarded on collision |

Default values: R=178 (~0.7), G=51 (~0.2), B=0

## Grid System

All positions use grid coordinates, converted to pixels at runtime:

```c
// Grid to pixel conversion
pixel_x = grid->offset_x + col * grid->cell_size;
pixel_y = grid->offset_y + row * grid->cell_size;
```

Objects snap to grid intersections (corners), not cell centers. This
enables precise alignment when connecting lines.

## Editor Workflow

### Mode Toggle
Press TAB to switch between editing modes.

### Object Palette
Select object type with number keys:
- 1: Peg
- 2: Line
- 3: Portal Entry
- 4: Portal Exit

### Placement
- Click to place objects at nearest grid intersection
- For lines: click start, click end, drag to set thickness
- Right-click to erase objects

### Property Editing
- Click existing object to select
- Adjust R/G/B values in property panel
- Color updates live as values change

### Save/Load
- Ctrl+S: Save current board
- Ctrl+O: Load board from file
- Boards saved to boards/ directory

## Portal System

Portals enable teleportation between board regions:

1. Entry portal detects ball collision
2. Ball teleports to random exit with same channel
3. Ball state preserved (velocity, health, owner)
4. Exit portals don't trigger on contact

### Channel System
Portals are grouped by channel ID. Multiple entries can link to multiple
exits within the same channel, enabling branching paths.

## Stage Pool Integration

When the player purchases a new stage, the game selects randomly from
available board files:

```c
// StagePool picks random board from boards/
char* filename = stage_pool_get_random(pool);
BoardData* board = board_data_load_json(filename);
stage_apply_board_data(new_stage, board);
```

Each board is used once before any repeats.

## Files

### Shared Components
| File | Purpose |
|------|---------|
| 020-board-data.h | BoardData, BoardObject, BoardZone structs |
| 021-board-data.c | JSON parsing/serialization (uses cJSON) |
| 022-grid.h | Grid coordinate system |
| 023-grid.c | Grid calculations |
| 028-portal.h | Portal zone structures |
| 029-portal.c | Portal manager and teleportation |

### Editor-Only Components
| File | Purpose |
|------|---------|
| 030-editor-main.c | Editor entry point |
| 031-editor-app.h | Editor application state |
| 032-editor-app.c | Editor implementation |
| 034-object-render.h | Object rendering utilities |
| 035-object-render.c | Grid, cursor, object rendering |

### Game Integration
| File | Purpose |
|------|---------|
| 026-stage-pool.h | Stage pool structure |
| 027-stage-pool.c | Random stage selection |

## Build

```bash
# Build game only
make game

# Build editor only
make editor

# Build both
make all
```
