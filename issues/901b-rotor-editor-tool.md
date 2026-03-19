# 1305b - Editor Rotor Placement Tool

## Status: Open

## Parent Issue: 1305 - Rotor System

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
