--[[
Test suite for Resource Management System (Issue 406)

Tests core resource storage, spending validation, and food/harvesting.
]]

-- {{{ Setup paths
local script_dir = debug.getinfo(1, "S").source:match("@(.*/)")
local project_root = script_dir:match("(.*/)[^/]+/[^/]+/$") or script_dir .. "../../"
package.path = project_root .. "src/?.lua;" ..
               project_root .. "src/?/init.lua;" ..
               package.path
-- }}}

-- {{{ Test framework
local resources = require("runtime.resources")

local tests_run = 0
local tests_passed = 0

local function test(name, fn)
    tests_run = tests_run + 1
    resources.reset()  -- Clean state for each test

    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name)
        print("         " .. tostring(err))
    end
end

local function assert_eq(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s",
            msg or "assertion failed",
            tostring(expected),
            tostring(actual)), 2)
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "expected true", 2)
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "expected false", 2)
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error((msg or "expected nil") .. ", got " .. tostring(value), 2)
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "expected non-nil value", 2)
    end
end
-- }}}

-- {{{ Resource Type Tests
print("\n-- Resource Type Tests --")

test("TYPES constants defined", function()
    assert_eq("gold", resources.TYPES.GOLD, "GOLD constant")
    assert_eq("lumber", resources.TYPES.LUMBER, "LUMBER constant")
    assert_eq("food_used", resources.TYPES.FOOD_USED, "FOOD_USED constant")
    assert_eq("food_cap", resources.TYPES.FOOD_CAP, "FOOD_CAP constant")
end)

test("get_all_types returns standard types", function()
    local types = resources.get_all_types()
    assert_true(#types >= 4, "at least 4 types")

    local found = {}
    for _, t in ipairs(types) do
        found[t] = true
    end

    assert_true(found.gold, "gold type exists")
    assert_true(found.lumber, "lumber type exists")
    assert_true(found.food_used, "food_used type exists")
    assert_true(found.food_cap, "food_cap type exists")
end)

test("get_type_config returns config", function()
    local gold = resources.get_type_config("gold")
    assert_not_nil(gold, "gold config exists")
    assert_eq(999999, gold.max, "gold max")
    assert_eq(0, gold.default, "gold default")
end)

test("get_type_config returns nil for unknown", function()
    local unknown = resources.get_type_config("unknown_resource")
    assert_nil(unknown, "unknown returns nil")
end)

test("register_type adds custom resource", function()
    resources.register_type("mana", {
        max = 1000,
        default = 100,
        description = "Custom mana resource",
    })

    local mana = resources.get_type_config("mana")
    assert_not_nil(mana, "mana config exists")
    assert_eq(1000, mana.max, "mana max")
    assert_eq(100, mana.default, "mana default")
end)

test("register_type updates existing type", function()
    local old_max = resources.get_type_config("gold").max
    assert_eq(999999, old_max, "original max")

    resources.register_type("gold", { max = 500000 })

    local new_max = resources.get_type_config("gold").max
    assert_eq(500000, new_max, "updated max")
end)
-- }}}

-- {{{ Player Initialization Tests
print("\n-- Player Initialization Tests --")

test("init_player creates storage", function()
    assert_false(resources.has_player(0), "player not initialized")

    resources.init_player(0)

    assert_true(resources.has_player(0), "player initialized")
end)

test("init_player sets defaults", function()
    resources.init_player(0)

    assert_eq(0, resources.get(0, "gold"), "gold default")
    assert_eq(0, resources.get(0, "lumber"), "lumber default")
    assert_eq(0, resources.get(0, "food_used"), "food_used default")
    assert_eq(0, resources.get(0, "food_cap"), "food_cap default")
end)

test("init_player fires event", function()
    local event_player = nil
    resources.on("player_resources_initialized", function(player_id)
        event_player = player_id
    end)

    resources.init_player(3)

    assert_eq(3, event_player, "event fired with player id")
end)

test("reset_player resets to defaults", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)
    resources.set(0, "lumber", 150)

    resources.reset_player(0)

    assert_eq(0, resources.get(0, "gold"), "gold reset")
    assert_eq(0, resources.get(0, "lumber"), "lumber reset")
end)

test("reset_player initializes if needed", function()
    assert_false(resources.has_player(0), "not initialized")

    resources.reset_player(0)

    assert_true(resources.has_player(0), "now initialized")
end)

test("remove_player cleans up", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    resources.remove_player(0)

    assert_false(resources.has_player(0), "player removed")
    assert_eq(0, resources.get(0, "gold"), "get returns 0")
end)
-- }}}

-- {{{ Get Tests
print("\n-- Get Tests --")

test("get returns 0 for uninitialized player", function()
    assert_eq(0, resources.get(0, "gold"), "uninitialized returns 0")
end)

test("get returns 0 for unknown resource", function()
    resources.init_player(0)
    assert_eq(0, resources.get(0, "unknown_resource"), "unknown returns 0")
end)

test("get returns set value", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    assert_eq(500, resources.get(0, "gold"), "returns set value")
end)

test("get_all returns all resources", function()
    resources.init_player(0)
    resources.set(0, "gold", 100)
    resources.set(0, "lumber", 50)

    local all = resources.get_all(0)

    assert_eq(100, all.gold, "gold in get_all")
    assert_eq(50, all.lumber, "lumber in get_all")
    assert_eq(0, all.food_used, "food_used in get_all")
    assert_eq(0, all.food_cap, "food_cap in get_all")
end)

test("get_all returns empty for uninitialized", function()
    local all = resources.get_all(99)
    assert_eq(0, next(all) and 1 or 0, "empty table for unknown player")
end)
-- }}}

-- {{{ Set Tests
print("\n-- Set Tests --")

test("set changes value", function()
    resources.init_player(0)

    resources.set(0, "gold", 500)

    assert_eq(500, resources.get(0, "gold"), "value changed")
end)

test("set returns new value", function()
    resources.init_player(0)

    local result = resources.set(0, "gold", 500)

    assert_eq(500, result, "returns new value")
end)

test("set clamps to min 0", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    local result = resources.set(0, "gold", -100)

    assert_eq(0, result, "clamped to 0")
    assert_eq(0, resources.get(0, "gold"), "stored as 0")
end)

test("set clamps to max", function()
    resources.init_player(0)

    local result = resources.set(0, "gold", 9999999)

    assert_eq(999999, result, "clamped to max")
    assert_eq(999999, resources.get(0, "gold"), "stored as max")
end)

test("set fires resource_changed event", function()
    resources.init_player(0)

    local events = {}
    resources.on("resource_changed", function(player_id, resource_name, old_val, new_val)
        table.insert(events, {
            player = player_id,
            resource = resource_name,
            old = old_val,
            new = new_val,
        })
    end)

    resources.set(0, "gold", 500)

    assert_eq(1, #events, "one event fired")
    assert_eq(0, events[1].player, "player id")
    assert_eq("gold", events[1].resource, "resource name")
    assert_eq(0, events[1].old, "old value")
    assert_eq(500, events[1].new, "new value")
end)

test("set does not fire event if unchanged", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    local event_count = 0
    resources.on("resource_changed", function()
        event_count = event_count + 1
    end)

    resources.set(0, "gold", 500)  -- Same value

    assert_eq(0, event_count, "no event for same value")
end)

test("set auto-initializes player", function()
    assert_false(resources.has_player(0), "not initialized")

    resources.set(0, "gold", 500)

    assert_true(resources.has_player(0), "auto initialized")
    assert_eq(500, resources.get(0, "gold"), "value set")
end)

test("set works with custom resources", function()
    resources.init_player(0)

    resources.set(0, "custom_resource", 42)

    assert_eq(42, resources.get(0, "custom_resource"), "custom value set")
end)
-- }}}

-- {{{ Add/Subtract Tests
print("\n-- Add/Subtract Tests --")

test("add increases value", function()
    resources.init_player(0)
    resources.set(0, "gold", 100)

    local result = resources.add(0, "gold", 50)

    assert_eq(150, result, "add returns new value")
    assert_eq(150, resources.get(0, "gold"), "value increased")
end)

test("add clamps to max", function()
    resources.init_player(0)
    resources.set(0, "gold", 999000)

    local result = resources.add(0, "gold", 5000)

    assert_eq(999999, result, "clamped to max")
end)

test("add with negative decreases", function()
    resources.init_player(0)
    resources.set(0, "gold", 100)

    local result = resources.add(0, "gold", -30)

    assert_eq(70, result, "decreased")
end)

test("subtract decreases value", function()
    resources.init_player(0)
    resources.set(0, "gold", 100)

    local result = resources.subtract(0, "gold", 30)

    assert_eq(70, result, "subtract returns new value")
    assert_eq(70, resources.get(0, "gold"), "value decreased")
end)

test("subtract clamps to 0", function()
    resources.init_player(0)
    resources.set(0, "gold", 50)

    local result = resources.subtract(0, "gold", 100)

    assert_eq(0, result, "clamped to 0")
end)
-- }}}

-- {{{ Event System Tests
print("\n-- Event System Tests --")

test("on registers multiple callbacks", function()
    local count = 0
    resources.on("resource_changed", function() count = count + 1 end)
    resources.on("resource_changed", function() count = count + 1 end)

    resources.init_player(0)
    resources.set(0, "gold", 100)

    assert_eq(2, count, "both callbacks called")
end)

test("clear_events removes all listeners", function()
    local count = 0
    resources.on("resource_changed", function() count = count + 1 end)

    resources.clear_events()
    resources.init_player(0)
    resources.set(0, "gold", 100)

    assert_eq(0, count, "no callbacks after clear")
end)

test("reset clears all state", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    local count = 0
    resources.on("resource_changed", function() count = count + 1 end)

    resources.reset()

    assert_false(resources.has_player(0), "player cleared")

    resources.init_player(0)
    resources.set(0, "gold", 100)
    assert_eq(0, count, "events cleared too")
end)
-- }}}

-- {{{ Multiple Player Tests
print("\n-- Multiple Player Tests --")

test("multiple players have separate storage", function()
    resources.init_player(0)
    resources.init_player(1)

    resources.set(0, "gold", 100)
    resources.set(1, "gold", 200)

    assert_eq(100, resources.get(0, "gold"), "player 0 gold")
    assert_eq(200, resources.get(1, "gold"), "player 1 gold")
end)

test("player 15 (neutral) can have resources", function()
    resources.init_player(15)
    resources.set(15, "gold", 999999)

    assert_eq(999999, resources.get(15, "gold"), "neutral player gold")
end)
-- }}}

-- {{{ Custom Resource Tests
print("\n-- Custom Resource Tests --")

test("custom resource works with init_player", function()
    resources.register_type("bounty", {
        max = 100,
        default = 10,
    })

    resources.init_player(0)

    assert_eq(10, resources.get(0, "bounty"), "custom default set")
end)

test("custom resource respects max", function()
    resources.register_type("mana", {
        max = 100,
        default = 0,
    })

    resources.init_player(0)
    local result = resources.set(0, "mana", 999)

    assert_eq(100, result, "clamped to custom max")
end)
-- }}}

-- {{{ Can Afford Tests (406b)
print("\n-- Can Afford Tests --")

test("can_afford returns true when affordable", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)
    resources.set(0, "lumber", 200)

    local can = resources.can_afford(0, { gold = 100, lumber = 50 })
    assert_true(can, "can afford")
end)

test("can_afford returns false when gold insufficient", function()
    resources.init_player(0)
    resources.set(0, "gold", 50)

    local can, missing = resources.can_afford(0, { gold = 100 })
    assert_false(can, "cannot afford")
    assert_eq("gold", missing, "gold is missing")
end)

test("can_afford returns false when lumber insufficient", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)
    resources.set(0, "lumber", 10)

    local can, missing = resources.can_afford(0, { gold = 100, lumber = 50 })
    assert_false(can, "cannot afford")
    assert_eq("lumber", missing, "lumber is missing")
end)

test("can_afford checks food against capacity", function()
    resources.init_player(0)
    resources.set(0, "food_cap", 10)
    resources.set(0, "food_used", 8)

    -- Should be able to afford 2 food (8 + 2 = 10 = cap)
    local can1 = resources.can_afford(0, { food = 2 })
    assert_true(can1, "can afford 2 food")

    -- Should not be able to afford 3 food (8 + 3 = 11 > 10)
    local can2, missing = resources.can_afford(0, { food = 3 })
    assert_false(can2, "cannot afford 3 food")
    assert_eq("food", missing, "food is missing")
end)

test("can_afford with empty cost returns true", function()
    resources.init_player(0)

    local can = resources.can_afford(0, {})
    assert_true(can, "empty cost is affordable")
end)

test("can_afford with nil cost returns true", function()
    resources.init_player(0)

    local can = resources.can_afford(0, nil)
    assert_true(can, "nil cost is affordable")
end)
-- }}}

-- {{{ Spend Tests (406b)
print("\n-- Spend Tests --")

test("spend subtracts gold", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    resources.spend(0, { gold = 100 })

    assert_eq(400, resources.get(0, "gold"), "gold subtracted")
end)

test("spend subtracts lumber", function()
    resources.init_player(0)
    resources.set(0, "lumber", 200)

    resources.spend(0, { lumber = 50 })

    assert_eq(150, resources.get(0, "lumber"), "lumber subtracted")
end)

test("spend increases food_used", function()
    resources.init_player(0)
    resources.set(0, "food_cap", 10)
    resources.set(0, "food_used", 2)

    resources.spend(0, { food = 3 })

    assert_eq(5, resources.get(0, "food_used"), "food_used increased")
end)

test("spend is atomic - nothing spent if cannot afford", function()
    resources.init_player(0)
    resources.set(0, "gold", 50)
    resources.set(0, "lumber", 200)

    local ok = resources.spend(0, { gold = 100, lumber = 50 })

    assert_false(ok, "spend failed")
    assert_eq(50, resources.get(0, "gold"), "gold unchanged")
    assert_eq(200, resources.get(0, "lumber"), "lumber unchanged")
end)

test("spend fires resources_spent event", function()
    resources.init_player(0)
    resources.set(0, "gold", 500)

    local event_player = nil
    local event_cost = nil
    resources.on("resources_spent", function(player_id, cost)
        event_player = player_id
        event_cost = cost
    end)

    resources.spend(0, { gold = 100 })

    assert_eq(0, event_player, "event has player id")
    assert_eq(100, event_cost.gold, "event has cost")
end)

test("spend with nil returns true", function()
    resources.init_player(0)

    local ok = resources.spend(0, nil)
    assert_true(ok, "nil cost succeeds")
end)
-- }}}

-- {{{ Refund Tests (406b)
print("\n-- Refund Tests --")

test("refund adds back gold", function()
    resources.init_player(0)
    resources.set(0, "gold", 400)

    resources.refund(0, { gold = 100 })

    assert_eq(500, resources.get(0, "gold"), "gold added back")
end)

test("refund adds back lumber", function()
    resources.init_player(0)
    resources.set(0, "lumber", 150)

    resources.refund(0, { lumber = 50 })

    assert_eq(200, resources.get(0, "lumber"), "lumber added back")
end)

test("refund decreases food_used", function()
    resources.init_player(0)
    resources.set(0, "food_used", 5)

    resources.refund(0, { food = 2 })

    assert_eq(3, resources.get(0, "food_used"), "food_used decreased")
end)

test("refund fires resources_refunded event", function()
    resources.init_player(0)

    local event_player = nil
    local event_cost = nil
    resources.on("resources_refunded", function(player_id, cost)
        event_player = player_id
        event_cost = cost
    end)

    resources.refund(0, { gold = 100 })

    assert_eq(0, event_player, "event has player id")
    assert_eq(100, event_cost.gold, "event has cost")
end)

test("refund with nil does nothing", function()
    resources.init_player(0)
    resources.set(0, "gold", 100)

    resources.refund(0, nil)

    assert_eq(100, resources.get(0, "gold"), "gold unchanged")
end)
-- }}}

-- {{{ Cost Validation Tests (406b)
print("\n-- Cost Validation Tests --")

test("validate_cost accepts valid cost", function()
    local valid, err = resources.validate_cost({ gold = 100, lumber = 50 })
    assert_true(valid, "valid cost")
    assert_nil(err, "no error")
end)

test("validate_cost rejects non-table", function()
    local valid, err = resources.validate_cost("not a table")
    assert_false(valid, "invalid")
    assert_true(err:find("table"), "error mentions table")
end)

test("validate_cost rejects negative amounts", function()
    local valid, err = resources.validate_cost({ gold = -100 })
    assert_false(valid, "invalid")
    assert_true(err:find("non%-negative"), "error mentions non-negative")
end)

test("validate_cost rejects non-string keys", function()
    local valid, err = resources.validate_cost({ [1] = 100 })
    assert_false(valid, "invalid")
    assert_true(err:find("string"), "error mentions string")
end)
-- }}}

-- {{{ Cost Arithmetic Tests (406b)
print("\n-- Cost Arithmetic Tests --")

test("add_costs combines two costs", function()
    local cost1 = { gold = 100, lumber = 50 }
    local cost2 = { gold = 50, food = 2 }

    local result = resources.add_costs(cost1, cost2)

    assert_eq(150, result.gold, "gold combined")
    assert_eq(50, result.lumber, "lumber from cost1")
    assert_eq(2, result.food, "food from cost2")
end)

test("add_costs handles nil", function()
    local cost1 = { gold = 100 }

    local result = resources.add_costs(cost1, nil)

    assert_eq(100, result.gold, "gold preserved")
end)

test("multiply_cost scales correctly", function()
    local cost = { gold = 100, lumber = 50 }

    local result = resources.multiply_cost(cost, 2)

    assert_eq(200, result.gold, "gold doubled")
    assert_eq(100, result.lumber, "lumber doubled")
end)

test("multiply_cost floors fractional results", function()
    local cost = { gold = 100 }

    local result = resources.multiply_cost(cost, 0.75)

    assert_eq(75, result.gold, "floored to 75")
end)
-- }}}

-- {{{ Food Supply Tests (406c)
print("\n-- Food Supply Tests --")

test("add_food_supply increases food_cap", function()
    resources.init_player(0)
    resources.set(0, "food_cap", 10)

    resources.add_food_supply(0, 6)

    assert_eq(16, resources.get(0, "food_cap"), "food_cap increased")
end)

test("remove_food_supply decreases food_cap", function()
    resources.init_player(0)
    resources.set(0, "food_cap", 20)

    resources.remove_food_supply(0, 6)

    assert_eq(14, resources.get(0, "food_cap"), "food_cap decreased")
end)

test("food_supply_changed event fires", function()
    resources.init_player(0)
    resources.set(0, "food_cap", 10)

    local event_data = nil
    resources.on("food_supply_changed", function(player_id, old_cap, new_cap)
        event_data = { player = player_id, old = old_cap, new = new_cap }
    end)

    resources.add_food_supply(0, 6)

    assert_not_nil(event_data, "event fired")
    assert_eq(10, event_data.old, "old cap")
    assert_eq(16, event_data.new, "new cap")
end)

test("add_food_used increases food_used", function()
    resources.init_player(0)
    resources.set(0, "food_used", 5)

    resources.add_food_used(0, 2)

    assert_eq(7, resources.get(0, "food_used"), "food_used increased")
end)

test("remove_food_used decreases food_used", function()
    resources.init_player(0)
    resources.set(0, "food_used", 10)

    resources.remove_food_used(0, 3)

    assert_eq(7, resources.get(0, "food_used"), "food_used decreased")
end)

test("food_used_changed event fires", function()
    resources.init_player(0)
    resources.set(0, "food_used", 5)

    local event_data = nil
    resources.on("food_used_changed", function(player_id, old_used, new_used)
        event_data = { player = player_id, old = old_used, new = new_used }
    end)

    resources.add_food_used(0, 2)

    assert_not_nil(event_data, "event fired")
    assert_eq(5, event_data.old, "old used")
    assert_eq(7, event_data.new, "new used")
end)

test("get_food_status returns correct values", function()
    resources.init_player(0)
    resources.set(0, "food_cap", 20)
    resources.set(0, "food_used", 15)

    local status = resources.get_food_status(0)

    assert_eq(15, status.used, "used")
    assert_eq(20, status.cap, "cap")
    assert_eq(5, status.available, "available")
    assert_false(status.is_capped, "not capped")
end)

test("get_food_status detects capped state", function()
    resources.init_player(0)
    resources.set(0, "food_cap", 10)
    resources.set(0, "food_used", 10)

    local status = resources.get_food_status(0)

    assert_true(status.is_capped, "is capped")
    assert_eq(0, status.available, "no available")
end)
-- }}}

-- {{{ Upkeep Tests (406c)
print("\n-- Upkeep Tests --")

test("upkeep is none at 50 food", function()
    assert_eq("none", resources.get_upkeep_level(50), "at 50")
    assert_eq("none", resources.get_upkeep_level(0), "at 0")
    assert_eq("none", resources.get_upkeep_level(25), "at 25")
end)

test("upkeep is low at 51-80 food", function()
    assert_eq("low", resources.get_upkeep_level(51), "at 51")
    assert_eq("low", resources.get_upkeep_level(65), "at 65")
    assert_eq("low", resources.get_upkeep_level(80), "at 80")
end)

test("upkeep is high at 81+ food", function()
    assert_eq("high", resources.get_upkeep_level(81), "at 81")
    assert_eq("high", resources.get_upkeep_level(100), "at 100")
end)

test("get_upkeep_rate returns correct rates", function()
    resources.init_player(0)

    resources.set(0, "food_used", 30)
    assert_eq(1.0, resources.get_upkeep_rate(0), "none rate")

    resources.set(0, "food_used", 60)
    assert_eq(0.7, resources.get_upkeep_rate(0), "low rate")

    resources.set(0, "food_used", 90)
    assert_eq(0.4, resources.get_upkeep_rate(0), "high rate")
end)

test("upkeep_changed event fires on threshold crossing", function()
    resources.init_player(0)
    resources.set(0, "food_used", 50)

    local events = {}
    resources.on("upkeep_changed", function(player_id, old_level, new_level)
        table.insert(events, { old = old_level, new = new_level })
    end)

    resources.add_food_used(0, 1)  -- 50 -> 51 (none -> low)

    assert_eq(1, #events, "one event")
    assert_eq("none", events[1].old, "old level")
    assert_eq("low", events[1].new, "new level")
end)
-- }}}

-- {{{ Harvesting Tests (406c)
print("\n-- Harvesting Tests --")

test("deposit_harvest adds resources", function()
    resources.init_player(0)

    resources.deposit_harvest(0, "lumber", 10)

    assert_eq(10, resources.get(0, "lumber"), "lumber added")
end)

test("deposit_harvest applies upkeep to gold", function()
    resources.init_player(0)
    resources.set(0, "food_used", 60)  -- low upkeep (70%)

    local actual = resources.deposit_harvest(0, "gold", 10)

    assert_eq(7, actual, "70% of 10 = 7")
    assert_eq(7, resources.get(0, "gold"), "gold added with upkeep")
end)

test("deposit_harvest does not apply upkeep to lumber", function()
    resources.init_player(0)
    resources.set(0, "food_used", 60)  -- low upkeep

    local actual = resources.deposit_harvest(0, "lumber", 10)

    assert_eq(10, actual, "full amount")
    assert_eq(10, resources.get(0, "lumber"), "lumber not affected by upkeep")
end)

test("deposit_harvest can skip upkeep", function()
    resources.init_player(0)
    resources.set(0, "food_used", 60)  -- low upkeep

    local actual = resources.deposit_harvest(0, "gold", 10, false)  -- skip upkeep

    assert_eq(10, actual, "full amount")
end)

test("deposit_harvest fires event", function()
    resources.init_player(0)

    local event_data = nil
    resources.on("harvest_deposited", function(data)
        event_data = data
    end)

    resources.deposit_harvest(0, "gold", 10)

    assert_not_nil(event_data, "event fired")
    assert_eq(0, event_data.player_id, "player id")
    assert_eq("gold", event_data.resource, "resource")
end)
-- }}}

-- {{{ Gold Mine Tests (406c)
print("\n-- Gold Mine Tests --")

test("deplete_gold_mine reduces remaining gold", function()
    -- Mock ECS (using closure to capture components)
    local components = {}
    local mock_ecs = {
        get_component = function(entity, name)
            return components[entity] and components[entity][name]
        end
    }

    components[1] = {
        gold_mine = { gold_remaining = 100, gold_capacity = 100 }
    }

    local remaining = resources.deplete_gold_mine(mock_ecs, 1, 10)

    assert_eq(90, remaining, "90 gold remaining")
    assert_eq(90, components[1].gold_mine.gold_remaining, "component updated")
end)

test("deplete_gold_mine fires depleted event", function()
    local components = {}
    local mock_ecs = {
        get_component = function(entity, name)
            return components[entity] and components[entity][name]
        end
    }

    components[1] = {
        gold_mine = { gold_remaining = 5, gold_capacity = 100 }
    }

    local depleted_entity = nil
    resources.on("gold_mine_depleted", function(entity)
        depleted_entity = entity
    end)

    resources.deplete_gold_mine(mock_ecs, 1, 10)  -- 5 - 10 = 0 (clamped)

    assert_eq(1, depleted_entity, "depleted event fired")
    assert_eq(0, components[1].gold_mine.gold_remaining, "clamped to 0")
end)

test("deplete_gold_mine returns error for missing component", function()
    local mock_ecs = {
        get_component = function() return nil end
    }

    local remaining, err = resources.deplete_gold_mine(mock_ecs, 1, 10)

    assert_nil(remaining, "returns nil")
    assert_true(err:find("gold_mine"), "error mentions component")
end)

test("get_mine_status returns status", function()
    local components = {}
    local mock_ecs = {
        get_component = function(entity, name)
            return components[entity] and components[entity][name]
        end
    }

    components[1] = {
        gold_mine = { gold_remaining = 5000, gold_capacity = 12500 }
    }

    local status = resources.get_mine_status(mock_ecs, 1)

    assert_eq(5000, status.remaining, "remaining")
    assert_eq(12500, status.capacity, "capacity")
    assert_eq(40, status.percent, "40%")
    assert_false(status.is_depleted, "not depleted")
end)
-- }}}

-- {{{ Income Tests (406c)
print("\n-- Income Tests --")

test("set_income_rate configures income", function()
    resources.init_player(0)

    resources.set_income_rate(0, "gold", 10)

    assert_eq(10, resources.get_income_rate(0, "gold"), "income rate set")
end)

test("get_income_rate returns 0 for unconfigured", function()
    resources.init_player(0)

    assert_eq(0, resources.get_income_rate(0, "gold"), "default is 0")
end)

test("process_income adds resources over time", function()
    resources.init_player(0)
    resources.set_income_rate(0, "gold", 100)  -- 100 per second

    resources.process_income(0.5)  -- 0.5 seconds = 50 gold

    assert_eq(50, resources.get(0, "gold"), "50 gold added")
end)

test("process_income accumulates fractional amounts", function()
    resources.init_player(0)
    resources.set_income_rate(0, "gold", 10)  -- 10 per second

    -- Multiple small ticks
    resources.process_income(0.05)  -- 0.5 gold (accumulated)
    resources.process_income(0.05)  -- 0.5 gold (accumulated)

    assert_eq(1, resources.get(0, "gold"), "accumulated to 1")
end)

test("clear_income removes all income", function()
    resources.init_player(0)
    resources.set_income_rate(0, "gold", 100)

    resources.clear_income()
    resources.process_income(1)

    assert_eq(0, resources.get(0, "gold"), "no income after clear")
end)
-- }}}

-- {{{ Summary
print(string.format("\n=== Results: %d/%d tests passed ===", tests_passed, tests_run))

if tests_passed == tests_run then
    print("All tests passed!")
    os.exit(0)
else
    print(string.format("%d test(s) failed", tests_run - tests_passed))
    os.exit(1)
end
-- }}}
