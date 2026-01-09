# Issue 016: Attribute Getter/Setter System

## Current Behavior

The guild hero system and ECS components have hardcoded stat access. There's no unified way to:
- Define attributes with constraints
- Apply modifiers from multiple sources
- Calculate derived attributes
- Map between different game systems (WC3 vs WoW)

## Intended Behavior

A system-agnostic attribute library that provides:
- Dispatch table-based getters/setters
- Array-indexed attribute storage for cache efficiency
- Config blocks defining attribute relationships
- Modifier stacks (base + equipment + buffs + auras)
- Derived attribute calculations with dependency tracking
- Event hooks for attribute changes
- Cross-system attribute mapping (WC3 ↔ WoW)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Attribute System                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Config    │  │  Registry   │  │  Dispatch   │              │
│  │   Blocks    │──│  (schemas)  │──│   Tables    │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│         │                │                │                      │
│         ▼                ▼                ▼                      │
│  ┌─────────────────────────────────────────────────┐            │
│  │              Attribute Container                 │            │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐         │            │
│  │  │  Base   │  │Modifiers│  │ Derived │         │            │
│  │  │ Values  │  │  Stack  │  │  Cache  │         │            │
│  │  └─────────┘  └─────────┘  └─────────┘         │            │
│  └─────────────────────────────────────────────────┘            │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────────────────────────────────────────┐            │
│  │           System-Specific Configs                │            │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │            │
│  │  │   WC3    │  │   WoW    │  │  Custom  │       │            │
│  │  │ Configs  │  │ Configs  │  │ Configs  │       │            │
│  │  └──────────┘  └──────────┘  └──────────┘       │            │
│  └─────────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Sub-Issues

| ID | Name | Description |
|----|------|-------------|
| 016a | Core attribute registry | Schema definitions, type system, constraints |
| 016b | Dispatch table getters | Read access with caching and validation |
| 016c | Dispatch table setters | Write access with events and constraints |
| 016d | Modifier stack system | Base + bonus layers with source tracking |
| 016e | Derived attribute engine | Dependency graphs, lazy evaluation, cache invalidation |
| 016f | WC3 attribute config | Strength/Agility/Intelligence, unit stats |
| 016g | WoW attribute config | Primary/secondary stats, ratings, resources |
| 016h | Cross-system mapping | Parallel attributes, conversion formulas |
| 016i | Integration tests | End-to-end validation of all systems |

## Design Principles

### 1. Dispatch Tables Over Conditionals

```lua
-- BAD: Switch/if chains
function get_stat(entity, stat_name)
    if stat_name == "strength" then
        return entity.strength
    elseif stat_name == "agility" then
        -- ...
    end
end

-- GOOD: Dispatch table
local GETTERS = {
    strength = function(e) return e.values[ATTR.STRENGTH] end,
    agility = function(e) return e.values[ATTR.AGILITY] end,
    -- ...
}

function get_stat(entity, stat_name)
    local getter = GETTERS[stat_name]
    return getter and getter(entity) or nil
end
```

### 2. Array Indexes Over String Keys

```lua
-- BAD: String key lookup every access
entity.stats["strength"] = 10

-- GOOD: Numeric index (compile-time constant)
local ATTR = {
    STRENGTH = 1,
    AGILITY = 2,
    INTELLIGENCE = 3,
    -- ...
}
entity.values[ATTR.STRENGTH] = 10
```

### 3. Config Blocks Define Relationships

```lua
-- Attribute schema config block
ATTRIBUTE_SCHEMA = {
    strength = {
        index = 1,
        type = "integer",
        min = 0,
        max = 999,
        default = 10,
        derives = { "attack_power", "block_value" },
        modifiable = true,
        persisted = true,
    },
    attack_power = {
        index = 10,
        type = "integer",
        derived_from = { "strength", "agility" },
        formula = function(attrs)
            return attrs.strength * 2 + attrs.agility
        end,
        modifiable = false,  -- Computed only
    },
}
```

### 4. Modifier Stacks with Sources

```lua
-- Each modifier tracks its source for removal
entity.modifiers.strength = {
    { source = "equipment:weapon_1", value = 15, type = "flat" },
    { source = "buff:blessing_of_kings", value = 10, type = "percent" },
    { source = "aura:devotion", value = 5, type = "flat" },
}

-- Final value = (base + flat_sum) * (1 + percent_sum/100)
```

## Related Documents

- `src/guild/hero.lua` - Current hardcoded stat system
- `src/runtime/ecs/wc3_components.lua` - ECS components with stats
- Issue 015 - WoW-style combat system (uses these attributes)

## Acceptance Criteria

- [ ] Attribute schemas defined via config blocks
- [ ] Getters use dispatch tables, not conditionals
- [ ] Values stored in arrays with numeric indexes
- [ ] Modifiers stack with source tracking
- [ ] Derived attributes auto-update on dependency change
- [ ] WC3 and WoW configs provided
- [ ] Cross-system mapping documented and implemented
- [ ] All tests pass

---

**Status:** Pending
**Priority:** Medium
**Dependencies:** Issue 014 (Guild System), Issue 015 (WoW Combat)
