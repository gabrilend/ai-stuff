# Issue 406a: Core Resource Storage

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 406-build-resource-management-system.md
**Dependencies:** None (foundational)

---

## Current Behavior

No resource tracking exists. There is no way to store, retrieve, or modify player resources like gold, lumber, or food.

---

## Intended Behavior

Implement the foundational resource storage system:
- Define standard WC3 resource types (gold, lumber, food_used, food_cap)
- Initialize per-player resource storage
- Provide getter/setter API with clamping to valid ranges
- Fire events when resources change
- Allow registration of custom resource types for map-specific mechanics

**API:**
```lua
-- Get/set individual resources
resources.get(player_id, resource_name) -> amount
resources.set(player_id, resource_name, amount)
resources.add(player_id, resource_name, amount)
resources.subtract(player_id, resource_name, amount)

-- Initialize player
resources.init_player(player_id)

-- Register custom resource types
resources.register_type(name, config)

-- Events fired:
-- "resource_changed", player_id, resource_name, old_value, new_value
```

---

## Suggested Implementation Steps

1. **Create resources module**
   ```
   src/runtime/resources.lua
   ```

2. **Define resource type registry**
   ```lua
   -- src/runtime/resources.lua
   local resources = {}

   -- {{{ Resource type definitions
   -- Standard WC3 resources with their constraints
   local RESOURCE_TYPES = {
       gold = {
           max = 999999,
           default = 0,
           description = "Primary currency from gold mines",
       },
       lumber = {
           max = 999999,
           default = 0,
           description = "Secondary currency from trees",
       },
       food_used = {
           max = 300,      -- WC3 max is typically 100, but some maps go higher
           default = 0,
           description = "Population currently in use",
       },
       food_cap = {
           max = 300,
           default = 0,
           description = "Maximum population capacity",
       },
   }
   -- }}}
   ```

3. **Implement custom resource registration**
   ```lua
   -- {{{ register_type
   -- Register a new resource type (for custom map resources)
   -- name: string identifier for the resource
   -- config: table with max, default, and optional description
   function resources.register_type(name, config)
       if RESOURCE_TYPES[name] then
           -- Allow updating existing type configs
           for k, v in pairs(config) do
               RESOURCE_TYPES[name][k] = v
           end
       else
           RESOURCE_TYPES[name] = {
               max = config.max or 999999,
               default = config.default or 0,
               description = config.description or "",
           }
       end
   end
   -- }}}

   -- {{{ get_type_config
   function resources.get_type_config(name)
       return RESOURCE_TYPES[name]
   end
   -- }}}

   -- {{{ get_all_types
   function resources.get_all_types()
       local types = {}
       for name in pairs(RESOURCE_TYPES) do
           types[#types + 1] = name
       end
       return types
   end
   -- }}}
   ```

4. **Implement player resource storage**
   ```lua
   -- {{{ Player storage
   -- Per-player resource storage
   -- Structure: player_resources[player_id][resource_name] = amount
   local player_resources = {}
   -- }}}

   -- {{{ init_player
   -- Initialize resources for a new player
   -- Called when player joins or game starts
   function resources.init_player(player_id)
       player_resources[player_id] = {}

       for name, config in pairs(RESOURCE_TYPES) do
           player_resources[player_id][name] = config.default
       end

       fire_event("player_resources_initialized", player_id)
   end
   -- }}}

   -- {{{ reset_player
   -- Reset player resources to defaults
   function resources.reset_player(player_id)
       if not player_resources[player_id] then
           resources.init_player(player_id)
           return
       end

       for name, config in pairs(RESOURCE_TYPES) do
           resources.set(player_id, name, config.default)
       end
   end
   -- }}}

   -- {{{ remove_player
   -- Clean up player resources
   function resources.remove_player(player_id)
       player_resources[player_id] = nil
   end
   -- }}}
   ```

5. **Implement getter**
   ```lua
   -- {{{ get
   -- Get current amount of a resource for a player
   -- Returns 0 if player or resource doesn't exist
   function resources.get(player_id, resource_name)
       local player = player_resources[player_id]
       if not player then
           return 0
       end
       return player[resource_name] or 0
   end
   -- }}}

   -- {{{ get_all
   -- Get all resources for a player as a table
   function resources.get_all(player_id)
       local player = player_resources[player_id]
       if not player then
           return {}
       end

       local result = {}
       for name, amount in pairs(player) do
           result[name] = amount
       end
       return result
   end
   -- }}}
   ```

6. **Implement setter with clamping and events**
   ```lua
   -- {{{ set
   -- Set a resource to a specific value
   -- Clamps to valid range [0, max]
   -- Fires resource_changed event if value actually changed
   function resources.set(player_id, resource_name, amount)
       -- Ensure player exists
       if not player_resources[player_id] then
           resources.init_player(player_id)
       end

       local config = RESOURCE_TYPES[resource_name]
       if not config then
           -- Unknown resource type - create with defaults
           config = { max = 999999, default = 0 }
       end

       local old_value = player_resources[player_id][resource_name] or 0

       -- Clamp to valid range
       local new_value = math.max(0, math.min(amount, config.max))

       player_resources[player_id][resource_name] = new_value

       -- Fire event if changed
       if old_value ~= new_value then
           fire_event("resource_changed", player_id, resource_name, old_value, new_value)
       end

       return new_value
   end
   -- }}}
   ```

7. **Implement add and subtract helpers**
   ```lua
   -- {{{ add
   -- Add amount to a resource (can be negative)
   -- Returns the new value
   function resources.add(player_id, resource_name, amount)
       local current = resources.get(player_id, resource_name)
       return resources.set(player_id, resource_name, current + amount)
   end
   -- }}}

   -- {{{ subtract
   -- Subtract amount from a resource
   -- Returns the new value
   function resources.subtract(player_id, resource_name, amount)
       return resources.add(player_id, resource_name, -amount)
   end
   -- }}}
   ```

8. **Add event firing placeholder**
   ```lua
   -- {{{ Event firing
   -- Placeholder for event system integration
   -- Will be connected to actual event system
   local function fire_event(event_name, ...)
       -- TODO: Connect to game event system
       -- For now, call registered listeners directly
       local listeners = resources._event_listeners[event_name]
       if listeners then
           for _, fn in ipairs(listeners) do
               fn(...)
           end
       end
   end

   -- Simple listener registration for testing
   resources._event_listeners = {}

   function resources.on(event_name, callback)
       if not resources._event_listeners[event_name] then
           resources._event_listeners[event_name] = {}
       end
       table.insert(resources._event_listeners[event_name], callback)
   end
   -- }}}
   ```

9. **Create unit tests**
   ```lua
   -- src/tests/test_resources_core.lua

   -- Test init_player creates storage
   -- Test get returns 0 for uninitialized player
   -- Test get returns default for initialized player
   -- Test set clamps to min (0)
   -- Test set clamps to max
   -- Test set fires resource_changed event
   -- Test add increases value
   -- Test subtract decreases value
   -- Test register_type adds custom resource
   -- Test custom resources work with get/set
   ```

---

## Related Documents

- issues/406-build-resource-management-system.md (parent issue)
- issues/406b-spending-validation.md (next - uses getters/setters)
- issues/406c-food-and-harvesting.md (uses add/subtract)
- issues/407-create-player-state-management.md (player ownership)

---

## Acceptance Criteria

- [x] `src/runtime/resources.lua` exists
- [x] `RESOURCE_TYPES` defines gold, lumber, food_used, food_cap
- [x] `init_player()` creates storage with defaults
- [x] `get()` returns current resource amount
- [x] `get()` returns 0 for unknown player/resource
- [x] `set()` clamps to valid range [0, max]
- [x] `set()` fires `resource_changed` event when value changes
- [x] `add()` increases resource amount
- [x] `subtract()` decreases resource amount
- [x] `register_type()` allows custom resources
- [x] Custom resources work with all get/set operations
- [x] Unit tests pass for all operations

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Created src/runtime/resources.lua (~340 lines):**
   - Module header with documentation
   - DEFAULT_RESOURCE_TYPES and copy_resource_types for reset support
   - RESOURCE_TYPES with gold, lumber, food_used, food_cap

2. **Resource type management:**
   - `register_type(name, config)` - add/update resource types
   - `get_type_config(name)` - query type configuration
   - `get_all_types()` - list all registered types

3. **Player storage:**
   - `init_player(player_id)` - initialize with defaults
   - `reset_player(player_id)` - restore defaults
   - `remove_player(player_id)` - cleanup
   - `has_player(player_id)` - check initialization

4. **Getters/Setters:**
   - `get(player_id, resource_name)` - returns 0 for unknown
   - `get_all(player_id)` - all resources as table
   - `set(player_id, resource_name, amount)` - with clamping and events
   - `add(player_id, resource_name, amount)` - increment
   - `subtract(player_id, resource_name, amount)` - decrement

5. **Event system:**
   - `on(event_name, callback)` - register listeners
   - `clear_events()` - remove all listeners
   - Events: resource_changed, player_resources_initialized

6. **Constants:**
   - `resources.TYPES.GOLD`, `LUMBER`, `FOOD_USED`, `FOOD_CAP`

### Test Coverage

Created src/tests/test_resources.lua with 37 tests:
- Resource type tests (6)
- Player initialization tests (6)
- Get tests (5)
- Set tests (8)
- Add/subtract tests (5)
- Event system tests (3)
- Multiple player tests (2)
- Custom resource tests (2)

---

## Notes

**Resource naming convention:**
- Use lowercase snake_case for resource names
- Standard resources: `gold`, `lumber`, `food_used`, `food_cap`
- Custom resources: `bounty`, `mana_crystals`, etc. (map-defined)

**Player IDs:**
- Assumed to be integers 0-15 (matching WC3 player slots)
- Neutral players (hostile, passive) also have resources
- Player ID 0 is typically "local" player in single player

**Clamping behavior:**
- Values below 0 become 0 (can't have negative resources)
- Values above max become max (prevents overflow)
- Event only fires if actual value changed (not if clamped to same value)

**Event system:**
- Simple callback-based for now
- Will integrate with game-wide event bus later
- `resource_changed` event args: player_id, resource_name, old_value, new_value

**Starting resources:**
- This module only provides storage, not initialization values
- Melee game setup will call: `set(player, "gold", 500)`, `set(player, "lumber", 150)`, etc.
