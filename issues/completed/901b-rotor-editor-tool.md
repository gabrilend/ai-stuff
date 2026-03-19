# 901b - Editor Rotor Placement Tool

## Status: Completed

## Parent Issue: 901 - Rotor System

## Problem

Need editor UI for placing rotors and defining which objects are connected to them.

## Implementation

### Editor Workflow

1. Select "Rotor" tool (key 5 or toolbar button)
2. Click grid intersection to place rotor center
3. Rotor appears as special peg marker (gear icon or distinct color)
4. Draw lines FROM the rotor center to create rotating arms
5. Place pegs that touch rotor lines - they become connected automatically
6. Right-click rotor to open property panel:
   - Rotation speed slider
   - Direction toggle (CW/CCW)
   - List of connected objects (read-only)

### Visual Indicators

- Rotor center: Gear-shaped or ringed peg
- Connected objects: Highlighted with rotation indicator
- Preview: Show rotation direction arrow when hovering

### Connection Rules

- Objects are connected if they touch a line that originates from rotor
- Transitive: If peg A touches rotor line, and line B touches peg A, line B is also connected
- Connection computed on placement, updated when objects change

## Implementation Steps

1. Add APP_TOOL_ROTOR to editor tool enum
2. Add rotor placement handling in handle_canvas_click
3. Add rotor rendering (distinct from regular pegs)
4. Modify line tool to detect rotor connections
5. Add rotor property panel with speed/direction controls
6. Implement connection visualization

## Files to Modify

- `src/031-editor-app.h` - Add tool enum, rotor state
- `src/032-editor-app.c` - Placement, property panel
- `src/035-object-render.c` - Rotor rendering

## Notes

- Consider rotor as special zone type or separate from objects
- May need "rotor mode" where subsequent placements auto-connect

## Implementation Complete

### Changes Made

1. Added `APP_TOOL_ROTOR` to `EditorAppTool` enum in `031-editor-app.h`
2. Added key 5 binding for rotor tool selection in `handle_tool_selection()`
3. Added rotor placement in `place_object()` with default speed of 1.0 rad/s
4. Added rotor erasing support in `erase_object()` via new `erase_rotor_at()` helper
5. Added rotor rendering functions in `034-object-render.h` and `035-object-render.c`:
   - `render_rotor()` - gear-shaped marker with rotation direction arrow
   - `render_rotor_preview()` - semi-transparent cursor preview
   - `render_board_rotors()` - renders all rotors in a board
6. Updated toolbar: 5 tool buttons with "5:Rotor"
7. Updated sidebar: "Rotor" in tool names, rotor count in board stats
8. Updated tools panel: added "5: Rotor" button

### Rotor Visual Design

Rotors are rendered as gear-shaped markers:
- 8 triangular teeth around a central circle
- Golden/brass color scheme (distinguishes from regular pegs)
- Direction arrow showing CW/CCW rotation
- Teeth rotate based on `current_angle`

### Deferred to Later Issues

- Rotor property panel (speed/direction adjustment) - defer to 901g
- Connection visualization - defer to 901d implementation
- Automatic connection detection on line placement - works via existing `board_data_rotor_detect_connections()`

### Unblocks

- 901g (Direction configuration UI) - now has tool infrastructure
