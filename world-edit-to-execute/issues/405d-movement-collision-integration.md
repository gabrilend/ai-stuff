# Issue 405d: Movement Collision Integration

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 405-implement-basic-collision-detection.md
**Dependencies:** 405c-collision-queries, 404-create-unit-movement-system

---

## Current Behavior

After 405c, collision queries exist. The movement system from 404 can move units but does not check for collisions. Units can overlap freely and pass through each other.

---

## Intended Behavior

Integrate collision detection with the movement system:
- Check if a proposed move would cause collision with solid entities
- Prevent movement into occupied space
- Resolve overlaps when they occur (push apart)
- Allow non-solid entities to overlap freely

**API:**
```lua
-- Check if moving entity to new position would collide
collision.can_move_to(entity, new_x, new_y) -> boolean, blocking_entity

-- Resolve overlap between two entities
collision.resolve_overlap(entity1, entity2)

-- Slide along obstacle when blocked
collision.slide_move(entity, desired_x, desired_y) -> actual_x, actual_y
```

---

## Suggested Implementation Steps

1. **Implement can_move_to check**
   ```lua
   -- {{{ can_move_to
   -- Check if entity can move to a new position without collision
   -- Returns: boolean success, entity that blocked (or nil)
   function collision.can_move_to(entity, new_x, new_y)
       local col = ecs.get_component(entity, "collision")

       -- Non-solid entities can always move
       if not col or not col.solid then
           return true, nil
       end

       -- Query for nearby solid entities
       local radius = col.radius
       if col.shape == "rect" then
           radius = math.sqrt(col.width * col.width + col.height * col.height) / 2
       end

       -- Check potential collisions at new position
       local candidates = spatial.get_nearby(new_x, new_y, radius * 2)

       for _, other in ipairs(candidates) do
           if other ~= entity then
               local other_pos = ecs.get_component(other, "position")
               local other_col = ecs.get_component(other, "collision")

               if other_pos and other_col and other_col.solid then
                   -- Check if entity's mask includes other's layer
                   if collision.layer_matches_mask(other_col.layer, col.mask) then
                       -- Create temporary position for collision test
                       local temp_pos = {x = new_x, y = new_y}

                       if collision.shapes_collide(temp_pos, col, other_pos, other_col) then
                           return false, other
                       end
                   end
               end
           end
       end

       return true, nil
   end
   -- }}}
   ```

2. **Implement overlap resolution**
   ```lua
   -- {{{ resolve_overlap
   -- Push two overlapping entities apart
   -- Uses minimum separation vector approach
   function collision.resolve_overlap(entity1, entity2)
       local pos1 = ecs.get_component(entity1, "position")
       local pos2 = ecs.get_component(entity2, "position")
       local col1 = ecs.get_component(entity1, "collision")
       local col2 = ecs.get_component(entity2, "collision")

       if not (pos1 and pos2 and col1 and col2) then
           return
       end

       -- Calculate separation vector (pointing from entity2 to entity1)
       local dx = pos1.x - pos2.x
       local dy = pos1.y - pos2.y
       local dist = math.sqrt(dx * dx + dy * dy)

       -- Avoid division by zero
       if dist < 0.001 then
           dx, dy = 1, 0
           dist = 1
       end

       -- Calculate overlap amount (for circles)
       local overlap = 0
       if col1.shape == "circle" and col2.shape == "circle" then
           overlap = (col1.radius + col2.radius) - dist
       else
           -- For mixed shapes, use approximate radius
           local r1 = col1.radius or math.max(col1.width, col1.height) / 2
           local r2 = col2.radius or math.max(col2.width, col2.height) / 2
           overlap = (r1 + r2) - dist
       end

       if overlap <= 0 then
           return  -- No overlap
       end

       -- Normalize direction
       local nx = dx / dist
       local ny = dy / dist

       -- Push apart (split evenly, or weighted by mass if available)
       local push = overlap / 2 + 0.1  -- Small extra push to prevent re-collision

       pos1.x = pos1.x + nx * push
       pos1.y = pos1.y + ny * push
       pos2.x = pos2.x - nx * push
       pos2.y = pos2.y - ny * push
   end
   -- }}}
   ```

3. **Implement slide movement**
   ```lua
   -- {{{ slide_move
   -- Attempt to move entity, sliding along obstacles if blocked
   -- Returns the actual position achieved
   function collision.slide_move(entity, desired_x, desired_y)
       local pos = ecs.get_component(entity, "position")
       if not pos then
           return desired_x, desired_y
       end

       -- Try direct move first
       local can_move, blocker = collision.can_move_to(entity, desired_x, desired_y)
       if can_move then
           return desired_x, desired_y
       end

       -- Try sliding along X axis only
       local can_x = collision.can_move_to(entity, desired_x, pos.y)
       if can_x then
           return desired_x, pos.y
       end

       -- Try sliding along Y axis only
       local can_y = collision.can_move_to(entity, pos.x, desired_y)
       if can_y then
           return pos.x, desired_y
       end

       -- Completely blocked - stay in place
       return pos.x, pos.y
   end
   -- }}}
   ```

4. **Integrate with movement system**
   ```lua
   -- In src/runtime/movement/init.lua or system file
   -- Modify movement system to use collision checks

   function movement_system.update(dt)
       for entity in ecs.query({"position", "velocity", "collision"}) do
           local pos = ecs.get_component(entity, "position")
           local vel = ecs.get_component(entity, "velocity")

           -- Calculate desired position
           local desired_x = pos.x + vel.x * dt
           local desired_y = pos.y + vel.y * dt

           -- Use slide movement to respect collisions
           local actual_x, actual_y = collision.slide_move(entity, desired_x, desired_y)

           -- Update position
           pos.x = actual_x
           pos.y = actual_y

           -- Optionally zero velocity if blocked
           if actual_x ~= desired_x then vel.x = 0 end
           if actual_y ~= desired_y then vel.y = 0 end
       end
   end
   ```

5. **Implement collision response system**
   ```lua
   -- {{{ resolve_all_overlaps
   -- Find and resolve all current overlaps
   -- Call after movement update to fix any penetrations
   function collision.resolve_all_overlaps()
       -- Get all entities with collision
       local entities = {}
       for entity in ecs.query_single("collision") do
           entities[#entities + 1] = entity
       end

       -- Check all pairs (could optimize with spatial hash)
       for i = 1, #entities do
           for j = i + 1, #entities do
               local e1, e2 = entities[i], entities[j]
               local col1 = ecs.get_component(e1, "collision")
               local col2 = ecs.get_component(e2, "collision")

               -- Only resolve solid-solid overlaps
               if col1.solid and col2.solid then
                   if collision.layer_matches_mask(col2.layer, col1.mask) then
                       local pos1 = ecs.get_component(e1, "position")
                       local pos2 = ecs.get_component(e2, "position")

                       if collision.shapes_collide(pos1, col1, pos2, col2) then
                           collision.resolve_overlap(e1, e2)
                       end
                   end
               end
           end
       end
   end
   -- }}}
   ```

6. **Add collision events**
   ```lua
   -- {{{ Fire collision events for trigger zones
   function collision.check_trigger_collisions()
       for trigger_entity in ecs.query({"collision", "position"}) do
           local col = ecs.get_component(trigger_entity, "collision")

           if col.trigger then
               local pos = ecs.get_component(trigger_entity, "position")
               local inside = collision.query_colliding(trigger_entity, {"unit"})

               -- Track enter/leave events
               local prev_inside = col._inside or {}
               col._inside = {}

               for _, entity in ipairs(inside) do
                   col._inside[entity] = true
                   if not prev_inside[entity] then
                       -- Entity just entered
                       fire_event("trigger_enter", trigger_entity, entity)
                   end
               end

               for entity in pairs(prev_inside) do
                   if not col._inside[entity] then
                       -- Entity just left
                       fire_event("trigger_leave", trigger_entity, entity)
                   end
               end
           end
       end
   end
   -- }}}
   ```

7. **Create unit tests**
   ```lua
   -- src/tests/test_movement_collision.lua
   -- Test can_move_to blocks movement into occupied space
   -- Test can_move_to allows movement for non-solid entities
   -- Test resolve_overlap pushes entities apart correctly
   -- Test slide_move slides along obstacles
   -- Test layer mask filtering in collision checks
   -- Test trigger enter/leave events
   ```

---

## Related Documents

- issues/405-implement-basic-collision-detection.md (parent issue)
- issues/405c-collision-queries.md (prerequisite - query API)
- issues/404-create-unit-movement-system.md (integration target)
- issues/405e-projectile-and-picking.md (sibling - different collision use)

---

## Acceptance Criteria

- [ ] `can_move_to()` correctly detects blocked movement
- [ ] `can_move_to()` returns blocking entity reference
- [ ] `resolve_overlap()` pushes overlapping entities apart
- [ ] `slide_move()` slides along obstacles when direct path blocked
- [ ] Movement system uses collision checks before moving
- [ ] Non-solid entities can overlap freely
- [ ] Layer/mask filtering respected in movement checks
- [ ] Trigger zones fire enter/leave events
- [ ] `resolve_all_overlaps()` fixes all penetrations
- [ ] Unit tests pass for all movement collision cases

---

## Notes

**Movement-first design:**
- Check collision BEFORE moving, not after
- This prevents entities from ever overlapping
- `resolve_overlap` is for edge cases (spawning, teleporting)

**Slide movement:**
- When blocked, try to preserve some movement
- Try X-only, then Y-only, then give up
- Creates natural "sliding along walls" behavior

**Trigger zones:**
- Use `solid = false, trigger = true`
- Don't block movement, just detect presence
- Fire events when units enter/leave
- Used for region triggers from w3r

**Performance considerations:**
- `can_move_to` called potentially every frame per entity
- Spatial hash makes broad phase fast
- For many entities, consider limiting narrow-phase checks

**Collision groups:**
- Allied units might want to overlap (soft collision)
- Could add `collision_group` to allow/disallow per-team
- For now, all solid entities block each other
