# Issue 406c: Food Supply and Harvesting Integration

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 406-build-resource-management-system.md
**Dependencies:** 406a-core-resource-storage, 402-build-entity-component-system

---

## Current Behavior

After 406a and 406b, basic resource storage and spending work, but there is no integration with:
- Buildings that provide food supply (farms, town halls)
- Units that consume food when trained/killed
- Workers depositing harvested resources
- Gold mines with limited capacity

---

## Intended Behavior

Implement food supply management and harvesting integration:
- Track food supply from buildings (farm built → food_cap increases)
- Track food consumption from units (unit trained → food_used increases)
- Handle harvesting deposits (worker returns gold/lumber)
- Track gold mine depletion
- Support optional periodic income for custom maps

**API:**
```lua
-- Food supply (from buildings)
resources.add_food_supply(player_id, amount)
resources.remove_food_supply(player_id, amount)

-- Food consumption (from units)
resources.add_food_used(player_id, amount)
resources.remove_food_used(player_id, amount)

-- Food status
resources.get_food_status(player_id) -> { used, cap, available }

-- Harvesting
resources.deposit_harvest(player_id, resource_name, amount)
resources.deplete_gold_mine(mine_entity, amount) -> remaining

-- Optional: periodic income
resources.set_income_rate(player_id, resource_name, per_second)
resources.process_income(dt)
```

---

## Suggested Implementation Steps

1. **Implement food supply management**
   ```lua
   -- {{{ add_food_supply
   -- Called when food-providing buildings complete construction
   -- Examples: Farm (+6), Town Hall (+10), Ziggurat (+10 with upgrade)
   function resources.add_food_supply(player_id, amount)
       local old_cap = resources.get(player_id, "food_cap")
       resources.add(player_id, "food_cap", amount)
       local new_cap = resources.get(player_id, "food_cap")

       fire_event("food_supply_changed", player_id, old_cap, new_cap)
   end
   -- }}}

   -- {{{ remove_food_supply
   -- Called when food-providing buildings are destroyed
   function resources.remove_food_supply(player_id, amount)
       local old_cap = resources.get(player_id, "food_cap")
       resources.subtract(player_id, "food_cap", amount)
       local new_cap = resources.get(player_id, "food_cap")

       fire_event("food_supply_changed", player_id, old_cap, new_cap)

       -- Note: food_used can now exceed food_cap
       -- This is intentional - units don't die when farms are destroyed
       -- But player can't train new units until balance is restored
   end
   -- }}}
   ```

2. **Implement food consumption tracking**
   ```lua
   -- {{{ add_food_used
   -- Called when units complete training or are summoned
   function resources.add_food_used(player_id, amount)
       local old_used = resources.get(player_id, "food_used")
       resources.add(player_id, "food_used", amount)
       local new_used = resources.get(player_id, "food_used")

       fire_event("food_used_changed", player_id, old_used, new_used)

       -- Check for upkeep level changes
       resources._check_upkeep_change(player_id, old_used, new_used)
   end
   -- }}}

   -- {{{ remove_food_used
   -- Called when units die or are removed
   function resources.remove_food_used(player_id, amount)
       local old_used = resources.get(player_id, "food_used")
       resources.subtract(player_id, "food_used", amount)
       local new_used = resources.get(player_id, "food_used")

       fire_event("food_used_changed", player_id, old_used, new_used)

       -- Check for upkeep level changes
       resources._check_upkeep_change(player_id, old_used, new_used)
   end
   -- }}}
   ```

3. **Implement food status helper**
   ```lua
   -- {{{ get_food_status
   -- Get comprehensive food information for a player
   function resources.get_food_status(player_id)
       local used = resources.get(player_id, "food_used")
       local cap = resources.get(player_id, "food_cap")

       return {
           used = used,
           cap = cap,
           available = cap - used,
           is_capped = used >= cap,
           upkeep_level = resources.get_upkeep_level(used),
       }
   end
   -- }}}
   ```

4. **Implement upkeep level tracking**
   ```lua
   -- {{{ Upkeep levels (WC3 melee rules)
   -- Affects gold income rate from harvesting
   local UPKEEP_THRESHOLDS = {
       none = 50,    -- 0-50 food: 100% gold income
       low = 80,     -- 51-80 food: 70% gold income
       -- Above 80: 40% gold income (high upkeep)
   }

   local UPKEEP_RATES = {
       none = 1.0,
       low = 0.7,
       high = 0.4,
   }

   function resources.get_upkeep_level(food_used)
       if food_used <= UPKEEP_THRESHOLDS.none then
           return "none"
       elseif food_used <= UPKEEP_THRESHOLDS.low then
           return "low"
       else
           return "high"
       end
   end

   function resources.get_upkeep_rate(player_id)
       local used = resources.get(player_id, "food_used")
       local level = resources.get_upkeep_level(used)
       return UPKEEP_RATES[level]
   end

   function resources._check_upkeep_change(player_id, old_used, new_used)
       local old_level = resources.get_upkeep_level(old_used)
       local new_level = resources.get_upkeep_level(new_used)

       if old_level ~= new_level then
           fire_event("upkeep_changed", player_id, old_level, new_level)
       end
   end
   -- }}}
   ```

5. **Implement harvest deposit**
   ```lua
   -- {{{ deposit_harvest
   -- Called when a worker returns resources to a town hall/goldmine
   -- Applies upkeep modifier to gold
   function resources.deposit_harvest(player_id, resource_name, amount, apply_upkeep)
       if apply_upkeep == nil then
           apply_upkeep = true
       end

       local final_amount = amount

       -- Apply upkeep penalty to gold
       if resource_name == "gold" and apply_upkeep then
           local rate = resources.get_upkeep_rate(player_id)
           final_amount = math.floor(amount * rate)
       end

       resources.add(player_id, resource_name, final_amount)

       fire_event("harvest_deposited", {
           player_id = player_id,
           resource = resource_name,
           amount = final_amount,
           original_amount = amount,
           upkeep_applied = apply_upkeep and resource_name == "gold",
       })

       return final_amount
   end
   -- }}}
   ```

6. **Implement gold mine depletion**
   ```lua
   -- {{{ deplete_gold_mine
   -- Reduce gold remaining in a mine
   -- mine_entity: ECS entity with gold_mine component
   -- amount: gold extracted this harvest (before upkeep)
   function resources.deplete_gold_mine(ecs, mine_entity, amount)
       local mine = ecs.get_component(mine_entity, "gold_mine")
       if not mine then
           return 0, "Entity has no gold_mine component"
       end

       local old_remaining = mine.gold_remaining
       mine.gold_remaining = math.max(0, mine.gold_remaining - amount)

       if mine.gold_remaining <= 0 and old_remaining > 0 then
           fire_event("gold_mine_depleted", mine_entity)
       elseif mine.gold_remaining <= mine.low_warning_threshold then
           -- Fire low gold warning (optional)
           fire_event("gold_mine_low", mine_entity, mine.gold_remaining)
       end

       return mine.gold_remaining
   end
   -- }}}

   -- {{{ get_mine_status
   function resources.get_mine_status(ecs, mine_entity)
       local mine = ecs.get_component(mine_entity, "gold_mine")
       if not mine then
           return nil
       end

       return {
           remaining = mine.gold_remaining,
           capacity = mine.gold_capacity,
           percent = mine.gold_remaining / mine.gold_capacity * 100,
           is_depleted = mine.gold_remaining <= 0,
       }
   end
   -- }}}
   ```

7. **Implement periodic income (optional)**
   ```lua
   -- {{{ Income system for custom maps
   local player_income = {}  -- player_id -> { resource_name -> per_second }

   function resources.set_income_rate(player_id, resource_name, per_second)
       if not player_income[player_id] then
           player_income[player_id] = {}
       end
       player_income[player_id][resource_name] = per_second
   end

   function resources.get_income_rate(player_id, resource_name)
       if not player_income[player_id] then
           return 0
       end
       return player_income[player_id][resource_name] or 0
   end

   -- Called each game tick with delta time
   function resources.process_income(dt)
       for player_id, incomes in pairs(player_income) do
           for resource_name, per_second in pairs(incomes) do
               local amount = per_second * dt
               -- Accumulate fractional amounts
               resources._income_accumulator = resources._income_accumulator or {}
               local key = player_id .. "_" .. resource_name
               local acc = (resources._income_accumulator[key] or 0) + amount
               local whole = math.floor(acc)

               if whole > 0 then
                   resources.add(player_id, resource_name, whole)
                   resources._income_accumulator[key] = acc - whole
               else
                   resources._income_accumulator[key] = acc
               end
           end
       end
   end
   -- }}}
   ```

8. **Register gold_mine component with ECS**
   ```lua
   -- In ECS setup or data initialization
   ecs.register_component("gold_mine", {
       gold_remaining = 12500,      -- Default WC3 gold mine capacity
       gold_capacity = 12500,       -- Original capacity (for UI percentage)
       gold_per_harvest = 10,       -- Gold per worker trip
       low_warning_threshold = 1000, -- Fire warning event below this
   })
   ```

9. **Create unit tests**
   ```lua
   -- src/tests/test_resources_food_harvest.lua

   -- Food supply tests:
   -- Test add_food_supply increases food_cap
   -- Test remove_food_supply decreases food_cap
   -- Test food_supply_changed event fires

   -- Food consumption tests:
   -- Test add_food_used increases food_used
   -- Test remove_food_used decreases food_used
   -- Test get_food_status returns correct values

   -- Upkeep tests:
   -- Test upkeep is "none" at 50 food
   -- Test upkeep is "low" at 51-80 food
   -- Test upkeep is "high" at 81+ food
   -- Test upkeep_changed event fires on threshold crossing

   -- Harvesting tests:
   -- Test deposit_harvest adds resources
   -- Test deposit_harvest applies upkeep to gold
   -- Test deplete_gold_mine reduces remaining gold
   -- Test gold_mine_depleted event fires when empty

   -- Income tests:
   -- Test set_income_rate configures income
   -- Test process_income adds resources over time
   ```

---

## Related Documents

- issues/406-build-resource-management-system.md (parent issue)
- issues/406a-core-resource-storage.md (prerequisite)
- issues/406b-spending-validation.md (sibling)
- issues/402-build-entity-component-system.md (gold_mine component)
- issues/409-implement-worker-ai.md (future - uses deposit_harvest)

---

## Acceptance Criteria

- [x] `add_food_supply()` increases food_cap
- [x] `remove_food_supply()` decreases food_cap
- [x] `add_food_used()` increases food_used
- [x] `remove_food_used()` decreases food_used
- [x] `get_food_status()` returns used, cap, available
- [x] Upkeep levels calculated correctly (none/low/high)
- [x] Upkeep change events fire on threshold crossing
- [x] `deposit_harvest()` adds resources to player
- [x] `deposit_harvest()` applies upkeep rate to gold
- [x] `deplete_gold_mine()` reduces mine capacity
- [x] `gold_mine_depleted` event fires when mine empties
- [x] Income rate system works for custom maps
- [x] Unit tests pass for all food/harvest operations

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Added food supply functions to src/runtime/resources.lua:**
   - `add_food_supply(player_id, amount)` - increases food_cap
   - `remove_food_supply(player_id, amount)` - decreases food_cap
   - Both fire `food_supply_changed` event

2. **Added food consumption functions:**
   - `add_food_used(player_id, amount)` - increases food_used, checks upkeep
   - `remove_food_used(player_id, amount)` - decreases food_used, checks upkeep
   - Both fire `food_used_changed` event
   - Automatically call `_check_upkeep_change()` to fire `upkeep_changed` when thresholds crossed

3. **Food status query:**
   - `get_food_status(player_id)` returns { used, cap, available, is_capped, upkeep_level }

4. **Upkeep system:**
   - `UPKEEP_THRESHOLDS` = { none = 50, low = 80 }
   - `UPKEEP_RATES` = { none = 1.0, low = 0.7, high = 0.4 }
   - `get_upkeep_level(food_used)` - returns "none", "low", or "high"
   - `get_upkeep_rate(player_id)` - returns rate multiplier based on current food_used
   - `_check_upkeep_change(player_id, old_used, new_used)` - fires event on threshold crossing

5. **Harvesting:**
   - `deposit_harvest(player_id, resource_name, amount, apply_upkeep)` - adds resources with optional upkeep penalty
   - Applies upkeep rate to gold by default (floor'd)
   - Fires `harvest_deposited` event with full details

6. **Gold mine integration:**
   - `deplete_gold_mine(ecs, mine_entity, amount)` - reduces gold_remaining in mine component
   - Fires `gold_mine_depleted` when remaining hits 0
   - Fires `gold_mine_low` when below low_warning_threshold
   - `get_mine_status(ecs, mine_entity)` - returns { remaining, capacity, percent, is_depleted }

7. **Periodic income:**
   - `set_income_rate(player_id, resource_name, per_second)` - configure income
   - `get_income_rate(player_id, resource_name)` - query rate
   - `process_income(dt)` - process all player incomes with fractional accumulation
   - `clear_income()` - reset all income data

8. **Events added:**
   - `food_supply_changed` (player_id, old_cap, new_cap)
   - `food_used_changed` (player_id, old_used, new_used)
   - `upkeep_changed` (player_id, old_level, new_level)
   - `harvest_deposited` (event_data table)
   - `gold_mine_depleted` (mine_entity)
   - `gold_mine_low` (mine_entity, remaining)

### Test Coverage

Added 27 new tests to test_resources.lua (89 total):
- Food supply tests (8)
- Upkeep tests (5)
- Harvesting tests (5)
- Gold mine tests (4)
- Income tests (5)

---

## Notes

**Food overflow:**
- When food-providing buildings are destroyed, food_cap decreases
- food_used can temporarily exceed food_cap
- Player cannot train new units until food_used <= food_cap
- Existing units are NOT killed when over food cap

**Upkeep mechanics:**
- Upkeep only affects gold from mines, not lumber
- Upkeep is a WC3 melee feature, can be disabled for custom maps
- Some maps have alternative economy systems

**Gold mine values (WC3):**
- Standard mine: 12,500 gold
- High value mine: 25,000+ gold (map-specific)
- Gold per worker trip: 10 (5 workers mining = 50 gold per return cycle)

**Harvest timing:**
- Workers harvest every ~5 seconds
- Multiple workers can harvest same mine
- When mine depletes, all attached workers need to find new mine

**Integration points:**
- Building system calls `add_food_supply()` on farm completion
- Building system calls `remove_food_supply()` on farm destruction
- Training system calls `add_food_used()` on unit creation
- Combat system calls `remove_food_used()` on unit death
- Worker AI calls `deposit_harvest()` and `deplete_gold_mine()`
