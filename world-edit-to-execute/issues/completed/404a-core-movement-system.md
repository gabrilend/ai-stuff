# Issue 404a: Core Movement System

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 404-create-unit-movement-system.md
**Dependencies:** 401-implement-game-tick-update-loop, 402-build-entity-component-system

---

## Current Behavior

The ECS (402) provides entity and component infrastructure. The game tick loop (401) calls registered systems each frame. However, no movement component or movement system exists. Units have position data from the `position` component but no velocity, speed, or pathing information.

---

## Intended Behavior

Core movement system infrastructure that:
- Defines the movement component with all required fields
- Registers the movement system with the ECS
- Stores previous positions for rendering interpolation
- Provides the foundation for path-following logic (404b)

**Movement Component Structure:**
```lua
{
    -- Base movement properties
    speed = 270,              -- Base speed in world units/second
    speed_modifier = 1.0,     -- Multiplier from buffs/debuffs (0.1 to 2.0+)

    -- Current movement state
    target = nil,             -- Target position {x, y} or nil if idle
    path = nil,               -- Array of waypoint {x, y} tables
    path_index = 1,           -- Index of current waypoint in path

    -- Movement type (for pathfinding)
    pathing_type = "foot",    -- foot, horse, fly, float, hover, amphibious

    -- Rotation
    turn_rate = 0.6,          -- Radians per second

    -- Interpolation for smooth rendering
    last_x = 0,               -- X position at start of tick
    last_y = 0,               -- Y position at start of tick
}
```

---

## Suggested Implementation Steps

1. **Create the movement system module**
   ```
   src/runtime/systems/
   └── movement.lua
   ```

2. **Define movement component schema**
   ```lua
   -- src/runtime/systems/movement.lua
   local ecs = require("runtime.ecs")

   local movement = {}

   -- {{{ Component definition
   local MOVEMENT_DEFAULTS = {
       speed = 270,
       speed_modifier = 1.0,
       target = nil,
       path = nil,
       path_index = 1,
       pathing_type = "foot",
       turn_rate = 0.6,
       last_x = 0,
       last_y = 0,
   }

   ecs.register_component("movement", MOVEMENT_DEFAULTS)
   -- }}}
   ```

3. **Define movement speed constants**
   ```lua
   -- {{{ Speed constants
   -- WC3 movement speed reference values
   movement.SPEED = {
       VERY_SLOW = 150,
       SLOW = 220,
       NORMAL = 270,
       FAST = 320,
       VERY_FAST = 400,
       MAX = 522,  -- WC3's hard cap
   }

   -- Minimum speed modifier (prevents units from being completely immobilized)
   movement.MIN_SPEED_MODIFIER = 0.1
   movement.MAX_SPEED_MODIFIER = 4.0
   -- }}}
   ```

4. **Define pathing type constants**
   ```lua
   -- {{{ Pathing types
   movement.PATHING_TYPE = {
       FOOT = "foot",
       HORSE = "horse",
       FLY = "fly",
       FLOAT = "float",
       HOVER = "hover",
       AMPHIBIOUS = "amphibious",
   }
   -- }}}
   ```

5. **Register the movement system**
   ```lua
   -- {{{ System registration
   -- The movement system runs on entities with both position and movement components
   local function movement_system_update(entities, dt)
       for _, entity in ipairs(entities) do
           local pos = ecs.get_component(entity, "position")
           local mov = ecs.get_component(entity, "movement")

           if pos and mov then
               -- Store last position for interpolation (before any movement)
               mov.last_x = pos.x
               mov.last_y = pos.y

               -- Actual movement logic is in 404b
               -- This system just ensures interpolation data is updated
               if mov.path and mov.path_index <= #mov.path then
                   -- Movement update will be added in 404b
                   -- movement.update_movement(entity, pos, mov, dt)
               end
           end
       end
   end

   ecs.register_system("movement", {"position", "movement"}, movement_system_update)
   -- }}}
   ```

6. **Add component creation helper**
   ```lua
   -- {{{ movement.create_component
   -- Creates a movement component with specified overrides
   function movement.create_component(overrides)
       local component = {}
       for k, v in pairs(MOVEMENT_DEFAULTS) do
           component[k] = v
       end
       if overrides then
           for k, v in pairs(overrides) do
               component[k] = v
           end
       end
       return component
   end
   -- }}}
   ```

7. **Add interpolation helper**
   ```lua
   -- {{{ movement.get_interpolated_position
   -- Returns interpolated position for smooth rendering
   -- alpha: 0.0 = last position, 1.0 = current position
   function movement.get_interpolated_position(entity, alpha)
       local pos = ecs.get_component(entity, "position")
       local mov = ecs.get_component(entity, "movement")

       if not pos or not mov then
           return nil, nil
       end

       local x = mov.last_x + (pos.x - mov.last_x) * alpha
       local y = mov.last_y + (pos.y - mov.last_y) * alpha

       return x, y
   end
   -- }}}
   ```

8. **Add movement state query helpers**
   ```lua
   -- {{{ State queries
   function movement.is_moving(entity)
       local mov = ecs.get_component(entity, "movement")
       return mov and mov.path ~= nil and mov.path_index <= #mov.path
   end

   function movement.get_target(entity)
       local mov = ecs.get_component(entity, "movement")
       return mov and mov.target
   end

   function movement.get_effective_speed(entity)
       local mov = ecs.get_component(entity, "movement")
       if not mov then return 0 end
       return mov.speed * mov.speed_modifier
   end
   -- }}}
   ```

9. **Export the module**
   ```lua
   -- {{{ Exports
   movement.DEFAULTS = MOVEMENT_DEFAULTS
   -- }}}

   return movement
   ```

10. **Create unit tests**
    ```
    src/tests/test_movement_core.lua
    ```

11. **Test scenarios**
    - Component creation with defaults
    - Component creation with overrides
    - Interpolation calculation
    - Movement state queries (is_moving, get_target)
    - Effective speed calculation with modifiers

---

## Related Documents

- issues/404-create-unit-movement-system.md (parent issue)
- issues/404b-path-following-logic.md (adds movement math)
- issues/404c-movement-orders.md (adds order interface)
- issues/401-implement-game-tick-update-loop.md (provides dt)
- issues/402-build-entity-component-system.md (ECS foundation)
- src/runtime/ecs/init.lua (ECS implementation)

---

## Acceptance Criteria

- [x] `src/runtime/systems/movement.lua` exists
- [x] Movement component registered with ECS
- [x] Component includes all required fields (speed, target, path, etc.)
- [x] Movement system registered and runs each tick
- [x] `last_x`/`last_y` updated before movement processing
- [x] `get_interpolated_position()` calculates lerp correctly
- [x] Speed constants defined (SLOW, NORMAL, FAST, etc.)
- [x] Pathing type constants defined
- [x] State query functions work (is_moving, get_target, get_effective_speed)
- [x] Unit tests pass

---

## Implementation Notes

*Completed 2025-12-29*

### Created Files

- `src/runtime/systems/movement.lua` (~250 lines)
- `src/tests/test_movement_core.lua` (~400 lines)

### Module Structure

**Constants:**
- `SPEED` table: VERY_SLOW (150), SLOW (220), NORMAL (270), FAST (320), VERY_FAST (400), MAX (522)
- `PATHING_TYPE` table: FOOT, HORSE, FLY, FLOAT, HOVER, AMPHIBIOUS
- `MIN_SPEED_MODIFIER` (0.1), `MAX_SPEED_MODIFIER` (4.0)

**Component Fields:**
- `speed` (270), `speed_modifier` (1.0)
- `target` (nil), `path` (nil), `path_index` (1)
- `pathing_type` ("foot"), `turn_rate` (0.6)
- `last_x` (0), `last_y` (0) for interpolation

**Helper Functions:**
- `create_component(overrides)` - Create component with custom values
- `get_interpolated_position(entity, alpha)` - Lerp between last and current
- `is_moving(entity)` - Check if entity has active path
- `get_target(entity)` - Get destination
- `get_effective_speed(entity)` - Speed with modifiers and cap
- `get_current_waypoint(entity)` - Current path waypoint
- `get_remaining_waypoints(entity)` - Remaining path count
- `set_speed_modifier(entity, modifier)` - Set speed modifier with clamping
- `clear_path(entity)` - Stop movement

**System:**
- Registered as "movement" with priority 10
- Requires "position" and "movement" components
- Updates `last_x`/`last_y` each tick for interpolation

### Test Coverage

**90 tests across 11 sections:**
- Speed constants (8 tests)
- Pathing type constants (6 tests)
- Component defaults (9 tests)
- Component creation (6 tests)
- ECS integration (5 tests)
- System registration (6 tests)
- Interpolation (10 tests)
- State queries (9 tests)
- Effective speed (7 tests)
- Waypoint queries (9 tests)
- Speed modifier setter (5 tests)
- Clear path (7 tests)
- System update (2 tests)

### Design Notes

- Component registration checks for existing registration to avoid conflicts with wc3_components.lua
- Speed is capped at 522 (WC3's hard cap) regardless of modifiers
- Interpolation alpha is clamped to [0, 1] for safety
- System priority 10 runs after input but before rendering

---

## Notes

This issue establishes the data model and system skeleton. The actual movement logic (waypoint progression, turning) is implemented in 404b. This separation allows testing the component structure and interpolation independently.

The `last_x`/`last_y` fields are updated at the START of each tick, before any movement occurs. This ensures the renderer can interpolate between the position at tick start and the position after movement.

The movement system priority should be set appropriately in the ECS - it should run after input processing but before rendering-related systems.

WC3's max speed of 522 is a well-known hard cap. Speed modifiers are clamped to prevent absurd values (minimum 10% to avoid complete immobility from stacking slows).
