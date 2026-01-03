# Issue 904: Region and Camera Editor

**Phase:** 9
**Type:** Implementation
**Priority:** High
**Dependencies:** 901 (Editor core), 203-204 (Region/Camera parsers)

---

## Current Behavior

Regions and cameras can be parsed and used at runtime but not created or edited.

## Intended Behavior

Full region and camera editing with feature parity to WC3 World Editor.

### Region Editor

```
REGION TOOLS
┌────────────────────────────┐
│ ● Rectangle  ○ Circle      │
│                            │
│ [New Region] [Delete]      │
└────────────────────────────┘

REGION LIST
┌────────────────────────────────┐
│ ▶ Playable Area               │
│   ├─ Player 1 Start           │
│   ├─ Player 2 Start           │
│   └─ Center Arena             │
│ ▶ Trigger Zones               │
│   ├─ Spawn Zone A             │
│   ├─ Spawn Zone B             │
│   └─ Victory Zone             │
│ ▶ Camera Bounds               │
│   └─ Playable Camera Bounds   │
└────────────────────────────────┘

REGION PROPERTIES
┌────────────────────────────────┐
│ Name: [Victory Zone______]    │
│                                │
│ Position:                      │
│   X: [1024.0]  Y: [2048.0]    │
│                                │
│ Size:                          │
│   Width: [512.0]               │
│   Height: [256.0]              │
│                                │
│ Weather: [None ▼]              │
│ Ambient: [Default ▼]           │
│                                │
│ Color: [■ Orange]              │
│ [ ] Show in game               │
└────────────────────────────────┘
```

### Region Types

| Type | Use Case |
|------|----------|
| **Playable Area** | Defines map bounds |
| **Camera Bounds** | Constrains camera scrolling |
| **Spawn Point** | Starting locations |
| **Trigger Zone** | Script-activated areas |
| **Weather Zone** | Weather effect regions |
| **Sound Zone** | Ambient sound regions |

### Camera Editor

```
CAMERA TOOLS
┌────────────────────────────┐
│ [New Camera] [Delete]      │
│                            │
│ [Set from View]            │
│ [Go to Camera]             │
└────────────────────────────┘

CAMERA LIST
┌────────────────────────────────┐
│ ○ Intro Camera                 │
│ ○ Battle Camera                │
│ ● Victory Cinematic            │
│ ○ Player 1 View                │
│ ○ Player 2 View                │
└────────────────────────────────┘

CAMERA PROPERTIES
┌────────────────────────────────┐
│ Name: [Victory Cinematic__]   │
│                                │
│ Position:                      │
│   X: [1024.0]  Y: [2048.0]    │
│                                │
│ Target:                        │
│   X: [1024.0]  Y: [2048.0]    │
│   Height: [0.0]                │
│                                │
│ Angle of Attack: [304°]        │
│ Rotation: [90°]                │
│ Distance: [1650]               │
│ Roll: [0°]                     │
│ Field of View: [70°]           │
│                                │
│ Far Clipping: [5000]           │
│                                │
│ [Preview] [Apply to View]      │
└────────────────────────────────┘
```

### Camera Visualization

```
    ╲                     ╱
     ╲   [Camera Eye]    ╱
      ╲       ●         ╱
       ╲      │        ╱
        ╲     │       ╱
         ╲    │      ╱
          ╲   │     ╱
           ╲  │    ╱
            ╲ │   ╱
             ╲│  ╱
              ╳ ← Target Point
             ╱ ╲
            ╱   ╲
           ╱     ╲
    [Frustum visualization in viewport]
```

### API Design

```lua
local regions = require("editor.regions")
local cameras = require("editor.cameras")

-- REGIONS --

-- Create region
local region = regions.create({
    name = "Spawn Zone",
    x = 1024, y = 2048,
    width = 512, height = 256,
    color = {255, 128, 0},
    weather = "rain",
})

-- Edit region
regions.set_position(region, x, y)
regions.set_size(region, width, height)
regions.set_name(region, "New Name")

-- Query regions
local at_point = regions.get_at(x, y)
local overlapping = regions.get_overlapping(region)

-- Region handles (for resizing)
local handle = regions.pick_handle(screen_x, screen_y)
regions.drag_handle(handle, dx, dy)

-- CAMERAS --

-- Create camera
local camera = cameras.create({
    name = "Intro Camera",
    x = 1024, y = 2048,
    target_x = 1024, target_y = 2048, target_z = 0,
    angle_of_attack = 304,
    rotation = 90,
    distance = 1650,
    fov = 70,
})

-- Set from current view
cameras.set_from_view(camera)

-- Apply to viewport
cameras.apply_to_view(camera)

-- Preview camera in viewport
cameras.preview(camera, duration)

-- Visualize in editor
cameras.draw_frustum(camera)
```

## Suggested Implementation Steps

1. Create `src/editor/regions.lua` module
2. Implement region creation (rectangle, circle)
3. Implement region selection and handles
4. Implement region properties panel
5. Implement region list with folders
6. Create `src/editor/cameras.lua` module
7. Implement camera creation
8. Implement camera properties editor
9. Implement camera frustum visualization
10. Implement "set from view" / "apply to view"
11. Integrate with undo/redo
12. Create tests

## Acceptance Criteria

- [ ] Rectangle and circle regions creatable
- [ ] Regions resizable via handles
- [ ] Region properties editable (name, weather, ambient)
- [ ] Region list with folder organization
- [ ] Camera objects creatable
- [ ] Camera properties editable (all angles, distances)
- [ ] "Set from View" captures current viewport
- [ ] "Apply to View" moves viewport to camera
- [ ] Camera frustum visualized in editor
- [ ] All operations support undo/redo

## Related Documents

- `src/parsers/w3r.lua` - Region data structure
- `src/parsers/w3c.lua` - Camera data structure
- Issue 203 - Region parser
- Issue 204 - Camera parser

## Notes

- Regions should be semi-transparent in editor view
- Consider color-coding by region type
- Camera preview could animate (smooth transition)
- May want "camera path" for cinematics (multiple cameras)
- Region handles should scale with zoom level
