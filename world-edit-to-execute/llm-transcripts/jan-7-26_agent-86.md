# Conversation Summary: agent-a1ac968

Generated on: Tue Dec 30 09:35:05 PM PST 2025

--------------------------------------------------------------------------------

### User Request 1

Explore the resource and currency handling in this codebase:

1. src/runtime/resources.lua - how are resources structured?
2. Any existing token/mark/currency patterns
3. How costs and spending work
4. How resources integrate with ECS components

Focus on understanding the architectural patterns for resource management.

--------------------------------------------------------------------------------

### Assistant Response 1

Excellent! Now I have all the information needed. Let me create a comprehensive
report.

## Comprehensive Resource and Currency Architecture Analysis

Based on my exploration of the codebase, here's the complete picture of how
resources and currencies are handled:

---

## 1. CORE RESOURCE SYSTEM (`src/runtime/resources.lua`)

## Resource Types Structure

The system defines four standard WC3 resources with extensibility for custom
types:

```lua
RESOURCE_TYPES = {
    gold = { max = 999999, default = 0 },
    lumber = { max = 999999, default = 0 },
    food_used = { max = 300, default = 0 },
    food_cap = { max = 300, default = 0 },
}
```

- **Gold & Lumber**: Primary/secondary currencies with hard caps at 999,999
- **Food System**: Separate from gold/lumber - uses two-part model:
  - `food_used`: Current population in use
  - `food_cap`: Maximum capacity from buildings

## Storage Pattern

**Per-Player Storage:**
```lua
local player_resources = {}  -- player_id -> { resource_name -> amount }
```

All resource amounts are stored as integers and automatically clamped to [0,
max]:

```lua
function resources.set(player_id, resource_name, amount)
    local config = RESOURCE_TYPES[resource_name]
    local new_value = math.max(0, math.min(amount, config.max))
    player_resources[player_id][resource_name] = new_value
end
```

## Event System

Resource changes fire events through a unified event dispatcher:

```lua
local event_listeners = {
    resource_changed = {},
    resources_spent = {},
    resources_refunded = {},
    food_supply_changed = {},
    food_used_changed = {},
    upkeep_changed = {},
    harvest_deposited = {},
    gold_mine_depleted = {},
    gold_mine_low = {},
}
```

Events are critical to integration - systems subscribe to changes rather than
polling.

---

## 2. COST AND SPENDING SYSTEM (406b)

## Cost Table Format

Costs use a simple dictionary mapping resource names to amounts:

```lua
local cost = { gold = 100, lumber = 50, food = 2 }
```

**Special handling for food**: When spending food, instead of subtracting from a gold-like pool, it adds to `food_used` (consumption increases, doesn't deplete a resource).

## Atomic Validation and Spending

The system guarantees all-or-nothing transactions:

```lua
function resources.spend(player_id, cost)
    -- First validate ALL resources are available
    local can, missing = resources.can_afford(player_id, cost)
    if not can then
        return false, missing  -- FAIL: return error with missing resource
    end

    -- Only then spend (atomicity guaranteed)
    for resource_name, amount in pairs(cost) do
        if resource_name == "food" then
            resources.add(player_id, "food_used", amount)
        else
            resources.subtract(player_id, resource_name, amount)
        end
    end

    fire_event("resources_spent", player_id, cost)
    return true
end
```

## Cost Utility Functions

Three helper functions for manipulating costs:

```lua
resources.add_costs(cost1, cost2)        -- Sum two cost tables
resources.multiply_cost(cost, multiplier) -- Scale costs (floored)
resources.validate_cost(cost)             -- Type/structure checking
```

## Refund Mechanism

Inverse of spending (used for cancelled orders):

```lua
function resources.refund(player_id, cost)
    -- Exactly inverse of spend logic
    for resource_name, amount in pairs(cost) do
        if resource_name == "food" then
            resources.subtract(player_id, "food_used", amount)
        else
            resources.add(player_id, resource_name, amount)
        end
    end
    fire_event("resources_refunded", player_id, cost)
end
```

---

## 3. FOOD SYSTEM (406c)

## Two-Part Food Tracking

Food in WC3 uses a capacity-based model, not consumption-based:

**Supply Side (from buildings):**
```lua
function resources.add_food_supply(player_id, amount)
    -- Called when: Farm completes (+6), Town Hall (+10), Ziggurat (+10)
    local old_cap = resources.get(player_id, "food_cap")
    resources.add(player_id, "food_cap", amount)
    local new_cap = resources.get(player_id, "food_cap")
    fire_event("food_supply_changed", player_id, old_cap, new_cap)
end
```

**Demand Side (from units):**
```lua
function resources.add_food_used(player_id, amount)
    -- Called when: Unit finishes training, summoned unit appears
    local old_used = resources.get(player_id, "food_used")
    resources.add(player_id, "food_used", amount)
    local new_used = resources.get(player_id, "food_used")
    fire_event("food_used_changed", player_id, old_used, new_used)
    resources._check_upkeep_change(player_id, old_used, new_used)
end
```

## Food Status Query

Single function provides comprehensive food state:

```lua
function resources.get_food_status(player_id)
    return {
        used = 25,
        cap = 100,
        available = 75,           -- cap - used
        is_capped = false,        -- used >= cap
        upkeep_level = "none",    -- "none" | "low" | "high"
    }
end
```

## Upkeep Mechanics

WC3-style upkeep penalty affects gold harvesting rates based on army size:

```lua
local UPKEEP_THRESHOLDS = {
    none = 50,     -- 0-50 food: 100% income
    low = 80,      -- 51-80 food: 70% income
    -- 81+: 40% income (high upkeep)
}

local UPKEEP_RATES = {
    none = 1.0,
    low = 0.7,
    high = 0.4,
}
```

When `food_used` crosses a threshold, `upkeep_changed` event fires to notify
systems that gold income rates have changed.

---

## 4. HARVESTING AND GOLD MINES (406c)

## Worker Harvesting Integration

When workers deposit harvested resources, upkeep penalty is applied to gold
only:

```lua
function resources.deposit_harvest(player_id, resource_name, amount,
apply_upkeep)
    local final_amount = amount

    -- Only gold gets upkeep penalty (not lumber)
    if resource_name == "gold" and apply_upkeep ~= false then
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
```

## Gold Mine Component Integration

Mines are ECS entities with a `gold_mine` component:

```lua
component.register("gold_mine", {
    gold_remaining = 12500,       -- Current capacity
    gold_capacity = 12500,        -- Original (for UI %)
    gold_per_harvest = 10,        -- Per worker trip
    low_warning_threshold = 1000, -- Event threshold
})
```

Depletion is tracked per-mine:

```lua
function resources.deplete_gold_mine(ecs, mine_entity, amount)
    local mine = ecs.get_component(mine_entity, "gold_mine")
    local old_remaining = mine.gold_remaining
    mine.gold_remaining = math.max(0, mine.gold_remaining - amount)

    if mine.gold_remaining <= 0 and old_remaining > 0 then
        fire_event("gold_mine_depleted", mine_entity)
    elseif mine.gold_remaining <= mine.low_warning_threshold then
        fire_event("gold_mine_low", mine_entity, mine.gold_remaining)
    end

    return mine.gold_remaining
end
```

## Gold Mine Status Queries

```lua
function resources.get_mine_status(ecs, mine_entity)
    local mine = ecs.get_component(mine_entity, "gold_mine")
    return {
        remaining = mine.gold_remaining,
        capacity = mine.gold_capacity,
        percent = (mine.gold_remaining / mine.gold_capacity) * 100,
        is_depleted = mine.gold_remaining <= 0,
    }
end
```

---

## 5. PERIODIC INCOME SYSTEM (406c)

For custom maps that need different economy models:

```lua
local player_income = {}  -- player_id -> { resource_name -> per_second }

function resources.set_income_rate(player_id, resource_name, per_second)
    if not player_income[player_id] then
        player_income[player_id] = {}
    end
    player_income[player_id][resource_name] = per_second
end

function resources.process_income(dt)
    -- Called each game tick with delta time
    for player_id, incomes in pairs(player_income) do
        for resource_name, per_second in pairs(incomes) do
            if per_second > 0 then
                local amount = per_second * dt
                -- Accumulate fractions to avoid drift
                local key = player_id .. "_" .. resource_name
                local acc = (income_accumulator[key] or 0) + amount
                local whole = math.floor(acc)

                if whole > 0 then
                    resources.add(player_id, resource_name, whole)
                    income_accumulator[key] = acc - whole
                else
                    income_accumulator[key] = acc
                end
            end
        end
    end
end
```

---

## 6. GUILD/HERO CURRENCY SYSTEM

## Local Economy (Hero Gold)

The Guild system implements a separate economy for hero progression via
`src/guild/hero.lua`:

```lua
local Hero = {}
function Hero.new(name)
    local self = setmetatable({}, Hero)
    self.gold = 0  -- Hero's personal gold (separate from player resources)
    -- ... inventory, equipment, stats, quests, etc.
    return self
end

function Hero:spend_gold(amount)
    if self.gold < amount then
        return false
    end
    self.gold = self.gold - amount
    return true
end
```

## Shop Integration

Shops (`src/guild/shop.lua`) mediate hero transactions:

```lua
function Shop:buy(hero, item_id, quantity)
    local unit_price = self:get_buy_price(item_id, hero)
    local total_price = unit_price * quantity

    if hero.gold < total_price then
        return false, "Insufficient gold"
    end

    hero:spend_gold(total_price)
    hero:add_to_inventory(item)
    return true
end
```

**Price Modifiers:**
- Item-specific overrides: `shop.price_overrides[item_id]`
- Discount system: flat, percentage, or level-based
- Sell price: 50% of buy price for regular items

---

## 7. ECS COMPONENT INTEGRATION

## Components Affected by Resources

**Unit Type Component:**
```lua
component.register("unit_type", {
    food_used = 0,  -- Food cost when trained (e.g., Footman = 2)
    food_made = 0,  -- Food provided (only for farms/halls)
})
```

**Building Component:**
```lua
component.register("building", {
    construction_progress = 1.0,  -- 0-1.0
    under_construction = false,
    queue = {},                   -- Unit types being trained
    queue_progress = 0.0,         -- Progress on current item
})
```

**Owner Component:**
```lua
component.register("owner", {
    player_id = 0,  -- Links entity to player resources
    team = 0,       -- Alliance tracking
})
```

## No Direct Cost Storage in Components

**Key architectural choice**: Costs are NOT stored in components. Instead:
- Costs are defined in **data** (SLK files, configuration)
- Components only store **current state** (health, position, construction progress)
- Systems look up costs from data when needed (e.g., when building/training queued)

---

## 8. ARCHITECTURAL PATTERNS

## Pattern 1: Cost Tables as Values

Costs flow through systems as lightweight tables:

```lua
function train_unit(player_id, unit_type)
    local cost = lookup_unit_cost(unit_type)  -- From data

    if not resources.spend(player_id, cost) then
        return false, "Cannot afford"
    end

    -- Create unit entity...
    resources.add_food_used(player_id, cost.food or 0)
end
```

## Pattern 2: Event-Driven Updates

Systems don't poll; they listen:

```lua
resources.on("resource_changed", function(player_id, resource, old, new)
    -- UI updates, AI decisions, etc.
end)

resources.on("food_supply_changed", function(player_id, old_cap, new_cap)
    -- Check if can now train units
end)
```

## Pattern 3: Separate Levels

Three distinct levels of currency:

1. **WC3 Game Resources** (`resources.lua`): Gold, lumber, food (shared by all
players)
2. **Hero Economy** (`guild/hero.lua`): Hero-specific gold (personal
progression)
3. **Items** (`guild/items.lua`): Individual item costs/values (trading between
heroes)

Each is isolated but can interact (hero gold → item costs → shop trades).

## Pattern 4: Atomic Transactions

All spending operations are all-or-nothing to prevent partial states:

```lua
-- Either ALL resources are spent, or NONE are
local ok, missing = resources.spend(player_id, cost)
-- No partial deductions if one resource fails
```

---

## 9. TEST PATTERNS (`src/tests/test_resources.lua`)

The test suite demonstrates usage:

```lua
resources.init_player(0)
resources.set(0, "gold", 1000)
assert_eq(1000, resources.get(0, "gold"))

-- Cost validation
local cost = { gold = 100, lumber = 50, food = 2 }
assert_true(resources.can_afford(0, cost))

-- Atomic spending
assert_true(resources.spend(0, cost))
assert_eq(900, resources.get(0, "gold"))

-- Refund
resources.refund(0, cost)
assert_eq(1000, resources.get(0, "gold"))

-- Food system
resources.add_food_supply(0, 10)
resources.add_food_used(0, 2)
local status = resources.get_food_status(0)
assert_eq(10, status.cap)
assert_eq(2, status.used)
```

---

## 10. KEY DESIGN DECISIONS

| Pattern | Decision | Reasoning |
|---------|----------|-----------|
| **Resource Clamping** | Automatic [0, max] | Prevents overflow/underflow bugs
|
| **Food Model** | Capacity + Usage | Matches WC3 melee design |
| **Upkeep Penalty** | Gold only, not lumber | Reflects WC3 economy balance |
| **Costs as Values** | Not stored in components | Decouples data from state |
| **Atomic Spending** | All-or-nothing validation | Prevents inconsistent states
|
| **Event-Driven** | Explicit firing, not polling | Allows parallel system
updates |
| **Hero Gold Separate** | Different from player resources | Enables per-hero
economies |
| **Cost Utilities** | add_costs, multiply_cost | Supports dynamic costs
(upgrades, buffs) |

---

## Summary

The resource architecture follows a **three-layered currency model**:

1. **Player Resources Layer** (WC3): Gold, lumber, food (shared account)
2. **Hero Progression Layer** (RPG): Individual hero gold (character economy)
3. **Item Value Layer** (Commerce): Item costs and trading (marketplace)

All are event-driven, support atomic transactions, and integrate with the ECS
for game systems to query and update resource state. The system is extensible
(custom resource types) while maintaining WC3 compatibility.

---

## File Locations

Key implementation files:

- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/runtime/resources.lua` - Core resource system (804 lines)
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/guild/hero.lua` - Hero currency
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/guild/shop.lua` - Shop transactions
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/tests/test_resources.lua` - Test suite
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/issues/406*.md` - Design documents

--------------------------------------------------------------------------------
