# Issue 405: Implement Basic Collision Detection

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Dependencies:** 401, 402, 404

---

## Current Behavior

No collision detection exists. Units can overlap freely, projectiles cannot
hit targets, and selection/picking has no spatial awareness.

---

## Intended Behavior

A collision detection system that:
- Detects unit-to-unit collisions for movement blocking
- Detects projectile-to-unit collisions for combat
- Provides spatial queries for area effects
- Supports picking (mouse cursor selection)
- Uses efficient spatial partitioning

---

## Suggested Implementation Steps

1. **Create collision module**
   ```
   src/runtime/
   └── collision/
       ├── init.lua       (main API)
       ├── shapes.lua     (collision primitives)
       └── spatial.lua    (spatial partitioning)
   ```

2. **Define collision component**
   ```lua
   ecs.register_component("collision", {
       shape = "circle",      -- circle, rect, point
       radius = 32,           -- for circles
       width = 0, height = 0, -- for rects

       layer = "unit",        -- unit, projectile, building, trigger
       mask = {"unit"},       -- what layers to collide with

       solid = true,          -- blocks movement
       trigger = false,       -- fires events but doesn't block
   })
   ```

3. **Implement spatial hash grid**
   ```lua
   -- Spatial hash for efficient broad-phase collision
   local CELL_SIZE = 256  -- world units per cell

   local spatial_hash = {}

   function collision.update_spatial_hash()
       spatial_hash = {}

       for entity in ecs.query_single("collision") do
           local pos = ecs.get_component(entity, "position")
           local col = ecs.get_component(entity, "collision")

           local cell_x = math.floor(pos.x / CELL_SIZE)
           local cell_y = math.floor(pos.y / CELL_SIZE)

           -- Insert into cell (and adjacent cells if near boundary)
           insert_into_cell(cell_x, cell_y, entity)
       end
   end
   ```

4. **Implement collision queries**
   ```lua
   -- Find all entities within radius of a point
   function collision.query_radius(x, y, radius, layer_mask)
       local results = {}
       local cell_radius = math.ceil(radius / CELL_SIZE)

       local center_cell_x = math.floor(x / CELL_SIZE)
       local center_cell_y = math.floor(y / CELL_SIZE)

       -- Check relevant cells
       for cx = center_cell_x - cell_radius, center_cell_x + cell_radius do
           for cy = center_cell_y - cell_radius, center_cell_y + cell_radius do
               local cell = get_cell(cx, cy)
               for _, entity in ipairs(cell) do
                   if check_collision_circle(entity, x, y, radius, layer_mask) then
                       results[#results + 1] = entity
                   end
               end
           end
       end

       return results
   end

   -- Find all entities within a rectangle
   function collision.query_rect(x, y, width, height, layer_mask)
   end

   -- Find entity at a point (for picking)
   function collision.query_point(x, y, layer_mask)
   end
   ```

5. **Circle-circle collision**
   ```lua
   function collision.circles_collide(x1, y1, r1, x2, y2, r2)
       local dx = x2 - x1
       local dy = y2 - y1
       local dist_sq = dx*dx + dy*dy
       local radii = r1 + r2
       return dist_sq <= radii * radii
   end
   ```

6. **Movement collision resolution**
   ```lua
   -- Called by movement system to check if move is valid
   function collision.can_move_to(entity, new_x, new_y)
       local col = ecs.get_component(entity, "collision")
       if not col.solid then return true end

       -- Check against other solid entities
       local nearby = collision.query_radius(new_x, new_y, col.radius * 2, col.mask)

       for _, other in ipairs(nearby) do
           if other ~= entity then
               local other_col = ecs.get_component(other, "collision")
               local other_pos = ecs.get_component(other, "position")

               if other_col.solid then
                   if collision.circles_collide(
                       new_x, new_y, col.radius,
                       other_pos.x, other_pos.y, other_col.radius
                   ) then
                       return false, other
                   end
               end
           end
       end

       return true
   end

   -- Resolve collision by pushing apart
   function collision.resolve_overlap(entity1, entity2)
       -- Calculate separation vector and push entities apart
   end
   ```

7. **Projectile collision**
   ```lua
   -- Called each tick for active projectiles
   function collision.check_projectile_hits(projectile)
       local pos = ecs.get_component(projectile, "position")
       local col = ecs.get_component(projectile, "collision")
       local proj = ecs.get_component(projectile, "projectile")

       local hits = collision.query_radius(pos.x, pos.y, col.radius, {"unit"})

       for _, target in ipairs(hits) do
           -- Check if target is valid (enemy, not already hit, etc.)
           if is_valid_target(projectile, target) then
               fire_event("projectile_hit", projectile, target)
               return target
           end
       end

       return nil
   end
   ```

8. **Selection/picking**
   ```lua
   function collision.pick_at_point(x, y)
       local entities = collision.query_point(x, y, {"unit", "building"})

       -- Sort by selection priority (units over buildings, etc.)
       -- Return topmost entity
   end

   function collision.pick_in_rect(x1, y1, x2, y2)
       -- Box selection
   end
   ```

---

## Technical Notes

### Collision Layers

Layers allow efficient filtering:
- Units collide with units and buildings
- Projectiles collide with units only
- Triggers collide with units (enter/leave events)

### Spatial Hash vs Quadtree

Spatial hash is simpler and works well for uniformly distributed entities.
Quadtrees are better for clustered entities but add complexity. Start with
spatial hash.

### Collision Radii

WC3 units have collision sizes (pathing map radius):
- Small units: 16-32
- Medium units: 32-48
- Large units: 48-72
- Heroes: often larger

### Dynamic Updates

The spatial hash must be updated when entities move. Options:
1. Rebuild entire hash each frame (simple, fast enough for small entity counts)
2. Update only moved entities (more complex, better for many entities)

Start with full rebuild - optimize if needed.

### Trigger Regions

Trigger regions (from w3r) can be implemented as collision entities with
`trigger = true`. Fire enter/leave events when units cross boundaries.

---

## Related Documents

- issues/402-build-entity-component-system.md (collision component)
- issues/404-create-unit-movement-system.md (uses collision checks)
- issues/203-parse-war3map-w3r.md (trigger regions)

---

## Acceptance Criteria

- [ ] Collision component with shape, layer, mask
- [ ] Spatial hash for broad-phase detection
- [ ] Circle-circle collision detection
- [ ] Query by radius (area effects)
- [ ] Query by rectangle (box selection)
- [ ] Query by point (picking)
- [ ] Movement blocking (solid entities)
- [ ] Projectile hit detection
- [ ] Layer/mask filtering
- [ ] Unit tests for collision detection

---

## Notes

Collision detection needs to be fast - it runs every tick and potentially
checks many entity pairs. The spatial hash provides O(1) average case
lookups for nearby entities.

Don't worry about perfect physical simulation. WC3's collision is simple:
units push each other apart, projectiles hit or miss. Keep it simple.

Consider adding debug visualization to draw collision shapes - invaluable
for debugging.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:17*

I'll analyze this issue to determine if splitting would be beneficial.

This is a substantial issue covering collision detection with multiple distinct subsystems. Let me evaluate the components:

## Analysis

The issue covers several distinct areas that could be developed and tested independently:

1. **Core collision primitives** (shapes, basic math) - Foundation layer
2. **Spatial partitioning** (hash grid) - Performance layer
3. **Query API** (radius, rect, point) - Interface layer
4. **Movement integration** (blocking, resolution) - Game system integration
5. **Projectile system** (hit detection) - Combat integration
6. **Selection/picking** (mouse interaction) - UI integration

## Recommendation: Split into 5 sub-issues

The issue has clear architectural layers with distinct concerns. Splitting would allow:
- Testing collision math independently of spatial optimization
- Validating the query API before integrating with game systems
- Parallel work on movement vs projectile collision

---

## Suggested Sub-Issues

### 405a-collision-primitives-and-shapes

**Description:** Implement the core collision component, shape definitions, and basic collision math (circle-circle, circle-rect, point-in-shape).

**Covers:**
- Collision component registration with ECS
- Shape definitions (circle, rect, point)
- `collision.circles_collide()` function
- Layer and mask system design
- Basic collision test functions

**Dependencies:** 402 (ECS must exist for component registration)

---

### 405b-spatial-hash-grid

**Description:** Implement spatial hash grid for efficient broad-phase collision detection with insert, remove, and cell query operations.

**Covers:**
- Spatial hash data structure
- `CELL_SIZE` tuning
- `insert_into_cell()` function
- `get_cell()` function
- `update_spatial_hash()` for full rebuild
- Handling entities near cell boundaries

**Dependencies:** 405a (needs collision component to know entity bounds)

---

### 405c-collision-queries

**Description:** Implement the query API for radius, rectangle, and point-based spatial queries with layer filtering.

**Covers:**
- `collision.query_radius(x, y, radius, layer_mask)`
- `collision.query_rect(x, y, width, height, layer_mask)`
- `collision.query_point(x, y, layer_mask)`
- Layer mask filtering logic
- Result sorting/prioritization

**Dependencies:** 405a, 405b (needs primitives and spatial hash)

---

### 405d-movement-collision-integration

**Description:** Integrate collision detection with the movement system for blocking and overlap resolution.

**Covers:**
- `collision.can_move_to(entity, new_x, new_y)`
- `collision.resolve_overlap(entity1, entity2)`
- Integration points with movement system (404)
- Solid entity blocking behavior

**Dependencies:** 405c, 404 (needs queries and movement system)

---

### 405e-projectile-and-picking

**Description:** Implement projectile hit detection and mouse selection/picking functionality.

**Covers:**
- `collision.check_projectile_hits(projectile)`
- Target validation (enemy check, already-hit tracking)
- `collision.pick_at_point(x, y)`
- `collision.pick_in_rect(x1, y1, x2, y2)`
- Selection priority sorting
- Projectile hit events

**Dependencies:** 405c (needs query API)

---

## Dependency Graph

```
402 (ECS)
    │
    ▼
  405a (primitives) ◄─── 404 (movement)
    │                        │
    ▼                        │
  405b (spatial hash)        │
    │                        │
    ▼                        │
  405c (queries)             │
    │                        │
    ├────────────────────────┘
    │         │
    ▼         ▼
  405d      405e
(movement)  (projectile/picking)
```

This split allows 405a, 405b, 405c to be implemented sequentially as the core collision system, then 405d and 405e can be worked on in parallel once the query API is stable.
