# Issue 404b: Path Following Logic

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Parent:** 404-create-unit-movement-system.md
**Dependencies:** 404a-core-movement-system, 403-implement-basic-pathfinding

---

## Current Behavior

The movement component (404a) stores path data and last positions for interpolation, but no logic exists to actually move units along their paths. The movement system skeleton updates `last_x`/`last_y` but doesn't progress units through waypoints.

---

## Intended Behavior

Path following logic that:
- Moves units toward current waypoint at their effective speed
- Progresses to next waypoint when current is reached
- Handles unit rotation/facing during movement
- Calculates arrival threshold for waypoint completion
- Clears path data when destination is reached

**Core Movement Math:**
```lua
-- Per-tick movement calculation
local effective_speed = mov.speed * mov.speed_modifier
local distance_this_tick = effective_speed * dt

-- Direction to current waypoint
local target = mov.path[mov.path_index]
local dx = target.x - pos.x
local dy = target.y - pos.y
local distance_to_waypoint = math.sqrt(dx * dx + dy * dy)

-- Normalize and apply movement
if distance_to_waypoint > 0 then
    local nx = dx / distance_to_waypoint
    local ny = dy / distance_to_waypoint

    if distance_this_tick >= distance_to_waypoint then
        -- Arrived at waypoint
        pos.x = target.x
        pos.y = target.y
        mov.path_index = mov.path_index + 1
    else
        -- Move toward waypoint
        pos.x = pos.x + nx * distance_this_tick
        pos.y = pos.y + ny * distance_this_tick
    end
end
```

---

## Suggested Implementation Steps

1. **Add path following to movement system**
   ```lua
   -- src/runtime/systems/movement.lua

   -- {{{ update_movement
   -- Moves entity along its path for one tick.
   local function update_movement(entity, pos, mov, dt)
       -- No path or path complete
       if not mov.path or mov.path_index > #mov.path then
           return
       end

       local effective_speed = mov.speed * mov.speed_modifier
       -- Clamp speed to WC3 limits
       effective_speed = math.min(effective_speed, movement.SPEED.MAX)
       effective_speed = math.max(effective_speed, movement.SPEED.VERY_SLOW * movement.MIN_SPEED_MODIFIER)

       local distance_remaining = effective_speed * dt

       -- Process multiple waypoints if moving fast enough
       while distance_remaining > 0 and mov.path_index <= #mov.path do
           local target = mov.path[mov.path_index]
           local dx = target.x - pos.x
           local dy = target.y - pos.y
           local distance_to_waypoint = math.sqrt(dx * dx + dy * dy)

           if distance_to_waypoint <= movement.ARRIVAL_THRESHOLD then
               -- Close enough, snap to waypoint and advance
               pos.x = target.x
               pos.y = target.y
               mov.path_index = mov.path_index + 1
           elseif distance_remaining >= distance_to_waypoint then
               -- Can reach this waypoint, continue to next
               pos.x = target.x
               pos.y = target.y
               distance_remaining = distance_remaining - distance_to_waypoint
               mov.path_index = mov.path_index + 1
           else
               -- Partial movement toward waypoint
               local nx = dx / distance_to_waypoint
               local ny = dy / distance_to_waypoint
               pos.x = pos.x + nx * distance_remaining
               pos.y = pos.y + ny * distance_remaining
               distance_remaining = 0
           end
       end

       -- Path complete
       if mov.path_index > #mov.path then
           mov.path = nil
           mov.target = nil
       end
   end
   -- }}}
   ```

2. **Add arrival threshold constant**
   ```lua
   -- {{{ Constants
   -- Minimum distance to consider "arrived" at a waypoint
   movement.ARRIVAL_THRESHOLD = 4.0  -- World units
   -- }}}
   ```

3. **Implement rotation/facing updates**
   ```lua
   -- {{{ update_facing
   -- Updates entity facing toward movement direction.
   local function update_facing(entity, pos, mov, dt)
       if not mov.path or mov.path_index > #mov.path then
           return
       end

       local target = mov.path[mov.path_index]
       local dx = target.x - pos.x
       local dy = target.y - pos.y

       if dx == 0 and dy == 0 then
           return
       end

       -- Calculate target angle
       local target_angle = math.atan2(dy, dx)

       -- Get current facing (if position component has it)
       local current_angle = pos.facing or 0

       -- Calculate angle difference (shortest path)
       local diff = target_angle - current_angle
       while diff > math.pi do diff = diff - 2 * math.pi end
       while diff < -math.pi do diff = diff + 2 * math.pi end

       -- Apply turn rate
       local max_turn = mov.turn_rate * dt
       if math.abs(diff) <= max_turn then
           pos.facing = target_angle
       elseif diff > 0 then
           pos.facing = current_angle + max_turn
       else
           pos.facing = current_angle - max_turn
       end

       -- Normalize facing to [0, 2pi)
       while pos.facing < 0 do pos.facing = pos.facing + 2 * math.pi end
       while pos.facing >= 2 * math.pi do pos.facing = pos.facing - 2 * math.pi end
   end
   -- }}}
   ```

4. **Update the movement system tick function**
   ```lua
   -- {{{ movement_system_update
   local function movement_system_update(entities, dt)
       for _, entity in ipairs(entities) do
           local pos = ecs.get_component(entity, "position")
           local mov = ecs.get_component(entity, "movement")

           if pos and mov then
               -- Store last position for interpolation (before movement)
               mov.last_x = pos.x
               mov.last_y = pos.y

               -- Update facing first (so unit turns toward destination)
               update_facing(entity, pos, mov, dt)

               -- Then apply movement
               update_movement(entity, pos, mov, dt)
           end
       end
   end
   -- }}}
   ```

5. **Add path setting function**
   ```lua
   -- {{{ movement.set_path
   -- Sets a new path for an entity to follow.
   function movement.set_path(entity, path)
       local mov = ecs.get_component(entity, "movement")
       if not mov then
           return false, "Entity has no movement component"
       end

       if not path or #path == 0 then
           -- Clear path
           mov.path = nil
           mov.target = nil
           mov.path_index = 1
           return true
       end

       mov.path = path
       mov.path_index = 1
       mov.target = path[#path]  -- Final destination

       return true
   end
   -- }}}
   ```

6. **Add distance calculation helpers**
   ```lua
   -- {{{ movement.distance_to_target
   -- Returns distance to final destination, or 0 if no path.
   function movement.distance_to_target(entity)
       local pos = ecs.get_component(entity, "position")
       local mov = ecs.get_component(entity, "movement")

       if not pos or not mov or not mov.target then
           return 0
       end

       local dx = mov.target.x - pos.x
       local dy = mov.target.y - pos.y
       return math.sqrt(dx * dx + dy * dy)
   end
   -- }}}

   -- {{{ movement.distance_to_next_waypoint
   function movement.distance_to_next_waypoint(entity)
       local pos = ecs.get_component(entity, "position")
       local mov = ecs.get_component(entity, "movement")

       if not pos or not mov or not mov.path then
           return 0
       end

       local waypoint = mov.path[mov.path_index]
       if not waypoint then
           return 0
       end

       local dx = waypoint.x - pos.x
       local dy = waypoint.y - pos.y
       return math.sqrt(dx * dx + dy * dy)
   end
   -- }}}
   ```

7. **Add estimated time calculation**
   ```lua
   -- {{{ movement.time_to_destination
   -- Estimates time to reach destination at current speed.
   function movement.time_to_destination(entity)
       local mov = ecs.get_component(entity, "movement")
       if not mov or not mov.path then
           return 0
       end

       local pos = ecs.get_component(entity, "position")
       if not pos then
           return 0
       end

       -- Sum distances for remaining path
       local total_distance = 0
       local cx, cy = pos.x, pos.y

       for i = mov.path_index, #mov.path do
           local wp = mov.path[i]
           local dx = wp.x - cx
           local dy = wp.y - cy
           total_distance = total_distance + math.sqrt(dx * dx + dy * dy)
           cx, cy = wp.x, wp.y
       end

       local speed = movement.get_effective_speed(entity)
       if speed <= 0 then
           return math.huge
       end

       return total_distance / speed
   end
   -- }}}
   ```

8. **Create unit tests**
   ```
   src/tests/test_movement_path.lua
   ```

9. **Test scenarios**
   - Single waypoint path completion
   - Multi-waypoint path following
   - Speed modifier affects movement rate
   - Turn rate affects facing changes
   - Path cleared when destination reached
   - Distance and time calculations accurate
   - Fast units can skip multiple waypoints per tick

---

## Related Documents

- issues/404-create-unit-movement-system.md (parent issue)
- issues/404a-core-movement-system.md (provides component and system)
- issues/404c-movement-orders.md (provides order interface)
- issues/403-implement-basic-pathfinding.md (provides paths)
- src/runtime/systems/movement.lua (implementation file)

---

## Acceptance Criteria

- [x] `update_movement()` moves units along paths
- [x] Units progress through waypoints correctly
- [x] Speed modifiers affect movement rate
- [x] Turn rate affects facing changes
- [x] `movement.set_path()` sets new paths
- [x] Paths cleared when destination reached
- [x] `distance_to_target()` returns correct distance
- [x] `time_to_destination()` estimates correctly
- [x] Fast units can traverse multiple waypoints per tick (via recursion in update_movement)
- [x] Unit tests pass

---

## Notes

The movement loop processes multiple waypoints per tick to handle fast units or low frame rates. Without this, a unit moving at 400 units/second with a 0.1s tick would move 40 units, potentially overshooting multiple close waypoints.

The arrival threshold (4.0 units) prevents units from oscillating around waypoints due to floating-point precision. This value may need tuning based on visual appearance.

Facing updates happen before movement so the unit appears to turn toward its destination before moving. This matches WC3's behavior where units don't moonwalk.

The turn rate of 0.6 radians/second (~34 degrees) is approximate. WC3 has per-unit turn rates that vary significantly (infantry turns faster than siege engines).

---

## Implementation Notes

**Completed: 2025-12-29**

### Changes Made

1. **Added path following functions to `src/runtime/systems/movement.lua`:**
   - `update_facing()` - Rotates entity toward waypoint at turn_rate
   - `update_movement()` - Moves entity along path, handles waypoint progression
   - `movement.set_path()` - Sets path and target for entity
   - `movement.distance_to_point()` - Base distance calculation
   - `movement.distance_to_next_waypoint()` - Distance to current waypoint
   - `movement.distance_to_target()` - Distance to final destination
   - `movement.time_to_destination()` - Estimated arrival time

2. **Updated `movement_system_update()` to call path following logic**
   - Stores last_x/last_y before movement for interpolation
   - Calls update_facing() then update_movement() each tick

3. **Created test file `src/tests/test_movement_path.lua`:**
   - 49 tests covering set_path, distance helpers, time calculation
   - Movement execution, multi-waypoint paths, facing updates
   - Speed modifiers, max speed cap, arrival threshold
   - All tests passing

### Design Decisions

- **Local helper functions**: update_facing() and update_movement() are local functions
  that receive the movement module as a parameter for constant access. This avoids
  forward-declaration issues in Lua while keeping the system update clean.

- **Recursive waypoint handling**: update_movement() uses recursion to handle multiple
  waypoints per tick. When arrival threshold is reached, it advances to next waypoint
  and recurses to continue movement in the same tick.

- **Facing normalization**: Facing is normalized to [0, 2π) after each update to
  maintain consistent angle representation.

- **Speed clamping in update_movement**: The local helper duplicates speed clamping
  logic rather than calling get_effective_speed() to avoid extra ECS lookups per tick.

### Test Results

```
test_movement_core.lua: 90 passed, 0 failed
test_movement_path.lua: 49 passed, 0 failed
```

