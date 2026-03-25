# 801 - Board Data Format (JSON Schema)

## Current Behavior

Boards are generated programmatically with hard-coded values:

```c
// src/005-world.c - Peg generation
world_generate_pegs(world, DEFAULT_PEG_ROWS, DEFAULT_PEG_COLS,
                    start_x, start_y, DEFAULT_PEG_SPACING);

// src/015-stage.c - Ramp generation
stage_generate_ramps_stage2(stage);
```

The layout is defined by code, not data. Changing a board requires recompiling.

## Intended Behavior

Define a JSON schema for board data that can be:
1. Created/edited in a visual editor
2. Saved to disk
3. Loaded at runtime to generate the game world

The schema should be:
- Human-readable (for manual tweaks)
- Compact (minimal verbosity)
- Extensible (easy to add new object types later)

## Suggested Implementation Steps

### Step 1: Define the JSON schema

```json
{
  "version": 1,
  "name": "Stage 1 - Classic Pegs",
  "grid": {
    "cell_size": 60,
    "columns": 14,
    "rows": 12
  },
  "board": {
    "width": 800,
    "height": 600
  },
  "objects": [
    {
      "type": "peg",
      "col": 2,
      "row": 1,
      "radius": 12
    },
    {
      "type": "line",
      "start_col": 4,
      "start_row": 3,
      "end_col": 6,
      "end_row": 5,
      "thickness": 20
    }
  ],
  "zones": [
    {
      "type": "score",
      "col": 5,
      "row": 10,
      "width": 2,
      "height": 1,
      "points": 100,
      "multiplier": 1
    },
    {
      "type": "trigger",
      "col": 3,
      "row": 8,
      "width": 1,
      "height": 1,
      "action": "boost"
    }
  ]
}
```

**Key distinction:**
- **Objects:** Physical obstacles that balls collide with (pegs, lines/ramps)
- **Zones:** Trigger areas that fire once per ball, reset when ball exits

### Step 2: Define C data structures

```c
// src/020-board-data.h

typedef struct BoardObject {
    int type;              // OBJECT_PEG, OBJECT_LINE
    int col, row;          // Grid position (for pegs: center, for lines: start)
    float radius;          // For pegs

    // For lines (ramps)
    int end_col, end_row;  // End grid position
    float thickness;       // Line thickness in pixels
} BoardObject;

typedef struct BoardZone {
    int type;              // ZONE_SCORE, ZONE_TRIGGER
    int col, row;          // Grid position (top-left)
    int width, height;     // Size in grid cells

    // For score zones
    int points;
    int multiplier;

    // For trigger zones
    char action[32];       // Action identifier (e.g., "boost", "split")
} BoardZone;

typedef struct BoardData {
    int version;
    char name[64];

    // Grid settings
    int cell_size;
    int grid_cols;
    int grid_rows;

    // Board dimensions (pixels)
    int board_width;
    int board_height;

    // Objects (collision obstacles)
    BoardObject* objects;
    int object_count;
    int object_capacity;

    // Zones (trigger areas)
    BoardZone* zones;
    int zone_count;
    int zone_capacity;
} BoardData;
```

### Step 3: Define type enums

```c
typedef enum ObjectType {
    OBJECT_PEG,
    OBJECT_LINE,
    OBJECT_COUNT
} ObjectType;

typedef enum ZoneType {
    ZONE_SCORE,
    ZONE_TRIGGER,
    ZONE_COUNT
} ZoneType;
```

### Step 4: Create helper functions

```c
// Create empty board data
BoardData* board_data_create(int grid_cols, int grid_rows, int cell_size);

// Free board data
void board_data_destroy(BoardData* data);

// Add object to board
int board_data_add_object(BoardData* data, ObjectType type, int col, int row);

// Remove object from board (by grid position)
int board_data_remove_object(BoardData* data, int col, int row);

// Add gate row
int board_data_add_gate_row(BoardData* data, int row, int zone_count, int multiplier);

// Convert grid coords to pixel coords
float board_grid_to_pixel_x(BoardData* data, int col);
float board_grid_to_pixel_y(BoardData* data, int row);

// Convert pixel coords to grid coords
int board_pixel_to_grid_col(BoardData* data, float x);
int board_pixel_to_grid_row(BoardData* data, float y);
```

### Step 5: Integrate cJSON library

Add cJSON to the project:
- Download cJSON.h and cJSON.c from https://github.com/DaveGamble/cJSON
- Place in `libs/cjson/`
- Update compile script to include cJSON

## Schema Design Decisions

### Grid-based coordinates
Objects are positioned by grid cell (col, row) rather than pixel coordinates:
- Resolution-independent
- Natural snapping behavior
- Cleaner data

### Staggered grid consideration
The current peg layout uses a staggered grid (odd rows offset by half cell). Options:
1. Store explicit offset in object
2. Use separate grid systems for even/odd rows
3. Store raw grid position, apply stagger in loader

**Recommendation:** Option 3 - let the loader handle stagger based on object type and row parity.

### Ramp dimensions
Ramps use grid cell units for width/height:
- `width: 2` means ramp spans 2 cells horizontally
- `height: 1` means ramp spans 1 cell vertically
- Converted to pixels at load time: `pixel_width = width * cell_size`

### Version field
The `version` field allows future schema changes:
- Version 1: Basic pegs, ramps, gates
- Version 2+: Future object types, properties

## Files to Create

- `src/020-board-data.h` - Board data structures and API
- `src/021-board-data.c` - Board data implementation
- `libs/cjson/cJSON.h` - JSON parsing library
- `libs/cjson/cJSON.c` - JSON parsing library

## Testing

1. Create BoardData programmatically
2. Add several objects (pegs, ramps)
3. Add a gate row
4. Verify grid-to-pixel conversion matches expected positions
5. Verify all objects accessible via iteration

## Related Issues

- 1102-grid-system-architecture.md (uses grid definitions)
- 1103-board-loader.md (parses this JSON format)
- 1108-board-save.md (writes this JSON format)
