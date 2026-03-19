# 902b - Editor Track Drawing Tool

## Status: Open

## Parent Issue: 902 - Track Mover System

## Problem

Need editor UI for drawing track segments and placing movers on them.

## Editor Workflow

### Track Drawing Mode

1. Select "Track" tool (key 6 or toolbar button)
2. Click to start track segment
3. Click again to end segment (like line tool)
4. If endpoint is near existing track endpoint, snap to it (creates connection)
5. Continue drawing more segments or switch tools

### Mover Placement Mode

1. Select "Mover" tool (key 7 or toolbar button)
2. Click on existing track segment to place mover
3. Mover appears as distinct marker on track
4. Draw objects connected to mover (they become payload)

### Visual Indicators

- Track segments: Dashed or dotted lines (distinct from solid object lines)
- Track color: Different from object lines (gray? blue?)
- Intersections: Highlighted nodes
- Mover: Circular marker with direction indicator
- Payload objects: Highlighted when mover selected

### Property Panel (Right-click on Mover)

```
┌─────────────────────────┐
│ Mover Properties        │
├─────────────────────────┤
│ Speed: ████████░░ 80%   │
│                         │
│ Payload: 3 objects      │
└─────────────────────────┘
```

## Snap Behavior

- Track endpoints snap to grid intersections
- Track endpoints snap to existing track endpoints (within threshold)
- Mover snaps to nearest point on track segment

## Implementation Steps

1. Add APP_TOOL_TRACK and APP_TOOL_MOVER to editor tool enum
2. Implement track drawing (similar to line tool)
3. Add endpoint snapping logic
4. Implement mover placement on tracks
5. Add track and mover rendering
6. Add property panel for mover speed

## Files to Modify

- `src/031-editor-app.h` - Add tool enums
- `src/032-editor-app.c` - Track/mover tools, property panel
- `src/035-object-render.c` - Track and mover rendering

## Notes

- Track drawing very similar to line drawing, can reuse code
- Consider different visual style to distinguish tracks from collision lines
- Mover position stored as parametric value (0-1) along segment
