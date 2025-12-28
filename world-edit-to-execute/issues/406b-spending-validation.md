# Issue 406b: Spending and Validation

**Phase:** 4 - Runtime
**Type:** Feature
**Priority:** Medium
**Parent:** 406-build-resource-management-system.md
**Dependencies:** 406a-core-resource-storage

---

## Current Behavior

After 406a, basic resource get/set operations exist, but there is no way to validate whether a player can afford a cost, atomically spend resources, or refund cancelled purchases.

---

## Intended Behavior

Implement cost validation and atomic spending operations:
- Check if a player can afford a cost table (gold, lumber, food)
- Spend resources atomically (all-or-nothing)
- Handle food specially (food spending increases food_used, not decreases gold-like resources)
- Refund costs when orders are cancelled
- Return helpful error information when spending fails

**API:**
```lua
-- Check if player can afford a cost
resources.can_afford(player_id, cost) -> boolean, missing_resource

-- Spend resources (atomic - all or nothing)
resources.spend(player_id, cost) -> boolean, missing_resource

-- Refund resources (inverse of spend)
resources.refund(player_id, cost)

-- Cost table format:
-- { gold = 100, lumber = 50, food = 2 }
```

---

## Suggested Implementation Steps

1. **Define cost table structure**
   ```lua
   -- Cost tables map resource names to amounts
   -- Special handling for 'food' key (uses food_used/food_cap)
   --
   -- Example costs:
   -- Footman: { gold = 135, food = 2 }
   -- Farm: { gold = 80, lumber = 20 }
   -- Upgrade: { gold = 200, lumber = 100 }
   ```

2. **Implement can_afford check**
   ```lua
   -- {{{ can_afford
   -- Check if player can afford a cost table
   -- Returns: true if affordable, or false with missing resource name
   function resources.can_afford(player_id, cost)
       if not cost then
           return true
       end

       for resource_name, amount in pairs(cost) do
           if resource_name == "food" then
               -- Food is special: check if food_used + amount <= food_cap
               local used = resources.get(player_id, "food_used")
               local cap = resources.get(player_id, "food_cap")

               if used + amount > cap then
                   return false, "food"
               end
           else
               -- Standard resource: check if current >= amount
               local current = resources.get(player_id, resource_name)

               if current < amount then
                   return false, resource_name
               end
           end
       end

       return true
   end
   -- }}}
   ```

3. **Implement atomic spend**
   ```lua
   -- {{{ spend
   -- Spend resources according to a cost table
   -- This is ATOMIC: either all resources are spent, or none are
   -- Returns: true on success, or false with missing resource name
   function resources.spend(player_id, cost)
       if not cost then
           return true
       end

       -- First, validate we can afford everything
       local can, missing = resources.can_afford(player_id, cost)
       if not can then
           return false, missing
       end

       -- Now spend each resource
       for resource_name, amount in pairs(cost) do
           if resource_name == "food" then
               -- Food spending increases food_used
               resources.add(player_id, "food_used", amount)
           else
               -- Standard resources are subtracted
               resources.subtract(player_id, resource_name, amount)
           end
       end

       -- Fire spending event
       fire_event("resources_spent", player_id, cost)

       return true
   end
   -- }}}
   ```

4. **Implement refund**
   ```lua
   -- {{{ refund
   -- Refund resources from a cancelled order
   -- Inverse of spend: adds back gold/lumber, removes food_used
   function resources.refund(player_id, cost)
       if not cost then
           return
       end

       for resource_name, amount in pairs(cost) do
           if resource_name == "food" then
               -- Food refund decreases food_used
               resources.subtract(player_id, "food_used", amount)
           else
               -- Standard resources are added back
               resources.add(player_id, resource_name, amount)
           end
       end

       -- Fire refund event
       fire_event("resources_refunded", player_id, cost)
   end
   -- }}}
   ```

5. **Add helper for partial spending (optional)**
   ```lua
   -- {{{ spend_partial
   -- Spend as much as possible, return what was actually spent
   -- Useful for harvesters dropping off variable amounts
   function resources.spend_partial(player_id, cost)
       local actually_spent = {}

       for resource_name, amount in pairs(cost) do
           if resource_name == "food" then
               local used = resources.get(player_id, "food_used")
               local cap = resources.get(player_id, "food_cap")
               local available = cap - used
               local spend_amount = math.min(amount, available)

               if spend_amount > 0 then
                   resources.add(player_id, "food_used", spend_amount)
                   actually_spent.food = spend_amount
               end
           else
               local current = resources.get(player_id, resource_name)
               local spend_amount = math.min(amount, current)

               if spend_amount > 0 then
                   resources.subtract(player_id, resource_name, spend_amount)
                   actually_spent[resource_name] = spend_amount
               end
           end
       end

       return actually_spent
   end
   -- }}}
   ```

6. **Add cost validation helper**
   ```lua
   -- {{{ validate_cost
   -- Check if a cost table is well-formed
   -- Returns: true if valid, false with error message
   function resources.validate_cost(cost)
       if type(cost) ~= "table" then
           return false, "Cost must be a table"
       end

       for resource_name, amount in pairs(cost) do
           if type(resource_name) ~= "string" then
               return false, "Resource name must be a string"
           end
           if type(amount) ~= "number" or amount < 0 then
               return false, "Resource amount must be a non-negative number"
           end
       end

       return true
   end
   -- }}}
   ```

7. **Add cost arithmetic helpers**
   ```lua
   -- {{{ add_costs
   -- Combine two cost tables
   function resources.add_costs(cost1, cost2)
       local result = {}

       for name, amount in pairs(cost1 or {}) do
           result[name] = (result[name] or 0) + amount
       end

       for name, amount in pairs(cost2 or {}) do
           result[name] = (result[name] or 0) + amount
       end

       return result
   end
   -- }}}

   -- {{{ multiply_cost
   -- Scale a cost table by a multiplier
   function resources.multiply_cost(cost, multiplier)
       local result = {}

       for name, amount in pairs(cost or {}) do
           result[name] = math.floor(amount * multiplier)
       end

       return result
   end
   -- }}}
   ```

8. **Create unit tests**
   ```lua
   -- src/tests/test_resources_spending.lua

   -- Test can_afford returns true when affordable
   -- Test can_afford returns false when gold insufficient
   -- Test can_afford returns false when lumber insufficient
   -- Test can_afford returns false when food cap exceeded
   -- Test can_afford with empty cost returns true

   -- Test spend subtracts gold
   -- Test spend subtracts lumber
   -- Test spend increases food_used (not subtracts)
   -- Test spend fails atomically (nothing spent if can't afford)
   -- Test spend fires resources_spent event

   -- Test refund adds back gold
   -- Test refund adds back lumber
   -- Test refund decreases food_used
   -- Test refund fires resources_refunded event

   -- Test add_costs combines two costs
   -- Test multiply_cost scales correctly
   ```

---

## Related Documents

- issues/406-build-resource-management-system.md (parent issue)
- issues/406a-core-resource-storage.md (prerequisite - provides get/set)
- issues/406c-food-and-harvesting.md (sibling)
- issues/408-implement-training-queue.md (future - uses spend/refund)

---

## Acceptance Criteria

- [x] `can_afford()` correctly checks gold sufficiency
- [x] `can_afford()` correctly checks lumber sufficiency
- [x] `can_afford()` correctly checks food capacity (used + cost <= cap)
- [x] `can_afford()` returns missing resource name on failure
- [x] `spend()` subtracts gold/lumber correctly
- [x] `spend()` increases food_used (not subtracts)
- [x] `spend()` is atomic (nothing spent if can't afford)
- [x] `spend()` fires `resources_spent` event
- [x] `refund()` adds back gold/lumber
- [x] `refund()` decreases food_used
- [x] `refund()` fires `resources_refunded` event
- [x] Cost arithmetic helpers work correctly
- [x] Unit tests pass for all spending operations

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Added spending functions to src/runtime/resources.lua:**
   - `can_afford(player_id, cost)` - validates affordability
   - `spend(player_id, cost)` - atomic spending
   - `refund(player_id, cost)` - inverse of spend

2. **Food handling:**
   - Food in cost tables represents population cost
   - Spending food INCREASES food_used (not decreases)
   - Refunding food DECREASES food_used
   - Food check: used + cost <= cap

3. **Cost helpers:**
   - `validate_cost(cost)` - checks table structure
   - `add_costs(cost1, cost2)` - combine cost tables
   - `multiply_cost(cost, multiplier)` - scale with floor

4. **Events added:**
   - `resources_spent` (player_id, cost)
   - `resources_refunded` (player_id, cost)

### Test Coverage

Added 25 new tests to test_resources.lua (now 62 total):
- Can afford tests (6)
- Spend tests (6)
- Refund tests (5)
- Cost validation tests (4)
- Cost arithmetic tests (4)

---

## Notes

**Food handling:**
- Food works differently from gold/lumber
- `food` in a cost table represents population cost
- Spending food INCREASES `food_used` (not decreases a "food" resource)
- Refunding food DECREASES `food_used`
- This matches WC3 behavior where units consume population

**Atomicity:**
- `spend()` must be all-or-nothing
- If any resource is insufficient, nothing is spent
- This prevents partial purchases (e.g., gold spent but not enough food)

**Common costs (WC3 Human):**
```lua
-- Units
footman = { gold = 135, food = 2 }
rifleman = { gold = 205, lumber = 30, food = 3 }
knight = { gold = 245, lumber = 60, food = 4 }
peasant = { gold = 75, food = 1 }

-- Buildings
farm = { gold = 80, lumber = 20 }
barracks = { gold = 160, lumber = 60 }
```

**Error messages:**
- UI can use the missing resource name to show appropriate error
- "Not enough gold" vs "Not enough food" etc.
- Consider localization needs when displaying to user
