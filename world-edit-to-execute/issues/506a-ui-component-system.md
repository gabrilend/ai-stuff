# Issue 506a: UI Component System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 506
**Priority:** High
**Dependencies:** 501a

---

## Current Behavior

No UI component system. UI elements would need to be drawn manually without structure or hierarchy.

---

## Intended Behavior

Base component class with hierarchy, visibility, and update lifecycle:

```lua
-- src/ui/component.lua
local Component = {}
Component.__index = Component

function Component.new(config)
    local self = setmetatable({}, Component)

    -- Identity
    self.id = config.id or generate_id()
    self.type = "component"

    -- Hierarchy
    self.parent = nil
    self.children = {}

    -- Transform (local to parent)
    self.x = config.x or 0
    self.y = config.y or 0
    self.width = config.width or 0
    self.height = config.height or 0

    -- State
    self.visible = config.visible ~= false
    self.enabled = config.enabled ~= false
    self.focused = false
    self.hovered = false

    -- Style
    self.style = config.style or {}

    return self
end

-- Hierarchy management
function Component:add_child(child)
    child.parent = self
    table.insert(self.children, child)
    return child
end

function Component:remove_child(child)
    for i, c in ipairs(self.children) do
        if c == child then
            table.remove(self.children, i)
            child.parent = nil
            return true
        end
    end
    return false
end

-- Coordinate conversion
function Component:get_absolute_position()
    local ax, ay = self.x, self.y
    if self.parent then
        local px, py = self.parent:get_absolute_position()
        ax = ax + px
        ay = ay + py
    end
    return ax, ay
end

-- Hit testing
function Component:contains_point(px, py)
    local ax, ay = self:get_absolute_position()
    return px >= ax and px < ax + self.width and
           py >= ay and py < ay + self.height
end

-- Lifecycle methods (override in subclasses)
function Component:update(dt)
    for _, child in ipairs(self.children) do
        if child.enabled then
            child:update(dt)
        end
    end
end

function Component:draw(renderer)
    if not self.visible then return end

    self:draw_self(renderer)

    for _, child in ipairs(self.children) do
        child:draw(renderer)
    end
end

function Component:draw_self(renderer)
    -- Override in subclasses
end

-- Event callbacks (override in subclasses)
function Component:on_mouse_enter() end
function Component:on_mouse_leave() end
function Component:on_click(button, x, y) end
function Component:on_focus() end
function Component:on_blur() end
```

---

## Suggested Implementation Steps

1. **Create base Component class**
   - Properties: position, size, visibility, enabled
   - Parent/children hierarchy
   - Unique ID generation

2. **Implement coordinate conversion**
   - Local to absolute position
   - Absolute to local position
   - Handle nested transforms

3. **Implement hit testing**
   - Point containment check
   - Recursive child hit testing
   - Return deepest hit component

4. **Implement lifecycle methods**
   - update(dt) propagation
   - draw(renderer) with visibility check
   - Depth-first child traversal

5. **Define event callback stubs**
   - Mouse enter/leave
   - Click with button and position
   - Focus/blur for keyboard

6. **Create component registry**
   - Track all components by ID
   - Find component by ID
   - Debug listing

---

## Acceptance Criteria

- [ ] Component class with position/size properties
- [ ] Parent/child hierarchy works correctly
- [ ] Absolute position calculation correct
- [ ] Hit testing identifies correct component
- [ ] Lifecycle methods propagate to children
- [ ] Event callbacks can be overridden

---

## Notes

This is the foundation for all UI elements. Keep it lightweight but extensible.

**Design principles:**
- Composition over inheritance
- Minimal base class, behavior added via mixins
- Consistent coordinate system (origin top-left)
- Children draw after parent (painter's algorithm)

---

## Related Documents

- issues/506-build-ui-framework.md (parent issue)
- issues/501a-define-renderer-interface.md (draw calls)
- issues/506b-layout-system.md (positioning logic)
- issues/506c-input-handling.md (event dispatch)
