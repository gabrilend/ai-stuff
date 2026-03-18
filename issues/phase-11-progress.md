# Phase 11 Progress

## Phase Goal

Board Editor System. Create a visual editor for designing pachinko boards, with JSON-based data storage and runtime loading. Replace programmatic board generation with data-driven design.

## Issues

| ID   | Description                        | Status    |
|------|------------------------------------|-----------|
| 1101 | Board data format (JSON schema)    | Complete  |
| 1102 | Grid system architecture           | Complete  |
| 1103 | Board loader (JSON to game)        | Complete  |
| 1104 | Editor mode toggle                 | Complete  |
| 1105 | Object palette UI                  | Complete  |
| 1106 | Object placement system            | Complete  |
| 1107 | Object removal system              | Complete  |
| 1108 | Board save functionality           | Complete  |
| 1109 | Board load functionality           | Complete  |
| 1110 | Line drawing tool                  | Complete  |
| 1111 | Stage pool system                  | Complete  |
| 1112 | Portal zone system                 | Complete  |
| 1113 | Object property editor (RGB)       | Complete  |

## Progress Summary

**Completed:** 13/13 issues (100%)
**Phase 11:** COMPLETE! All board editor features implemented.

## Design Overview

### Core Concept

Transform the current programmatic board generation into a data-driven system:

1. **Current State:** Boards are generated via code (`world_generate_pegs()`, `stage_generate_ramps_stage2()`, etc.)
2. **Future State:** Boards are loaded from JSON files, allowing visual editing and easy iteration

### Supported Object Types

| Type | Properties | Grid Behavior |
|------|-----------|---------------|
| Peg | x, y, radius | Snap to grid intersection |
| Ramp | x, y, width, height, direction | Snap to grid cell |
| Gate | y_position, zone_count, multiplier | Snap to row boundary |

### Grid System

- Configurable cell size (default: 60px, matching current PEG_SPACING)
- Objects snap to nearest grid position on placement
- Grid visible in editor mode, hidden in play mode
- Coordinates stored as grid indices, converted to pixels at load time

### Editor Workflow

```
[Play Mode] <--TAB--> [Editor Mode]
                           |
                    +------+------+
                    |             |
               [Place Mode]  [Erase Mode]
                    |             |
              Click to add  Click to remove
                    |
              [Object Palette]
              - Peg
              - Ramp (Left)
              - Ramp (Right)
              - Gate Row
```

### Data Flow

```
+-------------+     +------------+     +-------------+
| JSON File   | --> | Board      | --> | Game World  |
| (boards/)   |     | Loader     |     | (runtime)   |
+-------------+     +------------+     +-------------+
       ^                                      |
       |                                      v
+-------------+     +------------+     +-------------+
| Board       | <-- | Editor     | <-- | User Input  |
| Serializer  |     | State      |     | (mouse/kb)  |
+-------------+     +------------+     +-------------+
```

## Design Decisions (Confirmed)

### D1: Board Structure
**Decision:** Single stage per JSON file, containing any mix of objects and zones.
- Objects: Collision obstacles (pegs, ramps/lines, etc.)
- Zones: Trigger areas that fire once per ball (reset when ball exits)
- This allows flexible stage design while maintaining modularity

### D2: Adversary Board
**Decision:** Auto-mirror from player board.
- Single board file, adversary is generated as mirror
- May revisit for asymmetric designs later

### D3: Object Placement
**Decision:** Free placement with grid snapping.
- No automatic stagger - user places objects anywhere
- All placements snap to nearest grid intersection
- Full creative freedom within the grid system

### D4: Ramp/Line Tool
**Decision:** Line drawing tool with variable thickness and rounded joints.

**Workflow:**
1. Select line tool, see preview dot on nearest grid intersection
2. Click to set start point
3. Move mouse, preview line to nearest grid point
4. Click to set end point
5. Move mouse orthogonally to adjust thickness (away = thicker, toward = thinner)
6. Click to confirm thickness

**Joint System:**
- Line endpoints terminate in circles (diameter = line width)
- When lines share a grid point, ball joints overlap seamlessly
- Enables smooth connected ramp networks

### D5: Stage Purchase System
**Decision:** Random selection from stage pool with no-repeat cycling.
- When player purchases a stage, system picks random JSON from pool
- Each stage used once before any repeats
- Integrates editor-created stages into existing upgrade flow

### D6: Editor Integration
**Decision:** Built into game, toggle with key.
- Same executable, immediate physics preview
- Matches existing menu patterns (TAB for upgrades)

### D7: Portal Zones
**Decision:** Grouped channels with entry/exit distinction.
- Portals have a channel ID (e.g., 1, 2, 3)
- Portals are marked as "entry" or "exit"
- Ball entering an entry portal teleports to random exit portal with same channel
- Ball entering an exit portal does nothing
- Ball state fully preserved (velocity, health, owner, etc.)

### D8: Object Properties (RGB Encoding)
**Decision:** Three editable properties mapped to RGB color channels.

| Channel | Property | Range | Effect |
|---------|----------|-------|--------|
| R | Restitution | 0-255 → 0.0-1.0 | Bounciness |
| G | Friction | 0-255 → 0.0-1.0 | Grip/slide |
| B | Point Bonus | 0-255 → 0-255 pts | Score on hit |

- Click object in editor to open property panel
- Color updates live as values change
- Default: (178, 50, 0) = 0.7 restitution, 0.2 friction, 0 bonus

## Suggested Implementation Order

**Foundation (sequential):**
1. **1101** - JSON schema design (defines everything else)
2. **1102** - Grid system (core positioning logic)
3. **1103** - Board loader (prove the data format works)

**Editor Core (parallel where possible):**
4. **1104** - Editor mode toggle (E key switch)
5. **1105** - Object palette UI (visual selection)
6. **1106** - Object placement (click to add pegs)
7. **1110** - Line drawing tool (complex multi-click tool)
8. **1112** - Portal zone system (entry/exit placement)
9. **1107** - Object removal (click to delete)
10. **1113** - Object property editor (click to modify RGB values)

**File I/O (sequential):**
11. **1108** - Board save (editor -> JSON)
12. **1109** - Board load (JSON -> editor)

**Integration:**
13. **1111** - Stage pool system (random stage selection on purchase)

## Dependencies

Phase 10 must be complete (provides Stage and Ramp systems used by editor).

## Files to Create

- `src/020-board-data.h` - Board JSON data structures (objects, zones, properties)
- `src/021-board-data.c` - JSON parsing and serialization
- `src/022-grid.h` - Grid system
- `src/023-grid.c` - Grid calculations
- `src/024-editor.h` - Editor state, line tool, palette, property panel
- `src/025-editor.c` - Editor implementation
- `src/026-stage-pool.h` - Stage pool structure
- `src/027-stage-pool.c` - Random stage selection
- `src/028-portal.h` - Portal zone structures
- `src/029-portal.c` - Portal manager and teleportation
- `boards/` - Directory for board JSON files (created)
- `boards/stage1-default.json` - Default peg layout
- `boards/stage2-lines.json` - Example line/ramp stage

## JSON Library Consideration

C doesn't have built-in JSON support. Options:

1. **cJSON** - Lightweight, single-file, MIT license
2. **json-c** - More features, heavier
3. **Custom parser** - Minimal, but more work

**Recommendation:** Use cJSON (single .h/.c file, easy to integrate)
