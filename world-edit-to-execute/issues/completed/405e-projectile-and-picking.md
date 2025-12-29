# Issue 405e: Projectile Hit Detection and Picking

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 405-implement-basic-collision-detection.md
**Dependencies:** 405c-collision-queries

---

## Current Behavior

After 405c, collision queries exist. However, there is no specialized handling for:
- Projectile collision with valid targets (hit detection)
- Mouse cursor selection (picking)
- Box selection for multiple units

---

## Intended Behavior

Implement projectile hit detection and picking/selection:

**Projectile API:**
```lua
-- Check if projectile hit any valid targets this frame
collision.check_projectile_hit(projectile) -> target_entity or nil

-- Register a hit to prevent re-hitting same target
collision.register_projectile_hit(projectile, target)

-- Check if target was already hit by this projectile
collision.was_hit_by(projectile, target) -> boolean
```

**Picking API:**
```lua
-- Find selectable entity at screen point
collision.pick_at_point(world_x, world_y) -> entity or nil

-- Find all selectable entities in box selection
collision.pick_in_rect(x1, y1, x2, y2) -> {entity, ...}

-- Check if entity is selectable
collision.is_selectable(entity) -> boolean
```

---

## Suggested Implementation Steps

1. **Implement projectile hit tracking**
   ```lua
   -- Track which targets each projectile has hit
   -- Prevents piercing projectiles from hitting same target twice
   local projectile_hits = {}  -- projectile -> {target = true, ...}

   -- {{{ register_projectile_hit
   function collision.register_projectile_hit(projectile, target)
       if not projectile_hits[projectile] then
           projectile_hits[projectile] = {}
       end
       projectile_hits[projectile][target] = true
   end
   -- }}}

   -- {{{ was_hit_by
   function collision.was_hit_by(projectile, target)
       local hits = projectile_hits[projectile]
       return hits and hits[target] or false
   end
   -- }}}

   -- {{{ clear_projectile_hits
   -- Call when projectile is destroyed
   function collision.clear_projectile_hits(projectile)
       projectile_hits[projectile] = nil
   end
   -- }}}
   ```

2. **Implement target validation**
   ```lua
   -- {{{ is_valid_target
   -- Check if target is valid for projectile
   -- Considers: team, already hit, alive, etc.
   function collision.is_valid_target(projectile, target)
       -- Skip already hit targets
       if collision.was_hit_by(projectile, target) then
           return false
       end

       local proj = ecs.get_component(projectile, "projectile")
       local target_unit = ecs.get_component(target, "unit")

       if not proj or not target_unit then
           return false
       end

       -- Skip dead units
       if target_unit.is_dead then
           return false
       end

       -- Check team targeting (if owner exists)
       local owner = proj.owner
       if owner then
           local owner_unit = ecs.get_component(owner, "unit")
           if owner_unit then
               -- Skip friendly units (unless projectile targets allies)
               if target_unit.team == owner_unit.team and not proj.targets_allies then
                   return false
               end
               -- Skip enemies if projectile only targets allies
               if target_unit.team ~= owner_unit.team and proj.targets_allies and not proj.targets_enemies then
                   return false
               end
           end
       end

       return true
   end
   -- }}}
   ```

3. **Implement projectile hit detection**
   ```lua
   -- {{{ check_projectile_hit
   -- Check if projectile collides with any valid target
   -- Returns first valid target hit, or nil
   function collision.check_projectile_hit(projectile)
       local pos = ecs.get_component(projectile, "position")
       local col = ecs.get_component(projectile, "collision")
       local proj = ecs.get_component(projectile, "projectile")

       if not (pos and col) then
           return nil
       end

       -- Query nearby units
       local radius = col.radius or 8  -- Default projectile radius
       local targets = collision.query_radius(pos.x, pos.y, radius, {"unit"})

       for _, target in ipairs(targets) do
           if collision.is_valid_target(projectile, target) then
               -- Register hit and return target
               collision.register_projectile_hit(projectile, target)

               -- Fire projectile hit event
               fire_event("projectile_hit", {
                   projectile = projectile,
                   target = target,
                   x = pos.x,
                   y = pos.y,
               })

               return target
           end
       end

       return nil
   end
   -- }}}
   ```

4. **Implement point picking**
   ```lua
   -- {{{ is_selectable
   -- Check if entity can be selected by the player
   function collision.is_selectable(entity)
       local col = ecs.get_component(entity, "collision")
       local unit = ecs.get_component(entity, "unit")

       -- Must have collision shape
       if not col then
           return false
       end

       -- Only units and buildings are selectable
       if col.layer ~= "unit" and col.layer ~= "building" then
           return false
       end

       -- Check visibility (fog of war) if applicable
       -- local visible = check_visibility(entity)
       -- if not visible then return false end

       return true
   end
   -- }}}

   -- {{{ pick_at_point
   -- Find selectable entity at world coordinates
   -- Used for single-click selection
   function collision.pick_at_point(world_x, world_y)
       -- Query all pickable layers
       local entity = collision.query_point(world_x, world_y, {"unit", "building"})

       if entity and collision.is_selectable(entity) then
           return entity
       end

       return nil
   end
   -- }}}
   ```

5. **Implement box selection**
   ```lua
   -- {{{ pick_in_rect
   -- Find all selectable entities in a rectangle
   -- Used for box/drag selection
   function collision.pick_in_rect(x1, y1, x2, y2)
       -- Normalize rectangle (ensure x1 < x2, y1 < y2)
       if x1 > x2 then x1, x2 = x2, x1 end
       if y1 > y2 then y1, y2 = y2, y1 end

       local width = x2 - x1
       local height = y2 - y1
       local center_x = (x1 + x2) / 2
       local center_y = (y1 + y2) / 2

       -- Query rectangle
       local candidates = collision.query_rect(center_x, center_y, width, height, {"unit", "building"})

       -- Filter to selectable only
       local results = {}
       for _, entity in ipairs(candidates) do
           if collision.is_selectable(entity) then
               results[#results + 1] = entity
           end
       end

       -- Optionally limit selection count (WC3 has 12 unit limit)
       local MAX_SELECTION = 12
       if #results > MAX_SELECTION then
           -- Sort by some priority (e.g., distance from center) and truncate
           local cx, cy = center_x, center_y
           table.sort(results, function(a, b)
               local pos_a = ecs.get_component(a, "position")
               local pos_b = ecs.get_component(b, "position")
               local da = (pos_a.x - cx)^2 + (pos_a.y - cy)^2
               local db = (pos_b.x - cx)^2 + (pos_b.y - cy)^2
               return da < db
           end)

           local truncated = {}
           for i = 1, MAX_SELECTION do
               truncated[i] = results[i]
           end
           results = truncated
       end

       return results
   end
   -- }}}
   ```

6. **Implement screen-to-world coordinate conversion helper**
   ```lua
   -- {{{ screen_to_world
   -- Convert screen coordinates to world coordinates
   -- (Placeholder - actual implementation depends on camera system)
   function collision.screen_to_world(screen_x, screen_y, camera)
       -- Simple orthographic projection
       local world_x = screen_x + camera.x - camera.width / 2
       local world_y = screen_y + camera.y - camera.height / 2
       return world_x, world_y
   end
   -- }}}

   -- {{{ pick_at_screen
   -- Convenience function for picking at screen coordinates
   function collision.pick_at_screen(screen_x, screen_y, camera)
       local world_x, world_y = collision.screen_to_world(screen_x, screen_y, camera)
       return collision.pick_at_point(world_x, world_y)
   end
   -- }}}
   ```

7. **Projectile system integration**
   ```lua
   -- In projectile update system
   function projectile_system.update(dt)
       for projectile in ecs.query({"projectile", "position", "velocity"}) do
           local proj = ecs.get_component(projectile, "projectile")
           local pos = ecs.get_component(projectile, "position")
           local vel = ecs.get_component(projectile, "velocity")

           -- Move projectile
           pos.x = pos.x + vel.x * dt
           pos.y = pos.y + vel.y * dt

           -- Check for hit
           local hit = collision.check_projectile_hit(projectile)

           if hit then
               if proj.piercing then
                   -- Continue flying, already registered hit
               else
                   -- Destroy on hit
                   ecs.destroy(projectile)
                   collision.clear_projectile_hits(projectile)
               end
           end

           -- Check for max range
           local traveled = math.sqrt(
               (pos.x - proj.start_x)^2 + (pos.y - proj.start_y)^2
           )
           if traveled >= proj.max_range then
               ecs.destroy(projectile)
               collision.clear_projectile_hits(projectile)
           end
       end
   end
   ```

8. **Create unit tests**
   ```lua
   -- src/tests/test_projectile_picking.lua

   -- Projectile tests:
   -- Test hit detection finds targets in range
   -- Test was_hit_by prevents double hits
   -- Test is_valid_target respects team
   -- Test is_valid_target skips dead units
   -- Test piercing projectiles can hit multiple

   -- Picking tests:
   -- Test pick_at_point finds entity
   -- Test pick_at_point returns nil for empty space
   -- Test pick_in_rect finds multiple entities
   -- Test pick_in_rect respects MAX_SELECTION limit
   -- Test is_selectable filters correctly
   ```

---

## Related Documents

- issues/405-implement-basic-collision-detection.md (parent issue)
- issues/405c-collision-queries.md (prerequisite - query API)
- issues/405d-movement-collision-integration.md (sibling)
- issues/406-implement-projectile-system.md (future - full projectile system)

---

## Acceptance Criteria

- [x] `check_projectile_hit()` finds valid targets
- [x] `register_projectile_hit()` tracks hits per projectile
- [x] `was_hit_by()` prevents double hits
- [x] `is_valid_target()` respects team filtering
- [x] `is_valid_target()` skips dead units
- [x] `clear_projectile_hits()` cleans up on projectile destroy
- [x] `pick_at_point()` finds entity at world coordinates
- [x] `pick_in_rect()` finds entities in box selection
- [x] `is_selectable()` filters pickable entities
- [x] Box selection respects MAX_SELECTION limit
- [ ] Projectile hit events are fired (deferred to event system integration)
- [x] Unit tests pass for all cases

---

## Notes

**Projectile types:**
- Single-target: Hit one target, destroy
- Piercing: Hit multiple targets, continue flying
- AoE: Hit all in radius on impact (handled by damage system)

**Hit tracking:**
- Per-projectile tracking prevents piercing from hitting same unit twice
- Cleared when projectile is destroyed
- Memory leak if projectiles not cleaned up properly

**Selection limits:**
- WC3 has 12-unit selection limit
- Box selection sorts by distance to center
- Closest units to selection center are preferred

**Picking priority:**
- Units selected over buildings
- Could add hero priority later
- Could add "last selected" priority for toggle-selection

**Coordinate conversion:**
- Screen-to-world depends on camera implementation
- Placeholder uses simple orthographic math
- Real implementation needs camera transform matrix

**Future enhancements:**
- Homing projectiles (target tracking)
- Ground-targeted AoE (no direct collision)
- Double-click to select all of same type
- Shift-click to add to selection

---

## Implementation Notes

*Completed 2025-12-29*

### Files Modified

- `src/runtime/collision/init.lua` - Added ~300 lines of projectile/picking functions

### Files Created

- `src/tests/test_projectile_picking.lua` (~330 lines) - Comprehensive test suite

### API Implemented

**Projectile Hit Detection:**
- `collision.register_projectile_hit(projectile, target)` - Track hit
- `collision.was_hit_by(projectile, target)` - Check if already hit
- `collision.clear_projectile_hits(projectile)` - Clear on destroy
- `collision.get_projectile_hit_count(projectile)` - Get hit count
- `collision.is_valid_target(projectile, target, options)` - Validate target
- `collision.check_projectile_hit(projectile, options)` - Find first valid hit
- `collision.check_projectile_hits_all(projectile, options)` - Find all hits (AoE/piercing)

**Entity Picking:**
- `collision.is_selectable(entity)` - Check if entity can be selected
- `collision.pick_at_point(world_x, world_y)` - Single-click selection
- `collision.pick_in_rect(x1, y1, x2, y2, max_count)` - Box selection
- `collision.pick_all_at_point(world_x, world_y)` - All entities at point

### Test Coverage

45 tests covering:
- Projectile hit tracking (7 tests)
- is_valid_target (4 tests)
- Team filtering (5 tests)
- check_projectile_hit (4 tests)
- check_projectile_hits_all (3 tests)
- is_selectable (7 tests)
- pick_at_point (4 tests)
- pick_in_rect (4 tests)
- pick_all_at_point (2 tests)
- Edge cases (5 tests)

### Total Collision System Tests

- 405a (shapes): 99 tests
- 405b (spatial): 61 tests
- 405c (queries): 50 tests
- 405e (projectile/picking): 45 tests
- **Total: 255 tests**
