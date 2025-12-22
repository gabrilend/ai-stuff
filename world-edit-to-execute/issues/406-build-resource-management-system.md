# Issue 406: Build Resource Management System

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Dependencies:** 401, 402, 407

---

## Current Behavior

No resource tracking exists. Gold, lumber, food, and other resources cannot
be tracked, spent, or earned.

---

## Intended Behavior

A resource management system that:
- Tracks gold, lumber, food for each player
- Handles resource income from harvesting
- Validates spending (unit training, upgrades, building)
- Supports food supply/used tracking
- Fires events for resource changes
- Supports custom resources for map-specific mechanics

---

## Suggested Implementation Steps

1. **Create resource module**
   ```
   src/runtime/
   └── resources.lua
   ```

2. **Define resource types**
   ```lua
   local RESOURCE_TYPES = {
       gold = { max = 999999, default = 0 },
       lumber = { max = 999999, default = 0 },
       food_used = { max = 999, default = 0 },
       food_cap = { max = 999, default = 0 },
   }

   -- Custom resources can be registered by maps
   function resources.register_type(name, config)
       RESOURCE_TYPES[name] = config
   end
   ```

3. **Player resource storage**
   ```lua
   -- Resources stored per player
   local player_resources = {}  -- player_id -> { resource_name -> amount }

   function resources.init_player(player_id)
       player_resources[player_id] = {}
       for name, config in pairs(RESOURCE_TYPES) do
           player_resources[player_id][name] = config.default
       end
   end
   ```

4. **Resource getters/setters**
   ```lua
   function resources.get(player_id, resource_name)
       return player_resources[player_id][resource_name] or 0
   end

   function resources.set(player_id, resource_name, amount)
       local config = RESOURCE_TYPES[resource_name]
       local old = player_resources[player_id][resource_name]
       local new = math.max(0, math.min(amount, config.max))

       player_resources[player_id][resource_name] = new

       if old ~= new then
           fire_event("resource_changed", player_id, resource_name, old, new)
       end
   end

   function resources.add(player_id, resource_name, amount)
       local current = resources.get(player_id, resource_name)
       resources.set(player_id, resource_name, current + amount)
   end

   function resources.subtract(player_id, resource_name, amount)
       resources.add(player_id, resource_name, -amount)
   end
   ```

5. **Cost validation and spending**
   ```lua
   -- Cost table: { gold = 100, lumber = 50, food = 2 }
   function resources.can_afford(player_id, cost)
       for resource, amount in pairs(cost) do
           if resources.get(player_id, resource) < amount then
               return false, resource
           end
       end

       -- Special check for food
       if cost.food then
           local used = resources.get(player_id, "food_used")
           local cap = resources.get(player_id, "food_cap")
           if used + cost.food > cap then
               return false, "food"
           end
       end

       return true
   end

   function resources.spend(player_id, cost)
       local can, missing = resources.can_afford(player_id, cost)
       if not can then
           return false, missing
       end

       for resource, amount in pairs(cost) do
           if resource == "food" then
               resources.add(player_id, "food_used", amount)
           else
               resources.subtract(player_id, resource, amount)
           end
       end

       return true
   end

   function resources.refund(player_id, cost)
       -- Inverse of spend, for cancelled orders
       for resource, amount in pairs(cost) do
           if resource == "food" then
               resources.subtract(player_id, "food_used", amount)
           else
               resources.add(player_id, resource, amount)
           end
       end
   end
   ```

6. **Food supply management**
   ```lua
   -- Called when food-providing buildings are created/destroyed
   function resources.add_food_supply(player_id, amount)
       resources.add(player_id, "food_cap", amount)
   end

   function resources.remove_food_supply(player_id, amount)
       resources.subtract(player_id, "food_cap", amount)
   end

   -- Called when food-consuming units are created/destroyed
   function resources.add_food_used(player_id, amount)
       resources.add(player_id, "food_used", amount)
   end

   function resources.remove_food_used(player_id, amount)
       resources.subtract(player_id, "food_used", amount)
   end

   function resources.get_food_status(player_id)
       return {
           used = resources.get(player_id, "food_used"),
           cap = resources.get(player_id, "food_cap"),
       }
   end
   ```

7. **Harvesting integration**
   ```lua
   -- Called by worker AI when depositing resources
   function resources.deposit_harvest(player_id, resource_name, amount)
       resources.add(player_id, resource_name, amount)
       fire_event("harvest_deposited", player_id, resource_name, amount)
   end

   -- Gold mines have limited capacity
   function resources.deplete_gold_mine(mine_entity, amount)
       local mine = ecs.get_component(mine_entity, "gold_mine")
       mine.gold_remaining = mine.gold_remaining - amount

       if mine.gold_remaining <= 0 then
           fire_event("gold_mine_depleted", mine_entity)
       end
   end
   ```

8. **Income rates (optional)**
   ```lua
   -- For maps with periodic income
   function resources.set_income_rate(player_id, resource_name, per_second)
   end

   function resources.process_income(dt)
       -- Called each tick, adds income * dt to resources
   end
   ```

---

## Technical Notes

### WC3 Resource System

Standard WC3 resources:
- Gold: Primary currency, harvested from mines
- Lumber: Secondary currency, harvested from trees
- Food: Population limit (used/cap)

Some maps add custom resources via triggers.

### Food Mechanics

- Food cap increases when farms/ziggurats/etc. complete
- Food cap decreases when food buildings are destroyed
- Food used increases when units train
- Food used decreases when units die
- Max food cap is typically 100 in standard WC3

### Race Starting Resources

Typical melee starting resources:
- 500 gold, 150 lumber
- 5 food used (starting workers)
- 10-12 food cap (town hall)

### Upkeep System

WC3 has upkeep levels affecting gold income:
- No upkeep (0-50 food): 100% gold from mines
- Low upkeep (51-80 food): 70% gold
- High upkeep (81+ food): 40% gold

This can be implemented as a modifier in the harvesting system.

---

## Related Documents

- issues/407-create-player-state-management.md (player ownership)
- issues/402-build-entity-component-system.md (gold mine component)

---

## Acceptance Criteria

- [ ] Track gold per player
- [ ] Track lumber per player
- [ ] Track food used/cap per player
- [ ] can_afford() validation
- [ ] spend() with atomicity (all or nothing)
- [ ] refund() for cancelled orders
- [ ] Food supply add/remove
- [ ] Resource change events
- [ ] Custom resource registration
- [ ] Unit tests for resource operations

---

## Notes

The resource system is relatively simple but critical for gameplay. It
integrates with:
- Training queue (check costs before training)
- Building placement (check costs before building)
- Upgrade system (check costs before researching)
- Harvesting AI (deposit resources)

Keep the API clean and event-driven so other systems can react to
resource changes (UI updates, AI decisions, trigger conditions).

Consider thread-safety if the game loop and UI run on different threads,
though for Phase 4 single-threaded is likely fine.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:17*

Looking at this issue, I can analyze whether splitting would be beneficial.

## Analysis

This issue is **moderately complex** but has a coherent scope. Let me evaluate the splitting criteria:

**Arguments for keeping as-is:**
- All functionality lives in a single module (`resources.lua`)
- The components are tightly coupled (getters need storage, spending needs validation, etc.)
- The suggested implementation is already well-structured with clear steps
- Total scope is manageable (~200-300 lines of code)

**Arguments for splitting:**
- There are distinct functional areas (core storage, spending/validation, food mechanics, harvesting integration)
- Testing each area independently could be cleaner
- Income rates are explicitly marked "optional"

## Recommendation: **Split into 3 sub-issues**

While the issue *could* be implemented as one piece, splitting provides clearer milestones and better testability. Here's my suggested breakdown:

---

### 406a-core-resource-storage

**Description:** Core resource type definitions, player storage initialization, and basic getters/setters with event firing.

**Covers:**
- `RESOURCE_TYPES` definition with gold, lumber, food_used, food_cap
- `resources.register_type()` for custom resources
- `resources.init_player()` 
- `resources.get()`, `resources.set()`, `resources.add()`, `resources.subtract()`
- Resource change event firing

**Dependencies:** None (foundational)

**Acceptance criteria from parent:** Track gold, lumber, food per player; resource change events; custom resource registration

---

### 406b-spending-validation

**Description:** Cost validation, atomic spending, and refund operations for training/building/upgrades.

**Covers:**
- `resources.can_afford(cost_table)` with food cap checking
- `resources.spend()` with atomicity guarantee
- `resources.refund()` for cancelled orders

**Dependencies:** 406a (needs getters/setters)

**Acceptance criteria from parent:** can_afford() validation; spend() with atomicity; refund() for cancelled orders

---

### 406c-food-and-harvesting

**Description:** Food supply management (buildings providing cap) and harvesting integration (deposit, gold mine depletion).

**Covers:**
- `resources.add_food_supply()`, `resources.remove_food_supply()`
- `resources.add_food_used()`, `resources.remove_food_used()`
- `resources.get_food_status()`
- `resources.deposit_harvest()`
- `resources.deplete_gold_mine()` with depletion events
- (Optional) Income rate system for custom maps

**Dependencies:** 406a (needs add/subtract), 402 (ECS for gold mine component)

**Acceptance criteria from parent:** Food supply add/remove; unit tests for resource operations

---

## Dependency Graph

```
406a (core storage)
  │
  ├──▶ 406b (spending/validation)
  │
  └──▶ 406c (food & harvesting)
            │
            └──▶ depends on 402 (ECS) for gold mine entity
```

Both 406b and 406c can be worked on in parallel after 406a completes.

---

## Alternative: Keep as single issue

If you prefer not to split, the issue is self-contained enough to implement in one pass. The suggested implementation steps in the original issue already provide a natural ordering. The main benefit of splitting is clearer progress tracking and the ability to test/review each piece independently.
