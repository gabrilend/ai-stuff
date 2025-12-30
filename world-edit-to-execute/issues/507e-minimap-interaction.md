# Issue 507e: Minimap Interaction

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 507
**Priority:** Medium
**Dependencies:** 507a, 507b, 507c, 507d

---

## Current Behavior

Minimap is display-only. Players cannot click to move camera or issue commands.

---

## Intended Behavior

Interactive minimap with click and drag support:

```lua
-- src/ui/minimap/interaction.lua
local interaction = {}

local camera = require("render.camera")
local orders = require("runtime.orders")
local selection = require("input.selection")

local is_dragging = false
local drag_button = nil

function interaction.init(minimap)
    minimap.on_click = interaction.on_click
    minimap.on_drag_start = interaction.on_drag_start
    minimap.on_drag_update = interaction.on_drag_update
    minimap.on_drag_end = interaction.on_drag_end
end

-- Left click: Move camera
-- Right click: Issue move command
function interaction.on_click(minimap, button, mx, my)
    local wx, wy = minimap:minimap_to_world(mx, my)

    if button == 1 then  -- Left click
        camera.set_position(wx, wy)
        return true  -- Consumed

    elseif button == 2 then  -- Right click
        local selected = selection.get()
        if #selected > 0 then
            for _, entity in ipairs(selected) do
                orders.move(entity, wx, wy)
            end
            return true
        end
    end

    return false
end

-- Drag: Pan camera (left) or attack-move (right)
function interaction.on_drag_start(minimap, button, mx, my)
    is_dragging = true
    drag_button = button

    local wx, wy = minimap:minimap_to_world(mx, my)

    if button == 1 then
        camera.set_position(wx, wy)
    end
end

function interaction.on_drag_update(minimap, mx, my)
    if not is_dragging then return end

    local wx, wy = minimap:minimap_to_world(mx, my)

    if drag_button == 1 then
        camera.set_position(wx, wy)
    end
end

function interaction.on_drag_end(minimap, mx, my)
    if not is_dragging then return end

    local wx, wy = minimap:minimap_to_world(mx, my)

    if drag_button == 2 then
        -- Right-drag release: attack-move to location
        local selected = selection.get()
        if #selected > 0 then
            for _, entity in ipairs(selected) do
                orders.attack_move(entity, wx, wy)
            end
        end
    end

    is_dragging = false
    drag_button = nil
end

-- Alt+click: Ping location
function interaction.on_alt_click(minimap, mx, my)
    local wx, wy = minimap:minimap_to_world(mx, my)

    -- Send ping to all players
    ping_system.create(wx, wy, "alert")

    return true
end

-- Handle modifier keys
function interaction.process_click(minimap, button, mx, my, modifiers)
    if modifiers.alt then
        return interaction.on_alt_click(minimap, mx, my)
    end

    return interaction.on_click(minimap, button, mx, my)
end

return interaction
```

---

## Suggested Implementation Steps

1. **Implement left-click camera move**
   - Click anywhere on minimap
   - Camera jumps to that location
   - Instant (no smooth pan)

2. **Implement right-click move order**
   - Right-click issues move to selected units
   - Convert minimap coords to world
   - Use existing order system

3. **Implement drag-to-pan**
   - Left-drag pans camera
   - Camera follows mouse
   - Smooth during drag

4. **Implement right-drag attack-move**
   - Hold right button and drag
   - Release to issue attack-move
   - Visual feedback during drag

5. **Add ping on alt-click**
   - Alt+click creates ping
   - Visible to all players
   - Audio alert

6. **Handle input priority**
   - Minimap consumes clicks when inside
   - Pass through when outside bounds

---

## Acceptance Criteria

- [ ] Left-click moves camera to location
- [ ] Right-click issues move order
- [ ] Left-drag pans camera smoothly
- [ ] Right-drag + release does attack-move
- [ ] Alt-click creates ping
- [ ] Clicks outside minimap pass through

---

## Notes

Minimap interaction is critical for fast gameplay. Must be responsive and predictable.

**WC3 minimap controls:**
- Left-click: Move camera
- Left-drag: Pan camera
- Right-click: Move units
- Right-drag: Attack-move
- Alt+G or Alt+click: Ping

**Bounds checking:**
Ensure minimap interactions only trigger when click is within minimap bounds. Margin for error near edges.

---

## Related Documents

- issues/507a-minimap-module.md (parent component)
- issues/507d-camera-viewport.md (camera integration)
- issues/505e-input-commands.md (order system)
- issues/506c-input-handling.md (UI input)
