# Issue 507d: Camera Viewport

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 507
**Priority:** Medium
**Dependencies:** 507a, 501d

---

## Current Behavior

No camera indicator on minimap. Players cannot see which area of the map is currently visible.

---

## Intended Behavior

White rectangle showing current camera viewport:

```lua
-- src/ui/minimap/viewport.lua
local viewport = {}

-- Viewport rectangle color
local VIEWPORT_COLOR = {255, 255, 255, 200}
local VIEWPORT_THICKNESS = 1

function viewport.draw(renderer, minimap, camera)
    -- Get camera bounds in world coordinates
    local cam_x, cam_y = camera.x, camera.y
    local cam_w, cam_h = camera:get_view_size()

    -- Camera center to corner
    local left = cam_x - cam_w / 2
    local top = cam_y - cam_h / 2
    local right = cam_x + cam_w / 2
    local bottom = cam_y + cam_h / 2

    -- Clamp to map bounds
    local bounds = minimap.map_bounds
    left = math.max(left, bounds.min_x)
    top = math.max(top, bounds.min_y)
    right = math.min(right, bounds.max_x)
    bottom = math.min(bottom, bounds.max_y)

    -- Convert corners to minimap coordinates
    local mm_left, mm_top = minimap:world_to_minimap(left, top)
    local mm_right, mm_bottom = minimap:world_to_minimap(right, bottom)

    local mm_w = mm_right - mm_left
    local mm_h = mm_bottom - mm_top

    -- Draw viewport rectangle (outline only)
    renderer:draw_rect(mm_left, mm_top, mm_w, mm_h,
                       VIEWPORT_COLOR, false)

    -- Optional: thicker lines for visibility
    if VIEWPORT_THICKNESS > 1 then
        for i = 1, VIEWPORT_THICKNESS do
            renderer:draw_rect(mm_left - i, mm_top - i,
                              mm_w + i * 2, mm_h + i * 2,
                              VIEWPORT_COLOR, false)
        end
    end
end

-- Calculate viewport rectangle without drawing (for hit testing)
function viewport.get_bounds(minimap, camera)
    local cam_x, cam_y = camera.x, camera.y
    local cam_w, cam_h = camera:get_view_size()

    local left = cam_x - cam_w / 2
    local top = cam_y - cam_h / 2

    local mm_left, mm_top = minimap:world_to_minimap(left, top)
    local mm_right, mm_bottom = minimap:world_to_minimap(
        cam_x + cam_w / 2, cam_y + cam_h / 2
    )

    return {
        x = mm_left,
        y = mm_top,
        width = mm_right - mm_left,
        height = mm_bottom - mm_top,
    }
end

-- Check if point is inside viewport (for drag detection)
function viewport.contains_point(minimap, camera, mx, my)
    local bounds = viewport.get_bounds(minimap, camera)
    return mx >= bounds.x and mx < bounds.x + bounds.width and
           my >= bounds.y and my < bounds.y + bounds.height
end

return viewport
```

---

## Suggested Implementation Steps

1. **Get camera view bounds**
   - Camera position (center)
   - View width/height from zoom
   - Handle zoom levels

2. **Convert to minimap coordinates**
   - Use minimap:world_to_minimap()
   - Calculate all four corners

3. **Clamp to map bounds**
   - Viewport shouldn't extend beyond map
   - Handle edge cases

4. **Draw viewport rectangle**
   - White outline (not filled)
   - Visible against terrain
   - Not too thick

5. **Update each frame**
   - Viewport moves with camera
   - Resizes with zoom

6. **Add hit testing**
   - For drag-to-move feature
   - Detect clicks inside viewport

---

## Acceptance Criteria

- [ ] White rectangle shows visible area
- [ ] Rectangle moves with camera
- [ ] Rectangle resizes with zoom
- [ ] Rectangle clamped to map bounds
- [ ] Visible against all terrain types

---

## Notes

The viewport indicator is crucial for orientation. It answers "where am I looking?"

**WC3 behavior:**
- White rectangle, thin outline
- Always visible on minimap
- Scales with zoom level
- Can click outside to move camera

**Edge cases:**
- Very zoomed out: viewport nearly fills minimap
- Very zoomed in: very small rectangle
- Camera at map edge: partial rectangle

---

## Related Documents

- issues/507a-minimap-module.md (parent component)
- issues/501d-implement-camera-system.md (camera data)
- issues/507e-minimap-interaction.md (click to move)
