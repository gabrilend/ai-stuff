# 901g - Rotor Direction Configuration UI

## Status: Open

## Parent Issue: 901 - Rotor System

## Problem

Users need a way to configure rotor rotation direction and speed in the editor.

## UI Design

### Property Panel (Right-click on Rotor)

```
┌─────────────────────────┐
│ Rotor Properties        │
├─────────────────────────┤
│ Direction: [CW] [CCW]   │
│                         │
│ Speed: ████████░░ 80%   │
│                         │
│ Connected: 5 objects    │
└─────────────────────────┘
```

### Controls

- **Direction Toggle**: Two buttons or single toggle
  - CW = Clockwise (positive speed)
  - CCW = Counter-clockwise (negative speed)
- **Speed Slider**: 0-100% mapped to rotation speed range
  - 0% = stationary
  - 100% = maximum speed (configurable constant)
- **Connected Count**: Read-only display

### Visual Indicators

- Arrow overlay on rotor showing current direction
- Arrow animates/pulses to indicate speed
- Different colors for CW vs CCW (optional)

### Keyboard Shortcuts (while rotor selected)

- `R` - Reverse direction
- `+`/`-` - Adjust speed

## Implementation Steps

1. Extend property panel to detect rotor selection
2. Add direction toggle buttons
3. Add speed slider (reuse RGB slider code)
4. Add connected object count display
5. Add direction arrow rendering
6. Implement keyboard shortcuts

## Files to Modify

- `src/032-editor-app.c` - Property panel extension
- `src/035-object-render.c` - Direction arrow rendering

## Notes

- Reuse slider rendering from RGB property panel
- Direction stored as sign of speed value
- Consider showing rotation preview animation in editor
