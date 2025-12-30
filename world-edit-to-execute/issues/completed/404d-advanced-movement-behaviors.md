# Issue 404d: Advanced Movement Behaviors

**Phase:** 4 - Runtime
**Type:** Feature (Optional Enhancement)
**Priority:** Low
**Parent:** 404-create-unit-movement-system.md
**Dependencies:** 404b-path-following-logic, 404c-movement-orders

---

## Current Behavior

Units follow paths and execute move orders, but lack advanced behaviors that make movement feel polished:
- No collision avoidance between units
- No formation movement
- No sliding along obstacles
- No movement prediction for smooth multiplayer

---

## Intended Behavior

Advanced movement behaviors that:
- Implement local avoidance (units don't overlap)
- Support formation movement for groups
- Add obstacle sliding for smoother pathing
- Provide movement prediction for interpolation

**Note:** This issue is marked as optional/low priority. The core movement system (404a-c) is fully functional without these enhancements. These are polish features for a more authentic WC3 experience.

---

## Suggested Implementation Steps

### 1. Local Avoidance (Collision Avoidance)

```lua
-- src/runtime/systems/avoidance.lua
local avoidance = {}

-- {{{ avoidance.RADIUS
-- Default collision radius for units
avoidance.DEFAULT_RADIUS = 32
-- }}}

-- {{{ avoidance.calculate_steering
-- Calculates steering force to avoid nearby units.
-- Uses simple separation behavior.
function avoidance.calculate_steering(entity, nearby_entities)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return 0, 0
    end

    local steer_x, steer_y = 0, 0
    local radius = mov.collision_radius or avoidance.DEFAULT_RADIUS

    for _, other in ipairs(nearby_entities) do
        if other ~= entity then
            local other_pos = ecs.get_component(other, "position")
            local other_mov = ecs.get_component(other, "movement")

            if other_pos then
                local dx = pos.x - other_pos.x
                local dy = pos.y - other_pos.y
                local dist = math.sqrt(dx * dx + dy * dy)

                local other_radius = other_mov and other_mov.collision_radius or avoidance.DEFAULT_RADIUS
                local min_dist = radius + other_radius

                if dist < min_dist and dist > 0 then
                    -- Separation force (stronger when closer)
                    local strength = (min_dist - dist) / min_dist
                    steer_x = steer_x + (dx / dist) * strength
                    steer_y = steer_y + (dy / dist) * strength
                end
            end
        end
    end

    return steer_x, steer_y
end
-- }}}

-- {{{ avoidance.apply_steering
-- Applies steering force to entity's movement.
function avoidance.apply_steering(entity, steer_x, steer_y, dt)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then return end

    -- Limit steering strength
    local max_steer = mov.speed * 0.5 * dt
    local mag = math.sqrt(steer_x * steer_x + steer_y * steer_y)

    if mag > max_steer then
        steer_x = (steer_x / mag) * max_steer
        steer_y = (steer_y / mag) * max_steer
    end

    pos.x = pos.x + steer_x
    pos.y = pos.y + steer_y
end
-- }}}
```

### 2. Formation Movement

```lua
-- src/runtime/systems/formation.lua
local formation = {}

-- {{{ Formation types
formation.TYPE = {
    LINE = "line",
    BOX = "box",
    WEDGE = "wedge",
    COLUMN = "column",
}
-- }}}

-- {{{ formation.calculate_positions
-- Calculates formation positions for a group of entities.
function formation.calculate_positions(entities, target, formation_type)
    formation_type = formation_type or formation.TYPE.LINE
    local positions = {}
    local count = #entities

    if count == 0 then
        return positions
    end

    local spacing = 64  -- Units apart

    if formation_type == formation.TYPE.LINE then
        -- Horizontal line centered on target
        local half_width = (count - 1) * spacing / 2
        for i, entity in ipairs(entities) do
            positions[entity] = {
                x = target.x + (i - 1) * spacing - half_width,
                y = target.y,
            }
        end

    elseif formation_type == formation.TYPE.BOX then
        -- Square formation
        local cols = math.ceil(math.sqrt(count))
        local rows = math.ceil(count / cols)
        local idx = 1
        for row = 1, rows do
            for col = 1, cols do
                if idx <= count then
                    positions[entities[idx]] = {
                        x = target.x + (col - 1) * spacing - (cols - 1) * spacing / 2,
                        y = target.y + (row - 1) * spacing - (rows - 1) * spacing / 2,
                    }
                    idx = idx + 1
                end
            end
        end

    elseif formation_type == formation.TYPE.WEDGE then
        -- V-shaped wedge
        local leader_pos = target
        positions[entities[1]] = { x = leader_pos.x, y = leader_pos.y }

        local row = 1
        local idx = 2
        while idx <= count do
            for side = -1, 1, 2 do  -- Left and right
                if idx <= count then
                    positions[entities[idx]] = {
                        x = leader_pos.x + side * row * spacing * 0.7,
                        y = leader_pos.y - row * spacing,
                    }
                    idx = idx + 1
                end
            end
            row = row + 1
        end

    elseif formation_type == formation.TYPE.COLUMN then
        -- Single file column
        for i, entity in ipairs(entities) do
            positions[entity] = {
                x = target.x,
                y = target.y - (i - 1) * spacing,
            }
        end
    end

    return positions
end
-- }}}

-- {{{ formation.move_group
-- Issues move orders to a group in formation.
function formation.move_group(entities, target, formation_type)
    local positions = formation.calculate_positions(entities, target, formation_type)

    for entity, pos in pairs(positions) do
        orders.move(entity, pos)
    end
end
-- }}}
```

### 3. Obstacle Sliding

```lua
-- src/runtime/systems/sliding.lua
local sliding = {}

-- {{{ sliding.calculate_slide
-- When unit hits obstacle, calculates slide direction.
function sliding.calculate_slide(entity, blocked_x, blocked_y, desired_dx, desired_dy)
    -- Try sliding along the obstacle
    local slide_options = {
        { dx = desired_dx, dy = 0 },  -- Horizontal slide
        { dx = 0, dy = desired_dy },  -- Vertical slide
    }

    local mov = ecs.get_component(entity, "movement")
    local pathing_type = mov and mov.pathing_type or "foot"

    for _, option in ipairs(slide_options) do
        local new_x = blocked_x + option.dx
        local new_y = blocked_y + option.dy

        if pathfinding.is_passable(new_x, new_y, pathing_type) then
            -- Normalize the slide vector
            local mag = math.sqrt(option.dx * option.dx + option.dy * option.dy)
            if mag > 0 then
                return option.dx / mag, option.dy / mag
            end
        end
    end

    return 0, 0  -- No valid slide direction
end
-- }}}
```

### 4. Movement Prediction

```lua
-- src/runtime/systems/prediction.lua
local prediction = {}

-- {{{ prediction.predict_position
-- Predicts entity position at future time.
function prediction.predict_position(entity, time_ahead)
    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if not pos or not mov then
        return nil
    end

    if not movement.is_moving(entity) then
        return { x = pos.x, y = pos.y }
    end

    -- Simple linear prediction along current path
    local speed = movement.get_effective_speed(entity)
    local distance = speed * time_ahead

    local current_x, current_y = pos.x, pos.y
    local remaining = distance

    for i = mov.path_index, #mov.path do
        local waypoint = mov.path[i]
        local dx = waypoint.x - current_x
        local dy = waypoint.y - current_y
        local wp_dist = math.sqrt(dx * dx + dy * dy)

        if remaining <= wp_dist then
            -- Predicted position is along this segment
            local ratio = remaining / wp_dist
            return {
                x = current_x + dx * ratio,
                y = current_y + dy * ratio,
            }
        end

        remaining = remaining - wp_dist
        current_x, current_y = waypoint.x, waypoint.y
    end

    -- Reached end of path
    return { x = current_x, y = current_y }
end
-- }}}
```

### 5. Integration

Add collision radius to movement component defaults:
```lua
-- In 404a movement.lua
MOVEMENT_DEFAULTS.collision_radius = 32
```

Register avoidance system:
```lua
-- Runs after movement system
ecs.register_system("avoidance", {"position", "movement"}, function(entities, dt)
    for _, entity in ipairs(entities) do
        if movement.is_moving(entity) then
            local steer_x, steer_y = avoidance.calculate_steering(entity, entities)
            avoidance.apply_steering(entity, steer_x, steer_y, dt)
        end
    end
end)
```

### 6. Create unit tests
```
src/tests/test_avoidance.lua
src/tests/test_formation.lua
```

### 7. Test scenarios
- Two units don't overlap when moving to same point
- Formation positions calculated correctly for each type
- Group moves in formation
- Obstacle sliding allows smoother corner navigation
- Position prediction matches actual arrival

---

## Related Documents

- issues/404-create-unit-movement-system.md (parent issue)
- issues/404b-path-following-logic.md (provides base movement)
- issues/404c-movement-orders.md (formation uses orders)
- issues/403e-path-smoothing.md (related to smooth movement)

---

## Acceptance Criteria

- [x] Local avoidance prevents unit overlap
- [x] Formation types defined (line, box, wedge, column)
- [x] `formation.calculate_positions()` generates correct positions
- [x] `formation.move_group()` issues orders in formation
- [ ] Obstacle sliding enables smoother corner navigation (deferred - needs pathfinding integration)
- [x] `prediction.predict_position()` estimates future position
- [x] Avoidance system registered and runs after movement
- [x] Unit tests pass

---

## Notes

This issue is explicitly **optional and low priority**. The core movement system works without these features. These are "nice to have" polish features.

**Local Avoidance**: The simple separation-based approach works for small groups but doesn't scale to huge armies. For large-scale RTS, a more sophisticated approach like RVO (Reciprocal Velocity Obstacles) or flow fields would be needed.

**Formation Movement**: WC3 formations are actually quite simple - just position offsets from a center point. This implementation matches that simplicity. More complex formation behaviors (maintaining formation while moving, dynamic re-forming) would require additional work.

**Obstacle Sliding**: WC3's sliding behavior is subtle but noticeable - units "slide" along walls rather than getting stuck on corners. This is a simplified version that could be enhanced with proper wall-following.

**Movement Prediction**: Useful for multiplayer lag compensation and for AI systems that need to predict where units will be. The linear prediction along paths is accurate for constant-speed movement.

Each subsystem in this issue could be its own sub-issue if more detailed implementation is needed. They're grouped here because they're all optional enhancements to the core movement system.

---

## Implementation Notes

### Files Created
- `src/runtime/systems/avoidance.lua` - Local avoidance using separation-based steering
- `src/runtime/systems/formation.lua` - Formation movement (line, box, wedge, column)
- `src/runtime/systems/prediction.lua` - Movement prediction and intercept calculations
- `src/tests/test_advanced_movement.lua` - 56 unit tests for all systems

### Files Modified
- `src/runtime/systems/movement.lua` - Added `collision_radius` field to MOVEMENT_DEFAULTS (32 units)

### Design Decisions

1. **Avoidance System Priority**: Set to priority 12, running after movement (10) but before orders (15). This allows movement to happen first, then corrections are applied.

2. **Separation-Based Avoidance**: Chose simple separation behavior over RVO. Adequate for small groups, scales to ~50 units. For massive armies, would need flow fields or RVO.

3. **Avoidance Only While Moving**: Steering only applied to moving entities. Stationary entities don't push each other - this matches WC3 behavior where stopped units can overlap.

4. **Formation Positions as Arrays**: `calculate_positions()` returns positions indexed by entity order, not by entity ID. This keeps the API simple and allows reuse of position arrays.

5. **Lazy Orders Integration**: Formation's `move_group()` uses pcall to optionally load orders module. Works with or without orders system.

6. **Prediction Uses Effective Speed**: Considers speed modifiers when predicting future positions. `get_intercept_point()` uses binary search for accuracy.

7. **Obstacle Sliding Deferred**: Requires deeper integration with pathfinding to detect blocked movement. Will implement if/when needed.

### Test Coverage
- Avoidance: 19 tests (constants, steering calculation, magnitude limits, system integration)
- Formation: 21 tests (all 4 formation types, edge cases, move_group integration)
- Prediction: 16 tests (single/multi-waypoint prediction, time estimation, invalid entities)
- Total: 56 tests, all passing

### Performance Considerations
- Avoidance collects all entities into array before processing (single iterator pass)
- No spatial partitioning - O(n²) neighbor checks acceptable for <100 units
- For larger scales, would integrate with spatial hash from 405b

