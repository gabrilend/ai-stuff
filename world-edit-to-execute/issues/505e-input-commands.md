# Issue 505e: Input Commands

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 505
**Priority:** High
**Dependencies:** 505c

---

## Current Behavior

No input handling. Players cannot select units or issue commands.

---

## Intended Behavior

RTS-style input handling:

```lua
-- src/input/commands.lua
local commands = {}
local selection = require("input.selection")
local camera = require("render.camera")
local orders = require("runtime.orders")

-- Left click: Select
function commands.on_left_click(sx, sy)
    local wx, wy = camera.screen_to_world(sx, sy)
    local entity = find_entity_at(wx, wy)

    if entity then
        if is_shift_down() then
            selection.toggle(entity)
        else
            selection.set({entity})
        end
    else
        selection.clear()
    end
end

-- Right click: Command
function commands.on_right_click(sx, sy)
    local wx, wy = camera.screen_to_world(sx, sy)
    local target_entity = find_entity_at(wx, wy)

    for entity in selection.get() do
        if target_entity and is_enemy(target_entity) then
            orders.attack(entity, target_entity)
        else
            orders.move(entity, wx, wy)
        end
    end
end

-- Box select (drag)
function commands.on_drag_start(sx, sy)
    selection.start_box(sx, sy)
end

function commands.on_drag_update(sx, sy)
    selection.update_box(sx, sy)
end

function commands.on_drag_end(sx, sy)
    local entities = find_entities_in_box(selection.get_box())
    selection.set(entities)
end
```

---

## Suggested Implementation Steps

1. **Implement click detection**
   - Left click = select
   - Right click = command
   - Convert screen to world coords

2. **Implement entity picking**
   ```lua
   function find_entity_at(wx, wy)
       for entity in ecs.query("position") do
           local pos = ecs.get(entity, "position")
           local size = get_entity_size(entity)
           if distance(wx, wy, pos.x, pos.y) < size then
               return entity
           end
       end
       return nil
   end
   ```

3. **Implement selection state**
   - Store currently selected entities
   - Support multi-select
   - Shift+click to add/remove

4. **Implement box selection**
   - Drag to draw box
   - Select all entities in box
   - Visual feedback during drag

5. **Implement command issuance**
   - Right-click on ground = move
   - Right-click on enemy = attack
   - Right-click on ally = follow/assist

6. **Add hotkeys**
   - A = attack-move
   - S = stop
   - H = hold position
   - Esc = clear selection

---

## Acceptance Criteria

- [ ] Left-click selects single unit
- [ ] Shift+click adds to selection
- [ ] Right-click moves selected units
- [ ] Box select works with drag
- [ ] Right-click on enemy issues attack
- [ ] Hotkeys work correctly

---

## Notes

Input handling is critical for playability. Must be responsive and predictable.

**Smart targeting:**
Right-click context:
- Ground → Move
- Enemy unit → Attack
- Friendly unit → Follow
- Resource → Harvest
- Building → Repair/enter

---

## Related Documents

- issues/505c-game-view-camera.md (coordinate conversion)
- issues/404-create-unit-movement-system.md (movement orders)
- src/runtime/orders/ (order system)
