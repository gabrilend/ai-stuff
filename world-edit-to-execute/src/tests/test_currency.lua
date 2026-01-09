--[[
Currency System Tests

Tests the unified currency system including:
- Currency registry and schema lookup
- Money bag operations (add/remove/format)
- Dispatch table getters/setters
- Format parsing
]]

-- Add src to path
package.path = package.path .. ";./src/?.lua;./src/?/init.lua"

local registry = require("runtime.currency.registry")
local money_bag = require("runtime.currency.money_bag")

-- {{{ Test utilities
local tests_run = 0
local tests_passed = 0

local function test(name, fn)
    tests_run = tests_run + 1
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. ": " .. tostring(err))
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s",
            msg or "Assertion failed",
            tostring(expected),
            tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true, got false")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "Expected false, got true")
    end
end
-- }}}

-- =============================================================================
-- Registry Tests
-- =============================================================================

print("\n=== Currency Registry Tests ===")

test("CURRENCY_CATEGORY has all categories", function()
    assert_eq(1, registry.CURRENCY_CATEGORY.PHYSICAL)
    assert_eq(2, registry.CURRENCY_CATEGORY.ABSTRACT)
    assert_eq(3, registry.CURRENCY_CATEGORY.TOKEN)
    assert_eq(4, registry.CURRENCY_CATEGORY.REPUTATION)
    assert_eq(5, registry.CURRENCY_CATEGORY.SKILL)
    assert_eq(6, registry.CURRENCY_CATEGORY.WC3_RESOURCE)
end)

test("CURRENCY_SCHEMA has copper/silver/gold", function()
    assert_true(registry.CURRENCY_SCHEMA.copper ~= nil)
    assert_true(registry.CURRENCY_SCHEMA.silver ~= nil)
    assert_true(registry.CURRENCY_SCHEMA.gold ~= nil)
end)

test("Physical currencies have correct category", function()
    assert_eq(registry.CURRENCY_CATEGORY.PHYSICAL, registry.CURRENCY_SCHEMA.copper.category)
    assert_eq(registry.CURRENCY_CATEGORY.PHYSICAL, registry.CURRENCY_SCHEMA.silver.category)
    assert_eq(registry.CURRENCY_CATEGORY.PHYSICAL, registry.CURRENCY_SCHEMA.gold.category)
end)

test("Abstract currencies have correct category", function()
    assert_eq(registry.CURRENCY_CATEGORY.ABSTRACT, registry.CURRENCY_SCHEMA.honor.category)
    assert_eq(registry.CURRENCY_CATEGORY.ABSTRACT, registry.CURRENCY_SCHEMA.arena_points.category)
    assert_eq(registry.CURRENCY_CATEGORY.ABSTRACT, registry.CURRENCY_SCHEMA.justice_points.category)
end)

test("WC3 resources have correct category", function()
    assert_eq(registry.CURRENCY_CATEGORY.WC3_RESOURCE, registry.CURRENCY_SCHEMA.wc3_gold.category)
    assert_eq(registry.CURRENCY_CATEGORY.WC3_RESOURCE, registry.CURRENCY_SCHEMA.wc3_lumber.category)
end)

test("get_schema by name", function()
    local schema = registry.get_schema("gold")
    assert_true(schema ~= nil)
    assert_eq("Gold", schema.display_name)
end)

test("get_schema by index", function()
    local schema = registry.get_schema(1)  -- copper
    assert_true(schema ~= nil)
    assert_eq("copper", schema.name)
end)

test("is_physical returns true for coins", function()
    assert_true(registry.is_physical("copper"))
    assert_true(registry.is_physical("silver"))
    assert_true(registry.is_physical("gold"))
end)

test("is_physical returns false for abstract", function()
    assert_false(registry.is_physical("honor"))
    assert_false(registry.is_physical("arena_points"))
end)

test("is_wc3 returns true for WC3 resources", function()
    assert_true(registry.is_wc3("wc3_gold"))
    assert_true(registry.is_wc3("wc3_lumber"))
end)

test("is_wc3 returns false for WoW currencies", function()
    assert_false(registry.is_wc3("gold"))
    assert_false(registry.is_wc3("honor"))
end)

test("Conversion rate: silver to copper is 100", function()
    local schema = registry.get_schema("silver")
    assert_eq("copper", schema.conversion.to)
    assert_eq(100, schema.conversion.rate)
end)

test("Conversion rate: gold to silver is 100", function()
    local schema = registry.get_schema("gold")
    assert_eq("silver", schema.conversion.to)
    assert_eq(100, schema.conversion.rate)
end)

-- =============================================================================
-- Standing and Rank Tests
-- =============================================================================

print("\n=== Standing and Rank Tests ===")

test("get_standing_name for Hated", function()
    assert_eq("Hated", registry.get_standing_name(-42000))
    assert_eq("Hated", registry.get_standing_name(-10000))
end)

test("get_standing_name for Neutral", function()
    assert_eq("Neutral", registry.get_standing_name(0))
    assert_eq("Neutral", registry.get_standing_name(2999))
end)

test("get_standing_name for Exalted", function()
    assert_eq("Exalted", registry.get_standing_name(42000))
    assert_eq("Exalted", registry.get_standing_name(42999))
end)

test("get_standing_index for Neutral is 4", function()
    assert_eq(4, registry.get_standing_index(0))
end)

test("get_standing_index for Exalted is 8", function()
    assert_eq(8, registry.get_standing_index(42000))
end)

test("get_honor_rank for 0 honor is rank 0", function()
    local rank, data = registry.get_honor_rank(0)
    assert_eq(0, rank)
    assert_eq("None", data.alliance)
end)

test("get_honor_rank for 60000 honor is rank 14", function()
    local rank, data = registry.get_honor_rank(60000)
    assert_eq(14, rank)
    assert_eq("Grand Marshal", data.alliance)
    assert_eq("High Warlord", data.horde)
end)

-- =============================================================================
-- Money Bag Tests
-- =============================================================================

print("\n=== Money Bag Tests ===")

test("create returns empty bag", function()
    local bag = money_bag.create()
    assert_eq(0, bag.total_copper)
    assert_eq(0, bag.slots.copper.quantity)
    assert_eq(0, bag.slots.silver.quantity)
    assert_eq(0, bag.slots.gold.quantity)
end)

test("add_copper increases total", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 100)
    assert_eq(100, bag.total_copper)
end)

test("add_copper normalizes to silver", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 150)
    assert_eq(1, bag.slots.silver.quantity)
    assert_eq(50, bag.slots.copper.quantity)
    assert_eq(150, bag.total_copper)
end)

test("add_copper normalizes to gold", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 15000)
    assert_eq(1, bag.slots.gold.quantity)
    assert_eq(50, bag.slots.silver.quantity)
    assert_eq(0, bag.slots.copper.quantity)
    assert_eq(15000, bag.total_copper)
end)

test("remove_copper succeeds when sufficient", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 500)
    local ok = money_bag.remove_copper(bag, 200)
    assert_true(ok)
    assert_eq(300, bag.total_copper)
end)

test("remove_copper fails when insufficient", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 100)
    local ok, err = money_bag.remove_copper(bag, 200)
    assert_false(ok)
    assert_eq(100, bag.total_copper)  -- Unchanged
end)

test("can_afford returns true when sufficient", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 10000)
    assert_true(money_bag.can_afford(bag, 5000))
    assert_true(money_bag.can_afford(bag, 10000))
end)

test("can_afford returns false when insufficient", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 100)
    assert_false(money_bag.can_afford(bag, 200))
end)

test("set_total distributes coins", function()
    local bag = money_bag.create()
    money_bag.set_total(bag, 12345)
    assert_eq(1, bag.slots.gold.quantity)
    assert_eq(23, bag.slots.silver.quantity)
    assert_eq(45, bag.slots.copper.quantity)
    assert_eq(12345, bag.total_copper)
end)

test("format shows all denominations", function()
    local bag = money_bag.create()
    money_bag.set_total(bag, 12345)
    assert_eq("1g 23s 45c", money_bag.format(bag))
end)

test("format shows only relevant denominations", function()
    local bag = money_bag.create()
    money_bag.set_total(bag, 500)
    assert_eq("5s", money_bag.format(bag))
end)

test("format shows 0c for empty bag", function()
    local bag = money_bag.create()
    assert_eq("0c", money_bag.format(bag))
end)

test("format_copper static function", function()
    assert_eq("1g 23s 45c", money_bag.format_copper(12345))
    assert_eq("5s", money_bag.format_copper(500))
    assert_eq("45c", money_bag.format_copper(45))
    assert_eq("0c", money_bag.format_copper(0))
end)

test("parse money string", function()
    assert_eq(12345, money_bag.parse("1g 23s 45c"))
    assert_eq(10000, money_bag.parse("1g"))
    assert_eq(500, money_bag.parse("5s"))
    assert_eq(45, money_bag.parse("45c"))
    assert_eq(10050, money_bag.parse("1g 50c"))
end)

test("transfer moves money between bags", function()
    local from = money_bag.create()
    local to = money_bag.create()
    money_bag.add_copper(from, 1000)

    local ok = money_bag.transfer(from, to, 400)
    assert_true(ok)
    assert_eq(600, from.total_copper)
    assert_eq(400, to.total_copper)
end)

test("transfer fails when insufficient", function()
    local from = money_bag.create()
    local to = money_bag.create()
    money_bag.add_copper(from, 100)

    local ok = money_bag.transfer(from, to, 500)
    assert_false(ok)
    assert_eq(100, from.total_copper)  -- Unchanged
    assert_eq(0, to.total_copper)      -- Unchanged
end)

test("clone creates independent copy", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 5000)

    local copy = money_bag.clone(bag)
    assert_eq(5000, copy.total_copper)

    money_bag.add_copper(bag, 1000)
    assert_eq(6000, bag.total_copper)
    assert_eq(5000, copy.total_copper)  -- Independent
end)

test("empty returns true for zero bag", function()
    local bag = money_bag.create()
    assert_true(money_bag.empty(bag))

    money_bag.add_copper(bag, 1)
    assert_false(money_bag.empty(bag))
end)

test("reset clears bag", function()
    local bag = money_bag.create()
    money_bag.add_copper(bag, 10000)
    money_bag.reset(bag)

    assert_eq(0, bag.total_copper)
    assert_true(money_bag.empty(bag))
end)

-- =============================================================================
-- Custom Currency Registration Tests
-- =============================================================================

print("\n=== Custom Currency Tests ===")

test("register_custom adds new currency", function()
    local ok = registry.register_custom("test_tokens", {
        category = registry.CURRENCY_CATEGORY.TOKEN,
        display_name = "Test Tokens",
        cap = 1000,
    })
    assert_true(ok)

    local schema = registry.get_schema("test_tokens")
    assert_true(schema ~= nil)
    assert_eq("Test Tokens", schema.display_name)
    assert_eq(1000, schema.cap)
end)

test("register_custom fails for existing currency", function()
    local ok = registry.register_custom("gold", {
        display_name = "Fake Gold",
    })
    assert_false(ok)
end)

test("get_all_currencies includes custom", function()
    local all = registry.get_all_currencies()
    local found = false
    for _, name in ipairs(all) do
        if name == "test_tokens" then
            found = true
            break
        end
    end
    assert_true(found, "Custom currency should be in list")
end)

test("get_currencies_by_category works", function()
    local physical = registry.get_currencies_by_category(registry.CURRENCY_CATEGORY.PHYSICAL)
    local found_copper = false
    local found_gold = false
    for _, name in ipairs(physical) do
        if name == "copper" then found_copper = true end
        if name == "gold" then found_gold = true end
    end
    assert_true(found_copper)
    assert_true(found_gold)
end)

-- =============================================================================
-- Reputation Tests
-- =============================================================================

local reputation = require("runtime.currency.reputation")

print("\n=== Reputation Tests ===")

test("create returns fresh reputation", function()
    local rep = reputation.create()
    assert_true(rep ~= nil)
    assert_true(rep.standings ~= nil)
end)

test("create with side initializes faction standings", function()
    local rep = reputation.create("horde")
    -- Should be friendly with Horde factions
    assert_true(reputation.get(rep, "orgrimmar") >= 3000)
    -- Should be hostile with Alliance factions
    assert_true(reputation.get(rep, "stormwind") < 0)
end)

test("get returns default for unknown faction", function()
    local rep = reputation.create()
    assert_eq(0, reputation.get(rep, "unknown_faction"))
end)

test("set clamps to valid range", function()
    local rep = reputation.create()
    reputation.set(rep, "test", 100000)  -- Over max
    assert_eq(42999, reputation.get(rep, "test"))

    reputation.set(rep, "test", -100000)  -- Under min
    assert_eq(-42000, reputation.get(rep, "test"))
end)

test("add increases reputation", function()
    local rep = reputation.create()
    reputation.set(rep, "argent_dawn", 5000)
    reputation.add(rep, "argent_dawn", 1000)
    assert_eq(6000, reputation.get(rep, "argent_dawn"))
end)

test("get_standing_name returns correct tier", function()
    local rep = reputation.create()

    reputation.set(rep, "test", 0)
    assert_eq("Neutral", reputation.get_standing_name(rep, "test"))

    reputation.set(rep, "test", 9000)
    assert_eq("Honored", reputation.get_standing_name(rep, "test"))

    reputation.set(rep, "test", 42000)
    assert_eq("Exalted", reputation.get_standing_name(rep, "test"))
end)

test("is_friendly returns true for Friendly+", function()
    local rep = reputation.create()

    reputation.set(rep, "test", 2999)
    assert_false(reputation.is_friendly(rep, "test"))

    reputation.set(rep, "test", 3000)
    assert_true(reputation.is_friendly(rep, "test"))
end)

test("is_hostile returns true for Hostile or worse", function()
    local rep = reputation.create()

    reputation.set(rep, "test", -3000)
    assert_false(reputation.is_hostile(rep, "test"))

    reputation.set(rep, "test", -3001)
    assert_true(reputation.is_hostile(rep, "test"))
end)

test("get_discount returns correct multiplier", function()
    local rep = reputation.create()

    reputation.set(rep, "test", 0)
    assert_eq(1.0, reputation.get_discount(rep, "test"))

    reputation.set(rep, "test", 9000)  -- Honored
    assert_eq(0.90, reputation.get_discount(rep, "test"))

    reputation.set(rep, "test", 42000)  -- Exalted
    assert_eq(0.80, reputation.get_discount(rep, "test"))
end)

test("can_interact requires Neutral or better", function()
    local rep = reputation.create()

    reputation.set(rep, "test", -1)
    assert_false(reputation.can_interact(rep, "test"))

    reputation.set(rep, "test", 0)
    assert_true(reputation.can_interact(rep, "test"))
end)

test("get_progress returns tier progress", function()
    local rep = reputation.create()
    reputation.set(rep, "test", 15000)  -- Mid-Honored

    local current, max, percent = reputation.get_progress(rep, "test")
    assert_true(current > 0)
    assert_true(max > 0)
    assert_true(percent > 0 and percent < 100)
end)

test("set_watched and get_watched", function()
    local rep = reputation.create()
    assert_eq(nil, reputation.get_watched(rep))

    reputation.set_watched(rep, "argent_dawn")
    assert_eq("argent_dawn", reputation.get_watched(rep))
end)

test("get_all_factions returns list", function()
    local factions = reputation.get_all_factions()
    assert_true(#factions > 0)
end)

test("get_factions_by_side filters correctly", function()
    local horde = reputation.get_factions_by_side("horde")
    local found_orgrimmar = false
    for _, id in ipairs(horde) do
        if id == "orgrimmar" then found_orgrimmar = true end
    end
    assert_true(found_orgrimmar)
end)

test("register_faction adds custom faction", function()
    reputation.register_faction("test_guild", {
        name = "Test Guild",
        default = 0,
        side = "neutral",
    })

    local info = reputation.get_faction_info("test_guild")
    assert_true(info ~= nil)
    assert_eq("Test Guild", info.name)
end)

-- =============================================================================
-- Conversion Tests
-- =============================================================================

local conversion = require("runtime.currency.conversion")

print("\n=== Conversion Tests ===")

test("exchange rate: WC3 gold to copper is 100", function()
    local rate = conversion.get_exchange_rate("wc3_gold", "copper")
    assert_eq(100, rate)
end)

test("exchange rate: copper to WC3 gold is 0.01", function()
    local rate = conversion.get_exchange_rate("copper", "wc3_gold")
    assert_eq(0.01, rate)
end)

test("preview_wc3_to_wow calculates correctly", function()
    local preview = conversion.preview_wc3_to_wow(150)
    assert_eq(15000, preview.total_copper)
    assert_eq(1, preview.gold)
    assert_eq(50, preview.silver)
    assert_eq(0, preview.copper)
end)

test("preview_wow_to_wc3 calculates correctly", function()
    local preview = conversion.preview_wow_to_wc3(1550)
    assert_eq(15, preview.wc3_gold)
    assert_eq(50, preview.remainder_copper)
end)

test("preview_wow_to_wc3 with fractional", function()
    local preview = conversion.preview_wow_to_wc3(99)
    assert_eq(0, preview.wc3_gold)  -- Not enough for 1 WC3 gold
    assert_eq(99, preview.remainder_copper)
end)

-- =============================================================================
-- Currency Container Tests
-- =============================================================================

local currency_container = require("runtime.currency.currency_container")

test("create returns fresh container", function()
    local cont = currency_container.create()
    assert_eq("table", type(cont))
    assert_eq("table", type(cont.values))
    assert_eq("table", type(cont.tokens))
    assert_eq("table", type(cont.weekly_earned))
end)

test("get/set abstract currency", function()
    local cont = currency_container.create()
    assert_eq(0, currency_container.get(cont, "honor"))

    currency_container.set(cont, "honor", 5000)
    assert_eq(5000, currency_container.get(cont, "honor"))
end)

test("set clamps to cap", function()
    local cont = currency_container.create()
    -- Honor has cap of 75000
    currency_container.set(cont, "honor", 100000)
    assert_eq(75000, currency_container.get(cont, "honor"))
end)

test("add increases value", function()
    local cont = currency_container.create()
    currency_container.set(cont, "honor", 1000)
    currency_container.add(cont, "honor", 500)
    assert_eq(1500, currency_container.get(cont, "honor"))
end)

test("subtract decreases value", function()
    local cont = currency_container.create()
    currency_container.set(cont, "honor", 1000)
    local ok = currency_container.subtract(cont, "honor", 300)
    assert_eq(true, ok)
    assert_eq(700, currency_container.get(cont, "honor"))
end)

test("subtract fails when insufficient", function()
    local cont = currency_container.create()
    currency_container.set(cont, "honor", 100)
    local ok = currency_container.subtract(cont, "honor", 500)
    assert_eq(false, ok)
    assert_eq(100, currency_container.get(cont, "honor"))  -- Unchanged
end)

test("get_cap returns currency cap", function()
    local cap = currency_container.get_cap("honor")
    assert_eq(75000, cap)
end)

test("get_weekly_cap returns weekly cap", function()
    local cap = currency_container.get_weekly_cap("valor_points")
    assert_eq(1000, cap)
end)

test("weekly tracking respects cap", function()
    local cont = currency_container.create()
    -- Valor has weekly cap of 1000
    local added = currency_container.add_with_weekly_tracking(cont, "valor_points", 600)
    assert_eq(600, added)
    assert_eq(600, currency_container.get(cont, "valor_points"))

    -- Try to add 600 more (would exceed 1000 weekly cap)
    added = currency_container.add_with_weekly_tracking(cont, "valor_points", 600)
    assert_eq(400, added)  -- Only 400 more allowed
    assert_eq(1000, currency_container.get(cont, "valor_points"))
end)

test("can_earn_weekly checks weekly cap", function()
    local cont = currency_container.create()
    cont.weekly_earned = { [13] = 900 }  -- Valor index is 13

    assert_eq(true, currency_container.can_earn_weekly(cont, "valor_points", 100))
    assert_eq(false, currency_container.can_earn_weekly(cont, "valor_points", 200))
end)

test("reset_weekly clears weekly earned", function()
    local cont = currency_container.create()
    cont.weekly_earned = { [13] = 500 }
    currency_container.reset_weekly(cont)
    assert_eq(0, currency_container.get_weekly_earned(cont, "valor_points"))
end)

test("apply_decay reduces honor by decay_rate", function()
    local cont = currency_container.create()
    currency_container.set(cont, "honor", 10000)
    -- Honor has 25% decay rate
    local losses = currency_container.apply_decay(cont)
    assert_eq(2500, losses.honor)
    assert_eq(7500, currency_container.get(cont, "honor"))
end)

test("get/set token currency", function()
    local cont = currency_container.create()
    assert_eq(0, currency_container.get_token(cont, "mark_warsong"))

    currency_container.set_token(cont, "mark_warsong", 5)
    assert_eq(5, currency_container.get_token(cont, "mark_warsong"))
end)

test("add_token increases count", function()
    local cont = currency_container.create()
    currency_container.set_token(cont, "mark_arathi", 3)
    currency_container.add_token(cont, "mark_arathi", 2)
    assert_eq(5, currency_container.get_token(cont, "mark_arathi"))
end)

test("remove_token succeeds when sufficient", function()
    local cont = currency_container.create()
    currency_container.set_token(cont, "mark_warsong", 10)
    local ok = currency_container.remove_token(cont, "mark_warsong", 4)
    assert_eq(true, ok)
    assert_eq(6, currency_container.get_token(cont, "mark_warsong"))
end)

test("remove_token fails when insufficient", function()
    local cont = currency_container.create()
    currency_container.set_token(cont, "mark_warsong", 2)
    local ok = currency_container.remove_token(cont, "mark_warsong", 5)
    assert_eq(false, ok)
    assert_eq(2, currency_container.get_token(cont, "mark_warsong"))  -- Unchanged
end)

test("modifiers can be set and retrieved", function()
    local cont = currency_container.create()
    currency_container.set_modifier(cont, "honor_bonus", 1.5)
    assert_eq(1.5, currency_container.get_modifier(cont, "honor_bonus"))
end)

test("clear_modifiers removes all modifiers", function()
    local cont = currency_container.create()
    currency_container.set_modifier(cont, "honor_bonus", 1.5)
    currency_container.set_modifier(cont, "arena_bonus", 1.2)
    currency_container.clear_modifiers(cont)
    assert_eq(0, currency_container.get_modifier(cont, "honor_bonus"))
end)

test("get_all_values returns non-zero currencies", function()
    local cont = currency_container.create()
    currency_container.set(cont, "honor", 500)
    currency_container.set(cont, "arena_points", 100)
    local all = currency_container.get_all_values(cont)
    assert_eq(500, all.honor)
    assert_eq(100, all.arena_points)
    assert_eq(nil, all.valor_points)  -- Not set, so not in result
end)

test("clone creates independent copy", function()
    local cont = currency_container.create()
    currency_container.set(cont, "honor", 1000)
    currency_container.set_token(cont, "mark_warsong", 5)

    local copy = currency_container.clone(cont)
    currency_container.set(cont, "honor", 2000)

    assert_eq(1000, currency_container.get(copy, "honor"))  -- Original value
    assert_eq(5, currency_container.get_token(copy, "mark_warsong"))
end)

test("reset clears all values", function()
    local cont = currency_container.create()
    currency_container.set(cont, "honor", 1000)
    currency_container.set_token(cont, "mark_warsong", 5)
    currency_container.reset(cont)
    assert_eq(0, currency_container.get(cont, "honor"))
    assert_eq(0, currency_container.get_token(cont, "mark_warsong"))
end)

-- =============================================================================
-- Vendor Tests
-- =============================================================================

local vendor = require("runtime.currency.vendor")

-- Mock shop for testing
local function create_mock_shop()
    return {
        faction_id = nil,
        sell_modifier = 0.5,
        stock = {
            test_item = { quantity = 10 },
            unlimited_item = { quantity = -1 },
        },
        get_buy_price = function(self, item_id, hero)
            if item_id == "test_item" then
                return 10  -- 10 gold
            elseif item_id == "unlimited_item" then
                return 5
            end
            return nil
        end,
        is_in_stock = function(self, item_id)
            local stock = self.stock[item_id]
            if not stock then return false end
            return stock.quantity == -1 or stock.quantity > 0
        end,
    }
end

-- Mock entity with money_bag
local function create_mock_entity(copper_amount)
    local bag = money_bag.create()
    money_bag.add_copper(bag, copper_amount or 0)
    return {
        _money_bag = bag,
    }
end

-- Override get_component for testing
local original_get_component = nil
local mock_entities = {}

local function setup_mock_ecs()
    local ecs = require("runtime.ecs")
    original_get_component = ecs.get_component
    ecs.get_component = function(entity, component_name)
        if component_name == "money_bag" then
            return entity._money_bag
        elseif component_name == "reputation" then
            return entity._reputation
        end
        return nil
    end
end

local function teardown_mock_ecs()
    if original_get_component then
        local ecs = require("runtime.ecs")
        ecs.get_component = original_get_component
    end
end

setup_mock_ecs()

test("vendor.get_mode returns current mode", function()
    vendor.set_mode(vendor.MODE.WOW)
    assert_eq(vendor.MODE.WOW, vendor.get_mode())
end)

test("vendor.can_afford checks money bag", function()
    local entity = create_mock_entity(50000)  -- 5g
    assert_eq(true, vendor.can_afford(entity, 50000))
    assert_eq(false, vendor.can_afford(entity, 60000))
end)

test("vendor.get_buy_price returns copper price", function()
    local shop = create_mock_shop()
    local entity = create_mock_entity(100000)
    local price = vendor.get_buy_price(entity, shop, "test_item")
    -- Shop returns 10 gold, converted to copper = 100000
    assert_eq(100000, price)
end)

test("vendor.get_sell_price calculates correctly", function()
    local item = { buy_price = 10 }  -- 10 gold
    local price = vendor.get_sell_price(item, nil)
    -- 10 gold * 10000 = 100000 copper * 0.5 = 50000
    assert_eq(50000, price)
end)

test("vendor.get_sell_price returns 0 for soulbound", function()
    local item = { buy_price = 10, soulbound = true }
    local price = vendor.get_sell_price(item, nil)
    assert_eq(0, price)
end)

test("vendor.buy_item succeeds with funds", function()
    local shop = create_mock_shop()
    local entity = create_mock_entity(200000)  -- 20g
    local ok, receipt = vendor.buy_item(entity, shop, "test_item", 1)
    assert_eq(true, ok)
    assert_eq("test_item", receipt.item_id)
    assert_eq(100000, receipt.total_price)
    -- Stock should be reduced
    assert_eq(9, shop.stock.test_item.quantity)
end)

test("vendor.buy_item fails without funds", function()
    local shop = create_mock_shop()
    local entity = create_mock_entity(1000)  -- 10 silver
    local ok, err = vendor.buy_item(entity, shop, "test_item", 1)
    assert_eq(false, ok)
    assert(err:find("Insufficient"), "Expected insufficient funds error")
end)

test("vendor.sell_item adds coins to money bag", function()
    local entity = create_mock_entity(0)
    local item = { name = "Test Item", buy_price = 10, quantity = 1 }
    local ok, receipt = vendor.sell_item(entity, nil, item)
    assert_eq(true, ok)
    assert_eq("Test Item", receipt.item_name)
    assert_eq(50000, receipt.total_earned)  -- 5g after 50% modifier
    -- Check money was added
    assert_eq(50000, entity._money_bag.total_copper)
end)

test("vendor.preview_buy shows correct info", function()
    local shop = create_mock_shop()
    local entity = create_mock_entity(50000)  -- 5g
    local preview = vendor.preview_buy(entity, shop, "test_item", 1)
    assert_eq(100000, preview.total_price)
    assert_eq(false, preview.can_afford)  -- Need 10g, have 5g
    assert_eq(true, preview.in_stock)
end)

test("vendor.format_price formats copper correctly", function()
    local formatted = vendor.format_price(15050)  -- 1g 50s 50c
    assert_eq("1g 50s 50c", formatted)
end)

teardown_mock_ecs()

-- =============================================================================
-- Summary
-- =============================================================================

print("\n" .. string.rep("=", 60))
print(string.format("Tests: %d passed / %d total", tests_passed, tests_run))
if tests_passed == tests_run then
    print("All tests passed!")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
