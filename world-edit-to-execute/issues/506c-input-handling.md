# Issue 506c: Input Handling

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 506
**Priority:** High
**Dependencies:** 506a

---

## Current Behavior

No UI input handling. Mouse clicks and keyboard input not routed to UI components.

---

## Intended Behavior

Input dispatch system with hover, focus, and hotkeys:

```lua
-- src/ui/input.lua
local ui_input = {}

local focused_component = nil
local hovered_component = nil
local root_component = nil

function ui_input.set_root(component)
    root_component = component
end

-- Hit testing - find deepest component at point
function ui_input.hit_test(x, y, component)
    component = component or root_component
    if not component or not component.visible then return nil end

    -- Check children first (front to back = reverse order)
    for i = #component.children, 1, -1 do
        local hit = ui_input.hit_test(x, y, component.children[i])
        if hit then return hit end
    end

    -- Check self
    if component:contains_point(x, y) then
        return component
    end

    return nil
end

-- Mouse movement
function ui_input.on_mouse_move(x, y)
    local new_hover = ui_input.hit_test(x, y)

    if new_hover ~= hovered_component then
        if hovered_component then
            hovered_component.hovered = false
            hovered_component:on_mouse_leave()
        end

        hovered_component = new_hover

        if hovered_component then
            hovered_component.hovered = true
            hovered_component:on_mouse_enter()
        end
    end
end

-- Mouse clicks
function ui_input.on_mouse_press(x, y, button)
    local target = ui_input.hit_test(x, y)

    -- Update focus
    if target ~= focused_component then
        if focused_component then
            focused_component.focused = false
            focused_component:on_blur()
        end

        focused_component = target

        if focused_component then
            focused_component.focused = true
            focused_component:on_focus()
        end
    end

    -- Dispatch click
    if target and target.enabled then
        target:on_click(button, x, y)
        return true  -- Consumed
    end

    return false  -- Not consumed, pass to game
end

-- Keyboard input
function ui_input.on_key_press(key, scancode, is_repeat)
    -- Focused component gets first chance
    if focused_component and focused_component.enabled then
        if focused_component:on_key_press(key, scancode, is_repeat) then
            return true
        end
    end

    -- Check global hotkeys
    return ui_input.check_hotkey(key)
end

-- Hotkey system
local hotkeys = {}

function ui_input.register_hotkey(key, callback, description)
    hotkeys[key] = {
        callback = callback,
        description = description,
    }
end

function ui_input.unregister_hotkey(key)
    hotkeys[key] = nil
end

function ui_input.check_hotkey(key)
    local hotkey = hotkeys[key]
    if hotkey then
        hotkey.callback()
        return true
    end
    return false
end

-- Focus management
function ui_input.set_focus(component)
    if focused_component then
        focused_component.focused = false
        focused_component:on_blur()
    end

    focused_component = component

    if focused_component then
        focused_component.focused = true
        focused_component:on_focus()
    end
end

function ui_input.get_focus()
    return focused_component
end

function ui_input.clear_focus()
    ui_input.set_focus(nil)
end

return ui_input
```

---

## Suggested Implementation Steps

1. **Implement hit testing**
   - Recursive depth-first search
   - Return deepest hit component
   - Respect visibility flags

2. **Implement hover tracking**
   - Track current hovered component
   - Fire mouse_enter/leave events
   - Update hover state

3. **Implement click dispatch**
   - Route clicks to hit component
   - Update focus on click
   - Return consumed flag

4. **Implement focus system**
   - Track focused component
   - Fire focus/blur events
   - Support programmatic focus

5. **Implement hotkey system**
   - Register key -> callback mappings
   - Check hotkeys on key press
   - Support modifier keys (ctrl, shift, alt)

6. **Integrate with game input**
   - UI gets input first
   - Pass through unconsumed input
   - Clear focus on escape

---

## Acceptance Criteria

- [ ] Hit testing finds correct component
- [ ] Hover events fire on mouse enter/leave
- [ ] Clicks dispatch to correct component
- [ ] Focus changes on click
- [ ] Hotkeys trigger callbacks
- [ ] Unconsumed input passes to game

---

## Notes

Input should follow this priority:
1. Focused UI component
2. Hovered UI component (for clicks)
3. Global hotkeys
4. Game input (camera, selection)

**Modal dialogs:**
When a modal is open, it should capture all input. Clicks outside dismiss or are blocked.

---

## Related Documents

- issues/506a-ui-component-system.md (component base)
- issues/505e-input-commands.md (game input)
- issues/506-build-ui-framework.md (parent issue)
