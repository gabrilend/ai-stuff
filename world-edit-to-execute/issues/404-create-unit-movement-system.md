# Issue 404: Create Unit Movement System

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** High
**Dependencies:** 401, 402, 403

---

## Current Behavior

Units have position data but no ability to move. No movement orders, path
following, or velocity handling exists.

---

## Intended Behavior

A movement system that:
- Accepts move orders for entities
- Follows paths from the pathfinding system
- Updates entity positions each tick
- Handles movement speed modifiers
- Supports attack-move, patrol, and follow behaviors
- Provides smooth interpolation for rendering

---

## Suggested Implementation Steps

1. **Create movement system module**
   ```
   src/runtime/
   └── systems/
       └── movement.lua
   ```

2. **Define movement component**
   ```lua
   ecs.register_component("movement", {
       speed = 270,           -- base speed (world units/second)
       speed_modifier = 1.0,  -- multiplier from buffs/debuffs

       -- Current movement state
       target = nil,          -- {x, y} or nil
       path = nil,            -- list of waypoints
       path_index = 1,        -- current waypoint

       -- Movement type
       pathing_type = "foot", -- foot, fly, float, etc.
       turn_rate = 0.6,       -- radians per second

       -- Interpolation for rendering
       last_x = 0,
       last_y = 0,
   })
   ```

3. **Implement move order**
   ```lua
   function movement.order_move(entity, target_x, target_y)
       local pos = ecs.get_component(entity, "position")
       local mov = ecs.get_component(entity, "movement")

       -- Request path from pathfinding
       local path = pathfinding.find_path(
           {x = pos.x, y = pos.y},
           {x = target_x, y = target_y},
           mov.pathing_type
       )

       if path then
           mov.path = path
           mov.path_index = 1
           mov.target = {x = target_x, y = target_y}
       end
   end
   ```

4. **Implement movement system update**
   ```lua
   ecs.register_system("movement", {"position", "movement"}, function(entities, dt)
       for _, entity in ipairs(entities) do
           local pos = ecs.get_component(entity, "position")
           local mov = ecs.get_component(entity, "movement")

           -- Store last position for interpolation
           mov.last_x = pos.x
           mov.last_y = pos.y

           if mov.path and mov.path_index <= #mov.path then
               update_movement(entity, pos, mov, dt)
           end
       end
   end)
   ```

5. **Movement update logic**
   ```lua
   local function update_movement(entity, pos, mov, dt)
       local waypoint = mov.path[mov.path_index]
       local dx = waypoint.x - pos.x
       local dy = waypoint.y - pos.y
       local dist = math.sqrt(dx*dx + dy*dy)

       local speed = mov.speed * mov.speed_modifier
       local move_dist = speed * dt

       -- Turn towards waypoint
       local target_facing = math.atan2(dy, dx)
       pos.facing = approach_angle(pos.facing, target_facing, mov.turn_rate * dt)

       if dist <= move_dist then
           -- Reached waypoint
           pos.x = waypoint.x
           pos.y = waypoint.y
           mov.path_index = mov.path_index + 1

           if mov.path_index > #mov.path then
               -- Path complete
               mov.path = nil
               mov.target = nil
               fire_event("unit_reached_destination", entity)
           end
       else
           -- Move towards waypoint
           local ratio = move_dist / dist
           pos.x = pos.x + dx * ratio
           pos.y = pos.y + dy * ratio
       end
   end
   ```

6. **Speed modifiers**
   ```lua
   function movement.set_speed_modifier(entity, modifier)
       local mov = ecs.get_component(entity, "movement")
       mov.speed_modifier = modifier
   end

   -- Called by buff/debuff system
   function movement.recalculate_speed(entity)
       local mov = ecs.get_component(entity, "movement")
       local buffs = ecs.get_component(entity, "buffs")

       local modifier = 1.0
       for _, buff in ipairs(buffs.active) do
           if buff.speed_modifier then
               modifier = modifier * buff.speed_modifier
           end
       end

       mov.speed_modifier = math.max(0.1, modifier)  -- Minimum 10% speed
   end
   ```

7. **Additional movement behaviors**
   ```lua
   function movement.order_attack_move(entity, target_x, target_y)
       -- Move but attack enemies encountered
   end

   function movement.order_patrol(entity, points)
       -- Cycle through waypoints
   end

   function movement.order_follow(entity, target_entity)
       -- Follow another unit
   end

   function movement.order_stop(entity)
       local mov = ecs.get_component(entity, "movement")
       mov.path = nil
       mov.target = nil
   end
   ```

---

## Technical Notes

### Movement Speed

WC3 movement speeds are in world units per second:
- Slow: ~200-250
- Normal: ~270-300
- Fast: ~320-350
- Very Fast: ~400+

### Turn Rate

Units in WC3 turn to face their movement direction. Turn rate affects
how quickly they can change direction. Flying units often have higher
turn rates.

### Interpolation

The movement system stores last_x/last_y for rendering interpolation.
The renderer can blend between last position and current position based
on the fractional tick time.

### Path Recalculation

Paths should be recalculated when:
- Target is blocked by a new building
- Unit gets significantly pushed off course
- Original path becomes invalid

This can be expensive, so limit recalculation frequency.

### Orders Queue

WC3 supports shift-queuing orders. Consider adding an order queue:
```lua
ecs.register_component("orders", {
    queue = {},  -- list of {type, params}
    current = nil,
})
```

---

## Related Documents

- issues/402-build-entity-component-system.md (ECS foundation)
- issues/403-implement-basic-pathfinding.md (provides paths)
- issues/405-implement-basic-collision-detection.md (unit avoidance)

---

## Acceptance Criteria

- [ ] Move order with pathfinding integration
- [ ] Position updates each tick
- [ ] Speed modifier support
- [ ] Turn rate and facing updates
- [ ] Waypoint progression
- [ ] Path completion events
- [ ] Stop order
- [ ] Interpolation data for rendering
- [ ] Attack-move behavior (basic)
- [ ] Unit tests for movement logic

---

## Notes

Start with simple point-to-point movement following paths. More complex
behaviors (formation movement, local avoidance) can be added in later
iterations.

The movement system is one of the most visible runtime behaviors, so
getting it right early pays dividends. But don't over-engineer - WC3's
movement isn't particularly sophisticated by modern standards.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:16*

Looking at this issue, I'll analyze whether splitting would be beneficial.

## Analysis

This issue covers a lot of ground - movement orders, path following, speed modifiers, interpolation, and multiple behavior types (attack-move, patrol, follow). The acceptance criteria has 10 items spanning different concerns.

**Recommendation: Split into 4 sub-issues**

The issue naturally divides along these boundaries:

---

## Suggested Sub-Issues

### 404a-core-movement-system
**Description:** Core movement system infrastructure - the movement component definition, system registration, and basic position updates each tick.

**Covers:**
- Movement component with speed, target, path, path_index, pathing_type, turn_rate
- Interpolation fields (last_x, last_y)
- System registration with position+movement query
- Basic update loop storing last position

**Dependencies:** 401 (game tick), 402 (ECS)

---

### 404b-path-following-logic
**Description:** Waypoint progression and movement math - the actual logic that moves units along paths toward destinations.

**Covers:**
- `update_movement()` function with waypoint progression
- Distance calculations and move distance per tick
- Turn rate and facing updates with `approach_angle()`
- Path completion detection and events
- Waypoint advancement logic

**Dependencies:** 404a, 403 (pathfinding)

---

### 404c-movement-orders
**Description:** Order interface - functions to issue movement commands and integrate with pathfinding.

**Covers:**
- `order_move(entity, target_x, target_y)` with pathfinding request
- `order_stop(entity)` to clear movement state
- Speed modifier API (`set_speed_modifier`, `recalculate_speed`)
- Integration with buff/debuff system for speed calculation

**Dependencies:** 404a, 404b

---

### 404d-advanced-movement-behaviors
**Description:** Complex movement patterns beyond simple move-to-point.

**Covers:**
- `order_attack_move()` - move but engage enemies
- `order_patrol()` - cycle through waypoints
- `order_follow()` - follow another entity
- Orders queue concept for shift-queuing (design/stub)

**Dependencies:** 404c

---

## Dependency Graph

```
401 (tick) ──┐
402 (ECS) ───┼──▶ 404a ──▶ 404b ──▶ 404c ──▶ 404d
403 (path) ──┘              │
                            └──────────┘
```

## Rationale

1. **404a** establishes the data model - can be tested with manual position updates
2. **404b** is pure math/logic - highly testable in isolation
3. **404c** is the public API most other systems will use
4. **404d** is optional enhancement - could be deferred to later phase

This split allows:
- Testing movement math without pathfinding
- Completing core movement before complex behaviors
- Clear interfaces between layers
