# Issue 701b: Spirit World Layer

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Implementation
**Priority:** High
**Parent:** 701-death-and-resurrection-system.md
**Dependencies:** 701a (Death state), 402 (ECS), 404 (Movement)

---

## Current Behavior

There is only one world layer. All entities exist in the same coordinate space
and interact with each other. Dead heroes have nowhere to go.

---

## Intended Behavior

A parallel "spirit world" layer where ghosts exist:
1. Ghosts use the same (x, y) coordinates but on a separate layer
2. Ghosts don't collide with living entities
3. Ghosts can see the mortal realm but not interact with it
4. Movement works normally but ignores terrain obstacles
5. Layer is tracked via component, not separate coordinate system

---

## Suggested Implementation Steps

1. Add `layer` field to position component (or create layer component):
   ```lua
   -- Option A: Add to position
   position.layer = "mortal"  -- "mortal" or "spirit"

   -- Option B: Separate component
   ecs.register_component("layer", {
       name = "mortal",  -- "mortal" or "spirit"
   })
   ```

2. Define layer constants:
   ```lua
   death.LAYER = {
       MORTAL = "mortal",
       SPIRIT = "spirit",
   }
   ```

3. Update collision queries to respect layers:
   - Entities on different layers don't collide
   - Spatial queries can filter by layer

4. Add layer transition functions:
   ```lua
   death.send_to_spirit_world(entity)  -- Move to spirit layer
   death.return_to_mortal_world(entity)  -- Return to mortal layer
   ```

5. Ghost movement ignores terrain pathing:
   - Flying movement type while in spirit world
   - Or skip pathing entirely, direct movement

---

## Layer Component Design

```lua
-- Simple layer tracking
ecs.register_component("world_layer", {
    layer = "mortal",  -- "mortal" or "spirit"
})

-- Constants
death.LAYER = {
    MORTAL = "mortal",
    SPIRIT = "spirit",
}
```

---

## API Design

```lua
local death = require("runtime.systems.death")

-- Layer queries
death.get_layer(entity)         -- Returns "mortal" or "spirit"
death.is_in_spirit_world(entity)  -- Returns true if on spirit layer
death.is_in_mortal_world(entity)  -- Returns true if on mortal layer

-- Layer transitions
death.send_to_spirit_world(entity)    -- Transition to spirit layer
death.return_to_mortal_world(entity)  -- Transition to mortal layer

-- Spatial query helpers
death.query_mortal(component, ...)   -- Query only mortal entities
death.query_spirit(component, ...)   -- Query only spirit entities
```

---

## Collision Integration

The collision system (405) needs layer awareness:

```lua
-- In collision.lua, modify collision checks:
local function can_collide(entity_a, entity_b)
    local layer_a = ecs.get_component(entity_a, "world_layer")
    local layer_b = ecs.get_component(entity_b, "world_layer")

    -- Default to mortal layer
    local a_layer = layer_a and layer_a.layer or "mortal"
    local b_layer = layer_b and layer_b.layer or "mortal"

    -- Only collide if same layer
    return a_layer == b_layer
end
```

---

## Movement in Spirit World

Ghosts in spirit world use simplified movement:
- Ignore terrain passability (fly over everything)
- Still use pathfinding for aesthetic movement
- Or direct point-to-point movement

```lua
-- When creating ghost, modify movement component
mov.pathing_type = movement.PATHING_TYPE.FLY
-- Or set a special ghost pathing type
mov.pathing_type = "ghost"  -- Always passable
```

---

## Acceptance Criteria

- [ ] `world_layer` component registered with ECS
- [ ] Layer constants defined (MORTAL, SPIRIT)
- [ ] `send_to_spirit_world()` transitions entity to spirit layer
- [ ] `return_to_mortal_world()` transitions back
- [ ] Collision queries respect layer separation
- [ ] Spirit entities can move through terrain
- [ ] Unit tests for layer transitions
- [ ] Unit tests for layer-aware collision

---

## Notes

The spirit world is conceptually simple: same coordinates, different layer.
This avoids:
- Duplicate position tracking
- Complex coordinate transformations
- Separate movement systems

The layer component is intentionally minimal. Visibility rules (who can see
ghosts) are handled in rendering, not here.

Future consideration: Other layers could exist (ethereal plane, void, etc.)
for spell effects or special mechanics.
