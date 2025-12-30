# BOUNTY BOARD: The Hivemind Component

```
╔══════════════════════════════════════════════════════════════════╗
║  ⚔️  BOSS MONSTER BOUNTY  ⚔️                                      ║
║                                                                  ║
║  Name: THE HIVEMIND COMPONENT                                    ║
║  Threat Level: ███████░░░ (7/10)                                 ║
║  Location: The Component Registry (component.lua:83-85)          ║
║  Reward: Entity independence, predictable game state             ║
║                                                                  ║
║  "Move one footman, and a hundred move with it.                 ║
║   Damage one building, and all buildings crumble.               ║
║   They share a mind. A single, corrupted mind."                 ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## The Monster's Nature

The Hivemind is a classic Lua demon. When component defaults contain tables, those tables are shallow-copied. Every entity with that component shares the SAME table reference. Mutate one entity's position, and you mutate them all.

This is the footgun that has claimed countless Lua developers. It lurks in initialization code, waiting for the day someone adds a table-valued default.

---

## Lair Location

```lua
-- component.lua, lines 83-85
for k, v in pairs(defaults) do
    component_types[name][k] = v  -- SHALLOW COPY - TABLES ARE SHARED
end
```

---

## Battle Strategy

### What the Monster Exploits

```lua
-- Innocent-looking component registration
register_component("Position", {
    x = 0,
    y = 0,
    velocity = { vx = 0, vy = 0 }  -- THIS TABLE IS SHARED
})

-- Create two entities
local e1 = create_entity()
local e2 = create_entity()
add_component(e1, "Position")
add_component(e2, "Position")

-- Move entity 1
get_component(e1, "Position").velocity.vx = 10

-- Entity 2 is ALSO moving now!
print(get_component(e2, "Position").velocity.vx)  -- Prints 10!
```

### Weapons Required

**Weapon 1: Deep Copy Function**

```lua
-- {{{ deep_copy
-- Recursively copies tables to prevent shared references
local function deep_copy(obj)
    if type(obj) ~= "table" then
        return obj
    end
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = deep_copy(v)
    end
    return copy
end
-- }}}

-- Apply when copying defaults
for k, v in pairs(defaults) do
    component_types[name][k] = deep_copy(v)
end
```

**Weapon 2: Factory Functions**

```lua
-- Instead of table defaults, use factory functions
register_component("Position", {
    x = 0,
    y = 0,
    velocity = function() return { vx = 0, vy = 0 } end
})

-- When adding component, call factories
for k, v in pairs(defaults) do
    if type(v) == "function" then
        component[k] = v()  -- New table each time
    else
        component[k] = v
    end
end
```

**Weapon 3: Immutable Defaults + Explicit Init**

```lua
-- Defaults are primitives only, complex state set explicitly
register_component("Position", {
    x = 0,
    y = 0,
    -- No velocity in defaults
})

-- Explicit initialization
local pos = add_component(entity, "Position")
pos.velocity = { vx = 0, vy = 0 }  -- New table per entity
```

---

## Victory Conditions

- [ ] Modifying one entity's component doesn't affect others
- [ ] Deep copy handles nested tables correctly
- [ ] Circular references don't cause infinite loops (if supporting them)
- [ ] Performance: Deep copy doesn't significantly slow entity creation

---

## Test Arena

```lua
-- The Hivemind Detection Test
local function test_component_independence()
    register_component("TestComp", {
        value = 0,
        nested = { inner = 0 }
    })

    local e1 = create_entity()
    local e2 = create_entity()
    add_component(e1, "TestComp")
    add_component(e2, "TestComp")

    -- Modify e1
    get_component(e1, "TestComp").value = 42
    get_component(e1, "TestComp").nested.inner = 99

    -- e2 should be unaffected
    assert(get_component(e2, "TestComp").value == 0,
        "Hivemind detected: primitive value shared")
    assert(get_component(e2, "TestComp").nested.inner == 0,
        "Hivemind detected: nested table shared")

    print("Entities are independent. The Hivemind is slain.")
end
```

---

## Adventurer's Log

*"I gave the peasant a pickaxe. Suddenly, every peasant in my kingdom held one. I ordered the knight to attack. Every knight charged. The Hivemind had claimed my army."*

— Map Maker, debugging entity behavior

---

## Lore: The Shallow Copy Curse

In ancient times, Lua developers learned of references. A table assigned to a variable does not copy - it points. The wise ones learned `deep_copy`. The foolish ones shipped bugs.

The curse manifests most often in:
- ECS component defaults
- Configuration tables
- Prototype patterns

---

## Related Scrolls

- `src/runtime/ecs/component.lua` - The registry of shared minds
- `src/runtime/ecs/entity.lua` - Where components attach
- Lua Reference Manual, Section 2.1 - Values and Types

---

**Bounty Posted By:** The Entity Sovereignty Movement
**Date:** 2025-12-29
**Status:** UNCLAIMED
