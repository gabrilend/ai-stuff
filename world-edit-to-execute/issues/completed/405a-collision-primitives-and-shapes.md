# Issue 405a: Collision Primitives and Shapes

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 405-implement-basic-collision-detection.md
**Dependencies:** 402-build-entity-component-system

---

## Current Behavior

No collision system exists. The ECS from 402 provides component infrastructure but there are no collision-related components or shape primitives defined.

---

## Intended Behavior

Implement the foundational collision system including:
- Collision component registration with the ECS
- Shape definitions (circle, rectangle, point)
- Core collision math functions (circle-circle, circle-rect, point-in-shape)
- Layer and mask system for filtering collision checks

**Component structure:**
```lua
{
    shape = "circle",      -- "circle", "rect", "point"
    radius = 32,           -- for circles
    width = 0, height = 0, -- for rects

    layer = "unit",        -- collision layer identifier
    mask = {"unit"},       -- layers this entity collides with

    solid = true,          -- blocks movement
    trigger = false,       -- fires events but doesn't block
}
```

**Collision math API:**
```lua
collision.circles_collide(x1, y1, r1, x2, y2, r2) -> boolean
collision.circle_rect_collide(cx, cy, cr, rx, ry, rw, rh) -> boolean
collision.point_in_circle(px, py, cx, cy, cr) -> boolean
collision.point_in_rect(px, py, rx, ry, rw, rh) -> boolean
collision.rects_collide(x1, y1, w1, h1, x2, y2, w2, h2) -> boolean
```

---

## Suggested Implementation Steps

1. **Create collision module directory structure**
   ```
   src/runtime/collision/
   ├── init.lua       (main API, exports)
   └── shapes.lua     (collision primitives)
   ```

2. **Implement shapes.lua with collision primitives**
   ```lua
   -- src/runtime/collision/shapes.lua
   local shapes = {}

   -- {{{ circles_collide
   -- Check if two circles overlap
   -- Returns true if distance between centers <= sum of radii
   function shapes.circles_collide(x1, y1, r1, x2, y2, r2)
       local dx = x2 - x1
       local dy = y2 - y1
       local dist_sq = dx * dx + dy * dy
       local radii_sum = r1 + r2
       return dist_sq <= radii_sum * radii_sum
   end
   -- }}}

   -- {{{ point_in_circle
   function shapes.point_in_circle(px, py, cx, cy, cr)
       local dx = px - cx
       local dy = py - cy
       return dx * dx + dy * dy <= cr * cr
   end
   -- }}}

   -- {{{ point_in_rect
   -- Rect defined by center (rx, ry) and half-dimensions (rw/2, rh/2)
   function shapes.point_in_rect(px, py, rx, ry, rw, rh)
       local hw, hh = rw / 2, rh / 2
       return px >= rx - hw and px <= rx + hw
          and py >= ry - hh and py <= ry + hh
   end
   -- }}}

   -- {{{ rects_collide
   -- AABB collision between two center-defined rects
   function shapes.rects_collide(x1, y1, w1, h1, x2, y2, w2, h2)
       local hw1, hh1 = w1 / 2, h1 / 2
       local hw2, hh2 = w2 / 2, h2 / 2
       return math.abs(x1 - x2) <= hw1 + hw2
          and math.abs(y1 - y2) <= hh1 + hh2
   end
   -- }}}

   -- {{{ circle_rect_collide
   -- Circle vs AABB collision
   function shapes.circle_rect_collide(cx, cy, cr, rx, ry, rw, rh)
       local hw, hh = rw / 2, rh / 2
       -- Find closest point on rect to circle center
       local closest_x = math.max(rx - hw, math.min(cx, rx + hw))
       local closest_y = math.max(ry - hh, math.min(cy, ry + hh))
       -- Check if closest point is within circle
       return shapes.point_in_circle(closest_x, closest_y, cx, cy, cr)
   end
   -- }}}

   return shapes
   ```

3. **Register collision component with ECS**
   ```lua
   -- In src/runtime/collision/init.lua
   local ecs = require("runtime.ecs")

   ecs.register_component("collision", {
       shape = "circle",
       radius = 32,
       width = 0,
       height = 0,
       layer = "unit",
       mask = {"unit"},
       solid = true,
       trigger = false,
   })
   ```

4. **Implement layer/mask filtering**
   ```lua
   -- {{{ layer_matches_mask
   -- Check if a layer string matches any entry in a mask table
   function collision.layer_matches_mask(layer, mask)
       if not mask then return true end
       for _, m in ipairs(mask) do
           if m == layer or m == "*" then
               return true
           end
       end
       return false
   end
   -- }}}
   ```

5. **Create collision shape constants**
   ```lua
   collision.SHAPE = {
       CIRCLE = "circle",
       RECT = "rect",
       POINT = "point",
   }

   collision.LAYER = {
       UNIT = "unit",
       BUILDING = "building",
       PROJECTILE = "projectile",
       TRIGGER = "trigger",
       DEBRIS = "debris",
   }
   ```

6. **Implement shape-agnostic collision test**
   ```lua
   -- {{{ shapes_collide
   -- Test collision between two entities based on their shape types
   function collision.shapes_collide(pos1, col1, pos2, col2)
       if col1.shape == "circle" and col2.shape == "circle" then
           return shapes.circles_collide(
               pos1.x, pos1.y, col1.radius,
               pos2.x, pos2.y, col2.radius
           )
       elseif col1.shape == "circle" and col2.shape == "rect" then
           return shapes.circle_rect_collide(
               pos1.x, pos1.y, col1.radius,
               pos2.x, pos2.y, col2.width, col2.height
           )
       elseif col1.shape == "rect" and col2.shape == "circle" then
           return shapes.circle_rect_collide(
               pos2.x, pos2.y, col2.radius,
               pos1.x, pos1.y, col1.width, col1.height
           )
       elseif col1.shape == "rect" and col2.shape == "rect" then
           return shapes.rects_collide(
               pos1.x, pos1.y, col1.width, col1.height,
               pos2.x, pos2.y, col2.width, col2.height
           )
       elseif col1.shape == "point" then
           if col2.shape == "circle" then
               return shapes.point_in_circle(pos1.x, pos1.y, pos2.x, pos2.y, col2.radius)
           elseif col2.shape == "rect" then
               return shapes.point_in_rect(pos1.x, pos1.y, pos2.x, pos2.y, col2.width, col2.height)
           end
       end
       return false
   end
   -- }}}
   ```

7. **Create unit tests**
   ```lua
   -- src/tests/test_collision_shapes.lua
   -- Test all collision primitives with known inputs/outputs
   -- Test layer_matches_mask with various combinations
   -- Test shapes_collide dispatch
   ```

---

## Related Documents

- issues/405-implement-basic-collision-detection.md (parent issue)
- issues/405b-spatial-hash-grid.md (next - uses collision bounds)
- issues/402-build-entity-component-system.md (component registration)
- src/runtime/ecs/init.lua (ECS module)

---

## Acceptance Criteria

- [x] `src/runtime/collision/shapes.lua` exists with all primitives
- [x] `circles_collide()` correctly detects overlapping circles
- [x] `point_in_circle()` correctly tests point containment
- [x] `point_in_rect()` correctly tests point containment
- [x] `rects_collide()` correctly tests AABB overlap
- [x] `circle_rect_collide()` correctly tests circle-AABB overlap
- [x] Collision component registered with ECS
- [x] Layer/mask filtering implemented
- [x] `shapes_collide()` dispatches to correct primitive based on shape types
- [x] Unit tests pass for all collision primitives
- [x] Constants defined for common shapes and layers

---

## Notes

All collision math uses squared distances to avoid expensive `sqrt()` calls. This is a common optimization in game collision detection.

Rectangles are defined by center position and full width/height (not half-dimensions in the component, but the math functions handle the conversion internally for clarity).

WC3 collision sizes for reference:
- Peasant/Footman: 16-24 radius
- Knight/Tauren: 32-48 radius
- Buildings: rectangular, various sizes
- Heroes: typically 24-32 radius

The layer system allows efficient filtering without checking all entities. Common patterns:
- Units collide with units and buildings
- Projectiles collide with units only (ignore buildings/other projectiles)
- Trigger regions detect unit entry (trigger=true, solid=false)

---

## Implementation Notes

*Completed 2025-12-29*

### Files Created

- `src/runtime/collision/shapes.lua` (~95 lines) - Collision primitives
- `src/runtime/collision/init.lua` (~165 lines) - Main API and component registration
- `src/tests/test_collision_shapes.lua` (~330 lines) - Comprehensive test suite

### API Implemented

**Shapes module:**
- `circles_collide()` - Circle-circle overlap detection
- `point_in_circle()` - Point containment in circle
- `point_in_rect()` - Point containment in AABB
- `rects_collide()` - AABB-AABB overlap detection
- `circle_rect_collide()` - Circle-AABB overlap detection
- `distance()` / `distance_squared()` - Distance calculations
- `get_separation_vector()` - Overlap resolution helper

**Collision module:**
- `collision.init(ecs)` - Initialize and register component
- `collision.layer_matches_mask()` - Layer/mask filtering
- `collision.shapes_collide()` - Shape-agnostic dispatch
- `collision.get_entity_radius()` - Effective radius for any shape
- `collision.get_layer_priority()` / `set_layer_priority()` - Selection priority
- Constants: `SHAPE`, `LAYER`

### Test Coverage

99 tests covering:
- Circle-circle collision (10 tests)
- Point-in-circle (7 tests)
- Point-in-rect (10 tests)
- Rect-rect collision (8 tests)
- Circle-rect collision (8 tests)
- Distance functions (7 tests)
- Separation vectors (6 tests)
- Layer/mask filtering (7 tests)
- Layer priority (4 tests)
- Component registration (9 tests)
- Shape dispatch (13 tests)
- Entity radius (3 tests)
- Constants (7 tests)
