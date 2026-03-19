# 803 - Board Loader (JSON to Game)

## Current Behavior

Board content is generated programmatically at startup:

```c
// src/001-main.c
world_generate_pegs(world, DEFAULT_PEG_ROWS, DEFAULT_PEG_COLS,
                    start_x, start_y, DEFAULT_PEG_SPACING);
world_generate_zones(world, ZONE_COUNT, ZONE_HEIGHT);
world_generate_bumpers(world);
```

No external data files are used - the layout is compiled into the executable.

## Intended Behavior

Load board layouts from JSON files at runtime:
1. Parse JSON file using cJSON library
2. Create BoardData structure from parsed data
3. Convert BoardData into game objects (Pegs, Ramps, ScoreZones)
4. Populate World or Stage with loaded objects

This separates data from code, enabling the editor workflow.

## Suggested Implementation Steps

### Step 1: Add cJSON to project

Download cJSON from https://github.com/DaveGamble/cJSON and add to project:

```
libs/cjson/
  cJSON.h
  cJSON.c
```

Update compile script:
```bash
gcc -I./libs/cjson ... libs/cjson/cJSON.c ...
```

### Step 2: Implement JSON parsing function

```c
// src/021-board-data.c

#include "cJSON.h"

BoardData* board_data_load_json(const char* filename) {
    // Read file contents
    FILE* file = fopen(filename, "r");
    if (!file) {
        fprintf(stderr, "ERROR: Cannot open board file: %s\n", filename);
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* json_string = malloc(length + 1);
    fread(json_string, 1, length, file);
    json_string[length] = '\0';
    fclose(file);

    // Parse JSON
    cJSON* root = cJSON_Parse(json_string);
    free(json_string);

    if (!root) {
        fprintf(stderr, "ERROR: JSON parse error: %s\n", cJSON_GetErrorPtr());
        return NULL;
    }

    // Extract data...
    BoardData* data = board_data_create_from_json(root);
    cJSON_Delete(root);

    return data;
}
```

### Step 3: Implement JSON object parsing

```c
static BoardData* board_data_create_from_json(cJSON* root) {
    // Get grid settings
    cJSON* grid = cJSON_GetObjectItem(root, "grid");
    int cell_size = cJSON_GetObjectItem(grid, "cell_size")->valueint;
    int cols = cJSON_GetObjectItem(grid, "columns")->valueint;
    int rows = cJSON_GetObjectItem(grid, "rows")->valueint;

    BoardData* data = board_data_create(cols, rows, cell_size);

    // Get name
    cJSON* name = cJSON_GetObjectItem(root, "name");
    if (name) {
        strncpy(data->name, name->valuestring, 63);
    }

    // Parse objects array
    cJSON* objects = cJSON_GetObjectItem(root, "objects");
    cJSON* obj;
    cJSON_ArrayForEach(obj, objects) {
        const char* type_str = cJSON_GetObjectItem(obj, "type")->valuestring;
        int col = cJSON_GetObjectItem(obj, "col")->valueint;
        int row = cJSON_GetObjectItem(obj, "row")->valueint;

        if (strcmp(type_str, "peg") == 0) {
            board_data_add_object(data, OBJECT_PEG, col, row);
        } else if (strcmp(type_str, "ramp") == 0) {
            const char* dir = cJSON_GetObjectItem(obj, "direction")->valuestring;
            ObjectType ramp_type = (strcmp(dir, "left") == 0) ?
                OBJECT_RAMP_LEFT : OBJECT_RAMP_RIGHT;
            int width = cJSON_GetObjectItem(obj, "width")->valueint;
            int height = cJSON_GetObjectItem(obj, "height")->valueint;
            board_data_add_ramp(data, ramp_type, col, row, width, height);
        }
    }

    // Parse gate rows
    cJSON* gate_rows = cJSON_GetObjectItem(root, "gate_rows");
    cJSON* gate;
    cJSON_ArrayForEach(gate, gate_rows) {
        int gate_row = cJSON_GetObjectItem(gate, "row")->valueint;
        int zone_count = cJSON_GetObjectItem(gate, "zone_count")->valueint;
        int multiplier = cJSON_GetObjectItem(gate, "multiplier")->valueint;
        board_data_add_gate_row(data, gate_row, zone_count, multiplier);
    }

    return data;
}
```

### Step 4: Implement board-to-world conversion

```c
// Convert loaded BoardData into actual game objects
int board_data_apply_to_world(BoardData* data, World* world) {
    Grid grid = grid_create(data->grid_cols, data->grid_rows,
                           data->cell_size, world->table_x, world->table_top);
    grid.stagger_odd_rows = 1;  // Pegs use staggered layout

    // Count pegs for allocation
    int peg_count = 0;
    for (int i = 0; i < data->object_count; i++) {
        if (data->objects[i].type == OBJECT_PEG) peg_count++;
    }

    // Allocate and populate pegs
    world->pegs = malloc(sizeof(Peg) * peg_count);
    world->peg_count = peg_count;

    int peg_index = 0;
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        if (obj->type == OBJECT_PEG) {
            world->pegs[peg_index].x = grid_to_pixel_x(&grid, obj->col, obj->row);
            world->pegs[peg_index].y = grid_to_pixel_y(&grid, obj->col, obj->row);
            world->pegs[peg_index].radius = PEG_RADIUS;
            peg_index++;
        }
    }

    // Apply gate rows...
    // (Similar logic for zones and bumpers)

    return 1;
}
```

### Step 5: Implement board-to-stage conversion

For stages (which can contain ramps):

```c
int board_data_apply_to_stage(BoardData* data, Stage* stage) {
    Grid grid = grid_create(data->grid_cols, data->grid_rows,
                           data->cell_size, stage->table_x, stage->y_top);

    // Count ramps
    int ramp_count = 0;
    for (int i = 0; i < data->object_count; i++) {
        if (data->objects[i].type == OBJECT_RAMP_LEFT ||
            data->objects[i].type == OBJECT_RAMP_RIGHT) {
            ramp_count++;
        }
    }

    // Allocate and populate ramps
    stage->ramps = malloc(sizeof(Ramp) * ramp_count);
    stage->ramp_count = ramp_count;

    int ramp_index = 0;
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        if (obj->type == OBJECT_RAMP_LEFT || obj->type == OBJECT_RAMP_RIGHT) {
            float x = grid_to_pixel_x(&grid, obj->col, obj->row);
            float y = grid_to_pixel_y(&grid, obj->col, obj->row);
            float width = obj->width * data->cell_size;
            float height = obj->height * data->cell_size;
            RampDirection dir = (obj->type == OBJECT_RAMP_LEFT) ?
                RAMP_LEFT : RAMP_RIGHT;

            stage->ramps[ramp_index] = ramp_create(x, y, width, height, dir);
            ramp_index++;
        }
    }

    return 1;
}
```

### Step 6: Create default board files

Create initial board files matching current programmatic layouts:

**boards/stage1-default.json:**
```json
{
  "version": 1,
  "name": "Stage 1 - Classic Pegs",
  "grid": {
    "cell_size": 60,
    "columns": 8,
    "rows": 10
  },
  "board": {
    "width": 800,
    "height": 600
  },
  "objects": [
    {"type": "peg", "col": 0, "row": 0},
    {"type": "peg", "col": 1, "row": 0},
    ...
  ],
  "gate_rows": [
    {"row": 10, "zone_count": 9, "multiplier": 1}
  ]
}
```

### Step 7: Update main.c to use loader

Replace programmatic generation with file loading:

```c
// Old:
world_generate_pegs(world, ...);

// New:
BoardData* board = board_data_load_json("boards/stage1-default.json");
if (board) {
    board_data_apply_to_world(board, world);
    board_data_destroy(board);
}
```

## Error Handling

The loader should gracefully handle:
- Missing files (fall back to programmatic generation)
- Malformed JSON (log error, return NULL)
- Missing required fields (use defaults)
- Invalid object types (skip with warning)
- Out-of-bounds coordinates (clamp to grid)

## Files to Modify/Create

- `libs/cjson/cJSON.h` - JSON library header
- `libs/cjson/cJSON.c` - JSON library implementation
- `src/021-board-data.c` - Add JSON loading functions
- `src/001-main.c` - Use loader instead of generation
- `boards/stage1-default.json` - Default peg layout
- `scripts/compile` - Include cJSON in build

## Testing

1. Create minimal test JSON file with 3 pegs
2. Load and verify peg positions match expected grid positions
3. Create JSON with ramps, verify direction and dimensions
4. Create JSON with gate row, verify zone count and multiplier
5. Test error cases: missing file, invalid JSON, missing fields
6. Compare loaded board visually to programmatic board

## Related Issues

- 1101-board-data-format.md (defines JSON schema)
- 1102-grid-system.md (grid-to-pixel conversion)
- 1108-board-save.md (reverse operation - game to JSON)

## Implementation Notes (Completed)

### What was implemented:

1. **cJSON library added** (`libs/cjson/cJSON.h`, `libs/cjson/cJSON.c`)
   - Downloaded and integrated cJSON library
   - Updated Makefile to include cJSON paths

2. **Updated Peg struct** (`src/004-world.h`)
   - Added `restitution`, `friction`, `point_bonus` properties
   - Added `color` field for RGB-derived visual color

3. **Updated peg generation** (`src/005-world.c`)
   - `world_generate_pegs()` initializes new properties with defaults
   - `world_generate_adversary_pegs()` initializes new properties
   - `world_render_pegs()` uses `peg->color` for rendering
   - `world_render_adversary_pegs()` uses `peg->color` for rendering

4. **Board loader functions** (`src/021-board-data.c`)
   - `board_data_apply_pegs_to_world()` - converts BoardObject pegs to World Pegs
   - `board_data_apply_zones_to_world()` - converts BoardZone score zones to World ScoreZones
   - `board_data_apply_to_world()` - master function that applies all content
   - `rgb_to_color()` - generates visual color from RGB properties

5. **RGB property conversion**
   - R (restitution) = bounciness, maps to red tint
   - G (friction) = grip, maps to green tint
   - B (point_bonus) = value, maps to blue tint

### Deferred to other issues:

- Line (ramp) loading - Issue 1110
- Portal zone loading - Issue 1112
- Integration with main.c to use loader at startup - Issue 1109

### Files modified:

- `Makefile` - added cJSON paths
- `src/004-world.h` - added Peg properties
- `src/005-world.c` - updated peg generation and rendering
- `src/020-board-data.h` - added loader function declarations
- `src/021-board-data.c` - added loader implementations
