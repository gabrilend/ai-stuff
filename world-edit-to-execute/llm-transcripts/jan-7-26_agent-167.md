# Conversation Summary: agent-a7957b7

Generated on: Tue Dec 30 09:35:13 PM PST 2025

--------------------------------------------------------------------------------

### User Request 1

Design a unified currency/resource system for this WC3-to-WoW engine with these
requirements:

**Context from codebase exploration:**
- Current: src/runtime/resources.lua handles WC3 resources (gold, lumber, food) with per-player storage
- Guild system: src/guild/ has hero inventory, items, shops
- ECS: Full entity-component system in src/runtime/ecs/
- Attribute system: Issues 016a-016i define dispatch-table based attribute getters/setters

**User Requirements:**
1. **Unified System**: Merge "resources" and "currencies" into one architecture
2. **Classic/Vanilla WoW baseline** for currency model
3. **Money as Bag Items**: Copper/silver/gold stored in dedicated inventory
slots (not abstract counters)
4. **Vendor Transactions**: Selling = item transfer to vendor → coins returned
to seller
5. **All Currency Categories**:
   - Money (copper/silver/gold coins as inventory items)
   - Honor (PvP, with Vanilla rank system)
   - Marks (WSG, AB, AV tokens)
   - Reputation (per-faction standing: Hated→Exalted)
   - Profession skill points (dynamic adjustment on failure - mod idea)
   - Arena points (TBC+, but include for completeness)
   - Justice/Valor points (for extensibility)
   - Custom currencies (user-definable)

**Cross-play requirement:**
- WC3 gold should be convertible to WoW copper (or vice versa)
- Unified API for spending, earning, displaying currencies

**Design deliverables:**
1. Currency type taxonomy (categories, behaviors, storage models)
2. Data structures for each currency type
3. Integration with existing ECS and inventory systems
4. Vendor transaction flow
5. API design for unified access
6. How to preserve WC3 compatibility while enabling WoW features

Consider dispatch tables for currency getters/setters (following issue 016
patterns).

--------------------------------------------------------------------------------

### Assistant Response 1

Now I have comprehensive context. Let me design the unified currency system.

---

# Unified Currency/Resource System Design

## Executive Summary

This design unifies WC3 resources and WoW currencies into a single architecture
that:
1. Treats money as physical inventory items (copper/silver/gold coins)
2. Supports abstract currencies (honor, marks, reputation, skill points)
3. Enables cross-play between WC3 gold and WoW copper
4. Uses dispatch tables following the Issue 016 patterns
5. Integrates with existing ECS, inventory, and shop systems

---

## Part 1: Currency Type Taxonomy

## Category A: Physical Currencies (Bag Items)

These are actual item entities that occupy inventory slots.

| Currency | Storage Model | Stacking | Transfer Mechanism |
|----------|---------------|----------|-------------------|
| Copper Coin | Item in dedicated bag slots | 9999/stack | Drop, trade, mail |
| Silver Coin | Item in dedicated bag slots | 9999/stack | Drop, trade, mail |
| Gold Coin | Item in dedicated bag slots | 9999/stack | Drop, trade, mail |
| WC3 Gold | Convertible to coins when "owned" by character | N/A | Via
conversion system |

**Key Insight:** WoW uses 100 copper = 1 silver, 100 silver = 1 gold. The total value is stored abstractly but the physical representation is coins in a "money bag."

## Category B: Abstract Currencies (Per-Character Counters)

These are stored as numeric values, not physical items.

| Currency | Cap | Decay | Scope | Storage |
|----------|-----|-------|-------|---------|
| Honor | Weekly cap + lifetime | Weekly decay (Vanilla) | Character | ECS
component |
| Contribution Points | Weekly cap | Weekly reset | Character | ECS component |
| Arena Points | Weekly cap | None | Team (TBC+) | Team registry |
| Justice Points | Cap (4000) | None | Account-wide | Account storage |
| Valor Points | Weekly cap | None | Account-wide | Account storage |

## Category C: Token Currencies (Bag Items with Abstraction)

Physical tokens that represent abstract value.

| Token | Source | Use | Stacking |
|-------|--------|-----|----------|
| Warsong Gulch Mark | WSG win/loss | Honor gear vendor | 20/stack |
| Arathi Basin Mark | AB win/loss | Honor gear vendor | 20/stack |
| Alterac Valley Mark | AV win/loss | Honor gear vendor | 20/stack |

## Category D: Reputation (Per-Faction Standing)

| Faction | Min | Max | Thresholds |
|---------|-----|-----|------------|
| Any faction | -42000 (Hated) | 42999 (Exalted) |
Hated/Hostile/Unfriendly/Neutral/Friendly/Honored/Revered/Exalted |

## Category E: Skill Points (Per-Profession)

| Type | Range | Behavior |
|------|-------|----------|
| Profession Skill | 1-300 (Vanilla), 1-525 (later) | Can decrease on fail (mod
idea) |
| Weapon Skill | 1-300 | Increases through use |
| Defense Skill | 1-300 | Increases through combat |

## Category F: WC3 Resources (Player-Level)

| Resource | Max | Scope |
|----------|-----|-------|
| Gold | 999999 | Per-player (RTS) |
| Lumber | 999999 | Per-player (RTS) |
| Food Used | 300 | Per-player |
| Food Cap | 300 | Per-player |

---

## Part 2: Data Structures

## 2.1 Currency Registry (Dispatch Table Pattern)

Following Issue 016b patterns:

```lua
-- src/runtime/currency/registry.lua

local CURRENCY_CATEGORY = {
    PHYSICAL = 1,      -- Coins in bags
    ABSTRACT = 2,      -- Pure counters
    TOKEN = 3,         -- Physical tokens
    REPUTATION = 4,    -- Faction standings
    SKILL = 5,         -- Profession/weapon skills
    WC3_RESOURCE = 6,  -- Classic WC3 per-player resources
}

local CURRENCY_SCHEMA = {
    -- Physical money (WoW)
    copper = {
        index = 1,
        category = CURRENCY_CATEGORY.PHYSICAL,
        item_id = "currency_copper",
        stack_max = 9999,
        conversion = nil,  -- Base unit
        display_name = "Copper",
        icon = "inv_misc_coin_01",
    },
    silver = {
        index = 2,
        category = CURRENCY_CATEGORY.PHYSICAL,
        item_id = "currency_silver",
        stack_max = 9999,
        conversion = { to = "copper", rate = 100 },
        display_name = "Silver",
        icon = "inv_misc_coin_03",
    },
    gold = {
        index = 3,
        category = CURRENCY_CATEGORY.PHYSICAL,
        item_id = "currency_gold",
        stack_max = 9999,
        conversion = { to = "silver", rate = 100 },
        display_name = "Gold",
        icon = "inv_misc_coin_07",
    },

    -- Abstract currencies
    honor = {
        index = 10,
        category = CURRENCY_CATEGORY.ABSTRACT,
        cap = 75000,
        weekly_cap = 5000,
        decay_rate = 0.25,  -- 25% weekly decay in Vanilla
        display_name = "Honor",
        icon = "inv_misc_token_pvp",
    },
    arena_points = {
        index = 11,
        category = CURRENCY_CATEGORY.ABSTRACT,
        cap = 10000,
        weekly_cap = 5000,
        decay_rate = 0,
        display_name = "Arena Points",
        icon = "inv_misc_token_arena",
    },
    justice_points = {
        index = 12,
        category = CURRENCY_CATEGORY.ABSTRACT,
        cap = 4000,
        weekly_cap = nil,  -- No weekly cap
        decay_rate = 0,
        scope = "account",  -- Account-wide
        display_name = "Justice Points",
    },

    -- WC3 resources (per-player, not per-character)
    wc3_gold = {
        index = 100,
        category = CURRENCY_CATEGORY.WC3_RESOURCE,
        cap = 999999,
        player_scope = true,  -- Attached to player slot, not character
        display_name = "Gold",
        icon = "goldcoin",
        -- Conversion to WoW copper
        wow_conversion = { to = "copper", rate = 100 },  -- 1 WC3 gold = 100
copper
    },
    wc3_lumber = {
        index = 101,
        category = CURRENCY_CATEGORY.WC3_RESOURCE,
        cap = 999999,
        player_scope = true,
        display_name = "Lumber",
        icon = "lumber",
    },
}
```

## 2.2 Money Bag Component (Physical Currency Storage)

```lua
-- New ECS component for money storage
ecs.register_component("money_bag", {
    -- Dedicated slots for coins (separate from main inventory)
    slots = {
        copper = { item_id = nil, quantity = 0 },
        silver = { item_id = nil, quantity = 0 },
        gold = { item_id = nil, quantity = 0 },
    },

    -- Total value in copper (cached for quick comparisons)
    total_copper = 0,

    -- Dirty flag for recalculation
    dirty = true,
})
```

## 2.3 Currency Container Component (Abstract Currencies)

```lua
-- ECS component for abstract currency storage
ecs.register_component("currency_container", {
    -- Array-indexed storage (following Issue 016 pattern)
    values = {},      -- currency_index -> amount
    caps = {},        -- currency_index -> current cap (can be modified)
    weekly = {},      -- currency_index -> amount earned this week
    last_reset = 0,   -- Timestamp of last weekly reset

    -- Modifiers (equipment/buffs can modify caps/rates)
    modifiers = {},   -- currency_index -> { source, modifier_type, value }
})
```

## 2.4 Reputation Component

```lua
ecs.register_component("reputation", {
    -- Faction ID -> standing value
    standings = {},  -- faction_id -> integer (-42000 to 42999)

    -- Watched faction (shown on XP bar)
    watched_faction = nil,

    -- Reputation gains/losses pending (for batching)
    pending = {},
})

-- Standing thresholds (Vanilla WoW)
local STANDING_THRESHOLDS = {
    { name = "Hated",      min = -42000, max = -6000 },
    { name = "Hostile",    min = -6000,  max = -3000 },
    { name = "Unfriendly", min = -3000,  max = 0 },
    { name = "Neutral",    min = 0,      max = 3000 },
    { name = "Friendly",   min = 3000,   max = 9000 },
    { name = "Honored",    min = 9000,   max = 21000 },
    { name = "Revered",    min = 21000,  max = 42000 },
    { name = "Exalted",    min = 42000,  max = 42999 },
}
```

## 2.5 Profession Skill Component

```lua
ecs.register_component("profession_skills", {
    -- Profession ID -> skill data
    skills = {},  -- profession_id -> { current = N, max = N, failures = N }

    -- Mod feature: skill can decrease on failure
    failure_tracking = true,
    failure_decay_rate = 0.1,  -- Lose 0.1 skill per failure at cap

    -- Active professions (max 2 primary)
    primary = { nil, nil },
    secondary = {},  -- fishing, cooking, first_aid, archaeology
})
```

## 2.6 PvP Honor Component (Vanilla Rank System)

```lua
ecs.register_component("pvp_honor", {
    -- Lifetime stats
    lifetime_honorable_kills = 0,
    lifetime_honor = 0,

    -- This week
    weekly_honor = 0,
    weekly_contribution = 0,
    weekly_kills = {},  -- { player_id = count } for diminishing returns

    -- Rank
    rank = 0,           -- 0-14 (Private to Grand Marshal / Scout to High
Warlord)
    rank_progress = 0,  -- 0-100% to next rank

    -- Decay tracking
    last_decay = 0,

    -- Marks in bags (token references)
    -- Actual items are in inventory; this is for quick queries
    marks = {
        wsg = 0,
        ab = 0,
        av = 0,
    },
})
```

---

## Part 3: Integration with Existing Systems

## 3.1 ECS Integration

The currency system integrates via new components attached to entities:

```
[Character Entity]
    |
    +-- money_bag (physical coins)
    +-- currency_container (honor, arena points, etc.)
    +-- reputation (faction standings)
    +-- profession_skills (gathering, crafting)
    +-- pvp_honor (rank system)
    +-- inventory (existing - for mark tokens)
```

For WC3 resources (per-player, not per-character):
```
[Player State]  (from resources.lua - Issue 406)
    |
    +-- gold, lumber, food_used, food_cap
```

## 3.2 Inventory Integration

Physical currencies and tokens use the existing inventory system:

```lua
-- Money bag is a virtual "bag" with 3 dedicated slots
-- It does NOT consume regular inventory space

-- When coins are looted:
function loot_money(entity, copper_amount)
    local money_bag = ecs.get_component(entity, "money_bag")
    currency.add_physical(money_bag, "copper", copper_amount)
end

-- Tokens go in regular inventory
function loot_mark(entity, mark_type)
    local item = ItemRegistry.get("mark_" .. mark_type)
    inventory.add_item(entity, item)
end
```

## 3.3 Shop/Vendor Integration

The shop system from `src/guild/shop.lua` needs extension:

```lua
-- Vendor transaction flow:
-- 1. Player initiates sell
-- 2. Item transferred to vendor's hidden inventory
-- 3. Vendor pays player in coins (physical items)
-- 4. Coins go to player's money_bag

function vendor.sell_item(player, vendor, item, slot)
    -- Validate item is sellable
    if item.soulbound or item.quest_item then
        return false, "Cannot sell"
    end

    -- Calculate price
    local sell_price = vendor:get_sell_price(item)

    -- Remove from player inventory
    inventory.remove_item(player, slot)

    -- Add coins to player money bag
    local money_bag = ecs.get_component(player, "money_bag")
    currency.add_physical(money_bag, "copper", sell_price)

    -- Fire event
    events.fire("ITEM_SOLD", player, vendor, item, sell_price)

    return true
end
```

---

## Part 4: Vendor Transaction Flow

## 4.1 Complete Transaction Lifecycle

```
SELLING:
[Player Inventory]              [Vendor]                 [Player Money Bag]
      |                            |                           |
      | ---(1) item transfer--->   |                           |
      |                            | ---(2) coin creation--->  |
      |                            |                           |
      |(item removed)              |(item added to pool)       |(coins added)


BUYING:
[Player Money Bag]              [Vendor]                 [Player Inventory]
      |                            |                           |
      | ---(1) coin removal--->    |                           |
      |                            | ---(2) item transfer--->  |
      |                            |                           |
      |(coins removed)             |(item from pool)           |(item added)
```

## 4.2 Money Bag Operations

```lua
-- src/runtime/currency/money_bag.lua

local money_bag = {}

-- {{{ Dispatch table for physical currency operations
local COIN_VALUES = {
    copper = 1,
    silver = 100,
    gold = 10000,
}

local COIN_ORDER = { "gold", "silver", "copper" }  -- For display
-- }}}

-- {{{ add_copper
-- Add copper value, auto-converting to higher denominations
function money_bag.add_copper(bag, amount)
    local total = bag.total_copper + amount
    money_bag.set_total(bag, total)
end
-- }}}

-- {{{ remove_copper
-- Remove copper value, returns false if insufficient
function money_bag.remove_copper(bag, amount)
    if bag.total_copper < amount then
        return false, "Insufficient funds"
    end
    money_bag.set_total(bag, bag.total_copper - amount)
    return true
end
-- }}}

-- {{{ set_total
-- Set total copper and update coin slots
function money_bag.set_total(bag, total_copper)
    total_copper = math.max(0, total_copper)
    bag.total_copper = total_copper

    -- Distribute into denominations (greedy, highest first)
    local remaining = total_copper
    bag.slots.gold.quantity = math.floor(remaining / 10000)
    remaining = remaining % 10000
    bag.slots.silver.quantity = math.floor(remaining / 100)
    remaining = remaining % 100
    bag.slots.copper.quantity = remaining

    bag.dirty = false
end
-- }}}

-- {{{ can_afford
function money_bag.can_afford(bag, copper_amount)
    return bag.total_copper >= copper_amount
end
-- }}}

-- {{{ format_money
-- Format as "1g 23s 45c"
function money_bag.format_money(copper_amount)
    local gold = math.floor(copper_amount / 10000)
    local silver = math.floor((copper_amount % 10000) / 100)
    local copper = copper_amount % 100

    local parts = {}
    if gold > 0 then table.insert(parts, gold .. "g") end
    if silver > 0 then table.insert(parts, silver .. "s") end
    if copper > 0 or #parts == 0 then table.insert(parts, copper .. "c") end

    return table.concat(parts, " ")
end
-- }}}
```

---

## Part 5: API Design (Unified Access)

## 5.1 Core Currency API

```lua
-- src/runtime/currency/init.lua

local currency = {}

-- {{{ Dispatch tables
local GETTERS = {}
local SETTERS = {}
local ADDERS = {}

-- Build from registry on load
local function build_dispatch_tables()
    for id, schema in pairs(CURRENCY_SCHEMA) do
        local cat = schema.category

        if cat == CURRENCY_CATEGORY.PHYSICAL then
            GETTERS[id] = function(entity)
                local bag = ecs.get_component(entity, "money_bag")
                return bag and bag.slots[id].quantity or 0
            end
            SETTERS[id] = function(entity, amount)
                local bag = ecs.get_component(entity, "money_bag")
                if bag then money_bag.set_coin(bag, id, amount) end
            end

        elseif cat == CURRENCY_CATEGORY.ABSTRACT then
            GETTERS[id] = function(entity)
                local container = ecs.get_component(entity,
"currency_container")
                return container and container.values[schema.index] or 0
            end
            SETTERS[id] = function(entity, amount)
                local container = ecs.get_component(entity,
"currency_container")
                if container then
                    local cap = schema.cap
                    container.values[schema.index] = math.min(amount, cap)
                end
            end

        elseif cat == CURRENCY_CATEGORY.REPUTATION then
            GETTERS[id] = function(entity, faction_id)
                local rep = ecs.get_component(entity, "reputation")
                return rep and rep.standings[faction_id] or 0
            end
            SETTERS[id] = function(entity, faction_id, amount)
                local rep = ecs.get_component(entity, "reputation")
                if rep then
                    rep.standings[faction_id] = clamp(amount, -42000, 42999)
                end
            end

        elseif cat == CURRENCY_CATEGORY.WC3_RESOURCE then
            -- Redirect to existing resources.lua system
            GETTERS[id] = function(player_id)
                local res_name = id:gsub("wc3_", "")  -- wc3_gold -> gold
                return resources.get(player_id, res_name)
            end
            SETTERS[id] = function(player_id, amount)
                local res_name = id:gsub("wc3_", "")
                return resources.set(player_id, res_name, amount)
            end
        end

        -- Index by numeric key too
        GETTERS[schema.index] = GETTERS[id]
        SETTERS[schema.index] = SETTERS[id]
    end
end
-- }}}

-- {{{ Public API

-- Generic getter
function currency.get(entity_or_player, currency_id, ...)
    local getter = GETTERS[currency_id]
    if not getter then
        return nil, "Unknown currency: " .. tostring(currency_id)
    end
    return getter(entity_or_player, ...)
end

-- Generic setter
function currency.set(entity_or_player, currency_id, ...)
    local setter = SETTERS[currency_id]
    if not setter then
        return nil, "Unknown currency: " .. tostring(currency_id)
    end
    return setter(entity_or_player, ...)
end

-- Add (safe increment)
function currency.add(entity_or_player, currency_id, amount, ...)
    local current = currency.get(entity_or_player, currency_id, ...)
    return currency.set(entity_or_player, currency_id, current + amount, ...)
end

-- Subtract (safe decrement, returns false if insufficient)
function currency.subtract(entity_or_player, currency_id, amount, ...)
    local current = currency.get(entity_or_player, currency_id, ...)
    if current < amount then
        return false, "Insufficient " .. currency_id
    end
    currency.set(entity_or_player, currency_id, current - amount, ...)
    return true
end

-- Can afford check
function currency.can_afford(entity_or_player, cost_table)
    for currency_id, amount in pairs(cost_table) do
        local current = currency.get(entity_or_player, currency_id)
        if not current or current < amount then
            return false, currency_id
        end
    end
    return true
end

-- Spend from cost table (atomic)
function currency.spend(entity_or_player, cost_table)
    local can, missing = currency.can_afford(entity_or_player, cost_table)
    if not can then
        return false, "Insufficient " .. missing
    end

    for currency_id, amount in pairs(cost_table) do
        currency.subtract(entity_or_player, currency_id, amount)
    end
    return true
end

-- }}}
```

## 5.2 Cross-System Conversion

```lua
-- src/runtime/currency/conversion.lua

local conversion = {}

-- {{{ Convert WC3 gold to WoW copper
function conversion.wc3_to_wow(player_id, character_entity, amount)
    -- Remove from WC3 player resources
    local current_wc3 = resources.get(player_id, "gold")
    if current_wc3 < amount then
        return false, "Insufficient WC3 gold"
    end

    resources.subtract(player_id, "gold", amount)

    -- Add to character's money bag (100 copper per WC3 gold)
    local copper_amount = amount * 100
    local bag = ecs.get_component(character_entity, "money_bag")
    money_bag.add_copper(bag, copper_amount)

    events.fire("CURRENCY_CONVERTED", {
        from = "wc3_gold",
        to = "copper",
        amount = amount,
        result = copper_amount,
        player_id = player_id,
        character = character_entity,
    })

    return true, copper_amount
end
-- }}}

-- {{{ Convert WoW copper to WC3 gold
function conversion.wow_to_wc3(character_entity, player_id, copper_amount)
    local bag = ecs.get_component(character_entity, "money_bag")
    if not money_bag.can_afford(bag, copper_amount) then
        return false, "Insufficient copper"
    end

    money_bag.remove_copper(bag, copper_amount)

    -- Add to WC3 player resources (1 WC3 gold per 100 copper)
    local wc3_amount = math.floor(copper_amount / 100)
    resources.add(player_id, "gold", wc3_amount)

    -- Return remainder to character
    local remainder = copper_amount % 100
    if remainder > 0 then
        money_bag.add_copper(bag, remainder)
    end

    return true, wc3_amount
end
-- }}}
```

---

## Part 6: WC3 Compatibility

## 6.1 Resource Bridge

The existing `src/runtime/resources.lua` continues to handle WC3-style
per-player resources. The currency system provides a unified view:

```lua
-- Mode detection
local function get_mode()
    -- Could be config-driven or map-driven
    return game_state.mode  -- "wc3" or "wow" or "hybrid"
end

-- In WC3 mode, "gold" means WC3 gold (player resource)
-- In WoW mode, "gold" means gold coins (character inventory)
-- In hybrid mode, both exist and can be converted

function currency.get_gold(entity_or_player)
    local mode = get_mode()

    if mode == "wc3" then
        -- entity_or_player is actually player_id
        return resources.get(entity_or_player, "gold")
    elseif mode == "wow" then
        -- entity_or_player is entity
        local bag = ecs.get_component(entity_or_player, "money_bag")
        return bag and bag.slots.gold.quantity or 0
    else
        -- Hybrid: return both
        return {
            wc3 = resources.get(entity_or_player.player_id, "gold"),
            wow = ecs.get_component(entity_or_player.entity,
"money_bag").slots.gold.quantity,
        }
    end
end
```

## 6.2 JASS Native Compatibility

For JASS scripts expecting `GetPlayerState(player, PLAYER_STATE_RESOURCE_GOLD)`:

```lua
-- Native function wrappers
jass_natives.GetPlayerState = function(player_handle, state_type)
    local player_id = handle_to_player_id(player_handle)

    if state_type == PLAYER_STATE_RESOURCE_GOLD then
        return resources.get(player_id, "gold")
    elseif state_type == PLAYER_STATE_RESOURCE_LUMBER then
        return resources.get(player_id, "lumber")
    elseif state_type == PLAYER_STATE_RESOURCE_FOOD_USED then
        return resources.get(player_id, "food_used")
    -- etc.
    end
end
```

---

## Part 7: Implementation Plan

## Phase 1: Core Infrastructure
1. Create `src/runtime/currency/registry.lua` with CURRENCY_SCHEMA
2. Create `src/runtime/currency/init.lua` with dispatch table pattern
3. Register new ECS components (money_bag, currency_container, reputation,
pvp_honor, profession_skills)

## Phase 2: Physical Currency
1. Implement money_bag operations
2. Create currency item definitions (copper/silver/gold coins)
3. Integrate with existing inventory system
4. Add vendor transaction flow

## Phase 3: Abstract Currencies
1. Implement honor system with Vanilla decay/rank
2. Add mark tokens and battleground integration
3. Implement arena points (TBC+)
4. Add justice/valor points for extensibility

## Phase 4: Reputation System
1. Implement faction registry
2. Add reputation gain/loss with modifiers
3. Implement standing thresholds
4. Add rep-gated vendor access

## Phase 5: Profession Skills
1. Extend profession_skills component from Issue 702
2. Add skill decrease on failure (mod feature)
3. Integrate with gathering/crafting systems

## Phase 6: Cross-System Integration
1. Implement WC3 <-> WoW currency conversion
2. Add mode detection (wc3/wow/hybrid)
3. Create unified display API
4. Integration tests

---

## Critical Files for Implementation

- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/runtime/resources.lua` - Existing WC3 resource system to extend/wrap
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/runtime/ecs/component.lua` - For registering new currency components
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/guild/shop.lua` - Vendor transaction flow to modify for coins
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/guild/items.lua` - Item patterns to follow for coin items
- `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/issues/016b-dispatch-table-getters.md` - Pattern to follow for dispatch tables

--------------------------------------------------------------------------------
