# Issue 402: Build Entity Component System

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Critical
**Dependencies:** 401-implement-game-tick-update-loop

---

## Current Behavior

Game objects (units, doodads, regions, etc.) exist only as parsed data structures
with no runtime behavior or state management.

---

## Intended Behavior

An Entity Component System (ECS) that:
- Manages all game entities (units, buildings, doodads, items, projectiles)
- Attaches components for different behaviors (position, health, movement, etc.)
- Provides efficient queries by component type
- Supports entity creation, destruction, and lifecycle hooks
- Enables data-driven entity definitions

---

## Suggested Implementation Steps

1. **Create ECS module structure**
   ```
   src/runtime/
   ├── ecs/
   │   ├── init.lua       (main API)
   │   ├── entity.lua     (entity management)
   │   ├── component.lua  (component registry)
   │   └── system.lua     (system management)
   ```

2. **Implement Entity Manager**
   ```lua
   -- Entity is just an ID
   local next_entity_id = 1
   local entities = {}        -- id -> { components }
   local free_ids = {}        -- recycled IDs

   function ecs.create_entity()
       local id = table.remove(free_ids) or next_entity_id
       if id == next_entity_id then next_entity_id = next_entity_id + 1 end
       entities[id] = {}
       return id
   end

   function ecs.destroy_entity(id)
       entities[id] = nil
       table.insert(free_ids, id)
   end
   ```

3. **Implement Component System**
   ```lua
   -- Component types registry
   local component_types = {}

   function ecs.register_component(name, defaults)
       component_types[name] = defaults
   end

   function ecs.add_component(entity, component_name, data)
       local defaults = component_types[component_name]
       local component = setmetatable(data or {}, {__index = defaults})
       entities[entity][component_name] = component
       -- Update component index for queries
   end

   function ecs.get_component(entity, component_name)
       return entities[entity] and entities[entity][component_name]
   end
   ```

4. **Define core WC3 components**
   ```lua
   -- Position in world
   ecs.register_component("position", {
       x = 0, y = 0, z = 0,
       facing = 0,  -- radians
   })

   -- Health/mana
   ecs.register_component("stats", {
       hp = 100, hp_max = 100,
       mp = 0, mp_max = 0,
       armor = 0,
       regen_hp = 0, regen_mp = 0,
   })

   -- Movement capability
   ecs.register_component("movement", {
       speed = 270,        -- base movement speed
       speed_current = 270,
       pathing_type = "foot",  -- foot, horse, fly, float, amphibious
       collision_size = 32,
   })

   -- Ownership
   ecs.register_component("owner", {
       player_id = 0,  -- 0-15, or neutral
   })

   -- Unit type reference
   ecs.register_component("unit_type", {
       type_id = "",   -- e.g., "hfoo" for footman
   })

   -- Selection state
   ecs.register_component("selectable", {
       selected = false,
       selection_scale = 1.0,
   })
   ```

5. **Implement System Registration**
   ```lua
   local systems = {}  -- ordered list of systems

   function ecs.register_system(name, required_components, update_fn)
       systems[#systems + 1] = {
           name = name,
           requires = required_components,
           update = update_fn,
       }
   end

   function ecs.update(dt)
       for _, system in ipairs(systems) do
           -- Query entities with required components
           local matching = ecs.query(system.requires)
           system.update(matching, dt)
       end
   end
   ```

6. **Implement efficient queries**
   ```lua
   -- Maintain component -> entity indices for fast queries
   local component_index = {}  -- component_name -> set of entity ids

   function ecs.query(component_names)
       -- Return iterator over entities with ALL specified components
   end

   function ecs.query_single(component_name)
       -- Return iterator over entities with specific component
   end
   ```

---

## Technical Notes

### Entity ID Strategy

Using numeric IDs allows:
- Fast lookup in tables
- Easy serialization for save/replay
- ID recycling to prevent unbounded growth

### Component Design

Components should be pure data - no methods. Behavior lives in Systems.
This enables:
- Data-oriented design (cache-friendly iteration)
- Easy serialization
- Clear separation of concerns

### WC3 Entity Types

Map to ECS entities with appropriate components:

| WC3 Type | Components |
|----------|------------|
| Unit | position, stats, movement, owner, unit_type, selectable |
| Building | position, stats, owner, unit_type, selectable, training_queue |
| Doodad | position, doodad_type |
| Destructible | position, stats, destructible_type |
| Item | position, item_type, (owner if carried) |
| Projectile | position, movement, projectile_data |

### Handle Pattern

Consider wrapping entity IDs in handles that can detect if the entity
was destroyed (generation counter pattern), similar to WC3's handle system.

---

## Related Documents

- docs/roadmap.md (Phase 4 overview)
- issues/401-implement-game-tick-update-loop.md (calls ecs.update)
- issues/206-design-game-object-types.md (type definitions)

---

## Acceptance Criteria

- [ ] Entity creation and destruction
- [ ] Component registration with defaults
- [ ] Add/remove/get components on entities
- [ ] Query entities by component(s)
- [ ] System registration and update loop
- [ ] Core WC3 components defined (position, stats, movement, owner)
- [ ] Entity ID recycling
- [ ] Handle pattern for safe references (optional but recommended)
- [ ] Unit tests for ECS operations

---

## Notes

The ECS is the foundation for all runtime game objects. Keep it simple
and efficient - premature optimization is the enemy, but so is a slow
inner loop that runs 62.5 times per second.

Consider whether a full ECS is needed or if a simpler object model
would suffice. WC3 isn't a bullet-hell game with thousands of entities,
so pure ECS performance benefits may be marginal. The main benefit is
architectural clarity.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:15*

I'll analyze this issue to determine if splitting would be beneficial.

This is a substantial feature with several distinct responsibilities. Let me break it down:

---

## Sub-Issue Analysis

**Recommendation: SPLIT**

This issue covers multiple distinct concerns that would benefit from separate implementation and testing cycles. The ECS has clear architectural layers that map well to sub-issues.

---

### Suggested Sub-Issues

#### 402a-implement-entity-manager
**Description:** Core entity ID management - creation, destruction, ID recycling, and the entities table structure.

**Covers:**
- `next_entity_id` counter and `entities` table
- `create_entity()` function
- `destroy_entity()` function  
- ID recycling with `free_ids` pool
- Basic entity existence checks

**Dependencies:** None (foundational)

**Acceptance Criteria:**
- Entity creation returns unique IDs
- Destroyed entity IDs are recycled
- Cannot access components of destroyed entities

---

#### 402b-implement-component-registry
**Description:** Component type registration system with defaults and component attachment/retrieval on entities.

**Covers:**
- `component_types` registry
- `register_component(name, defaults)`
- `add_component(entity, name, data)`
- `remove_component(entity, name)`
- `get_component(entity, name)`
- `has_component(entity, name)`
- Metatable inheritance for defaults

**Dependencies:** 402a (needs entity storage)

**Acceptance Criteria:**
- Components registered with default values
- Components inherit defaults via metatable
- Add/remove/get/has operations work correctly

---

#### 402c-implement-component-queries
**Description:** Efficient querying of entities by component type(s), including index maintenance for fast lookups.

**Covers:**
- `component_index` table (component_name → entity set)
- Index updates on add/remove component
- `query(component_names)` - entities with ALL components
- `query_single(component_name)` - entities with one component
- Iterator pattern for memory efficiency

**Dependencies:** 402b (needs component storage)

**Acceptance Criteria:**
- Queries return correct entity sets
- Index stays synchronized with component changes
- Multi-component queries use intersection

---

#### 402d-implement-system-registration
**Description:** System registration and the update loop that iterates systems and feeds them matching entities.

**Covers:**
- `systems` ordered list
- `register_system(name, required_components, update_fn)`
- `ecs.update(dt)` main loop
- System execution order guarantees
- Integration with game tick from 401

**Dependencies:** 402c (needs query system)

**Acceptance Criteria:**
- Systems registered in order
- Update calls each system with matching entities
- Systems receive correct dt value

---

#### 402e-define-core-wc3-components
**Description:** Define the standard WC3 component types (position, stats, movement, owner, unit_type, selectable) with appropriate defaults.

**Covers:**
- `position` component (x, y, z, facing)
- `stats` component (hp, mp, armor, regen)
- `movement` component (speed, pathing_type, collision)
- `owner` component (player_id)
- `unit_type` component (type_id reference)
- `selectable` component (selection state)
- Documentation of WC3 entity → component mapping

**Dependencies:** 402b (needs register_component)

**Acceptance Criteria:**
- All core components registered
- Defaults match WC3 sensible values
- Component mapping table documented

---

#### 402f-implement-entity-handles (Optional)
**Description:** Generation-counter handle pattern for safe entity references that detect destroyed entities.

**Covers:**
- Generation counter per entity slot
- `Handle` wrapper type
- `handle:valid()` check
- `handle:get()` safe entity access
- Handle creation on entity spawn

**Dependencies:** 402a (needs entity lifecycle)

**Acceptance Criteria:**
- Handles invalidate when entity destroyed
- Stale handles return nil/false
- Handle overhead is minimal

---

### Dependency Graph

```
402a (entity manager)
  │
  ▼
402b (component registry)
  │
  ├──────────────────┐
  ▼                  ▼
402c (queries)    402e (wc3 components)
  │
  ▼
402d (systems)

402a ──▶ 402f (handles) [optional]
```

---

### Implementation Order

1. **402a** - Entity manager (foundation)
2. **402b** - Component registry (builds on entities)
3. **402c** and **402e** in parallel (both need 402b)
4. **402d** - Systems (needs queries)
5. **402f** - Handles (optional, can be deferred)

---

### Notes

The "optional but recommended" handle pattern (402f) could be deferred to a later iteration if time is constrained. The core ECS (402a-d) plus WC3 components (402e) form the minimum viable implementation.

Each sub-issue is testable in isolation, which aligns with the iterative development philosophy - get the interface right, then refine.
