-- {{{ Stat Allocation Test Suite
-- Checks the logic of issue 063 without a window: each stat's row shows
-- its value, limits, cost now and the cost of one step either way;
-- setting a stat is held to its limits and to the budget; sliders snap
-- to increments; presets spend the points left by their shares without
-- going over; and suggestions point at real problems.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_stat_allocation').run_all()"
local TestSuite = {}

local StatAllocator = require("src.editor.stat_allocator")
local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local TemplateConstraints = require("src.data.template_constraints")

-- {{{ local function warrior
local function warrior(stats)
    return UnitTemplate.new({name = "Test Warrior", unit_type = "melee", stats = stats,
        abilities = {"primary_melee_attack", "power_strike"}})
end
-- }}}

-- {{{ local function row_of
local function row_of(allocator, stat)
    for _, row in ipairs(allocator:rows()) do
        if row.stat == stat then
            return row
        end
    end
end
-- }}}

-- {{{ local function has
local function has(list, kind, stat)
    for _, item in ipairs(list) do
        if item.kind == kind and (stat == nil or item.stat == stat) then
            return item
        end
    end
end
-- }}}

-- {{{ TestSuite.test_rows
function TestSuite.test_rows()
    local allocator = StatAllocator:new(warrior({health = 170, armor = 3}))
    local rows = allocator:rows()
    assert(#rows == #UnitTemplate.STAT_NAMES, "A row for every stat")
    assert(rows[1].category == "survival" and rows[#rows].category == "awareness", "Rows come in category order")
    local health = row_of(allocator, "health")
    assert(health.value == 170 and health.base == 120, "Value and the body's own value")
    assert(health.points == allocator.template.breakdown.stats.health, "Points are what the template is charged")
    assert(health.next_cost == 1 and health.refund == 1, "Ten health is a point either way")
    local armor = row_of(allocator, "armor")
    assert(armor.points == 5 and math.abs(armor.exact - 4.5) < 1e-9 and math.abs(armor.rounding - 0.5) < 1e-9,
        "Armor 3 costs 4.5, paid as 5")
    assert(armor.next_cost == 1 and armor.refund == 2, "Armor 4 costs 6 exactly; armor 2 costs 3")
    assert(health.per_point == 10, "A point buys ten health")
    local limits = TemplateConstraints.stats.health
    assert(math.abs(health.fraction - (170 - limits.min) / (limits.max - limits.min)) < 1e-9, "Slider position")
    assert(health.affordable_max <= limits.max and health.affordable_max > 170, "How high it could go")
    print("✓ Rows test passed")
end
-- }}}

-- {{{ TestSuite.test_set_and_limits
function TestSuite.test_set_and_limits()
    local allocator = StatAllocator:new(warrior())
    local kept, note = allocator:set("health", 999)
    assert(kept == TemplateConstraints.stats.health.max and note:find("held to 500"), "Held to the hard limit")
    assert(allocator.template.is_valid, "Still valid")
    local cap = row_of(allocator, "armor").affordable_max
    kept, note = allocator:set("armor", 40)
    assert(kept == cap and note:find("over budget"), "Held to what the points left can buy")
    assert(allocator.template.points_used <= allocator.template.point_budget, "Never over budget")
    assert(allocator.template:points_left() < UnitTemplate.round_up(1.5) + 1, "And close to it")
    kept = allocator:set("armor", 0)
    assert(kept == 0, "Lowering is always allowed")
    kept, note = allocator:set("speed", 72.4)
    assert(kept == 72 and note, "Whole numbers")
    assert(allocator:set("luck", 3) == nil and allocator:set("speed", "fast") == nil, "Unknown stats and non-numbers")

    local over = StatAllocator:new(UnitTemplate.new({name = "Over Budget", unit_type = "melee", stats = {armor = 40},
        abilities = {"primary_melee_attack", "power_strike"}}))
    assert(over:set("health", 300) == 120, "An over-budget template can't raise anything")
    assert(over:set("armor", 10) == 10, "But can come down")
    print("✓ Set and limits test passed")
end
-- }}}

-- {{{ TestSuite.test_steps_and_slider
function TestSuite.test_steps_and_slider()
    local allocator = StatAllocator:new(warrior())
    assert(allocator:step("health", 1) == 130 and allocator:step("health", -1) == 120, "Steps of ten health")
    assert(allocator:step("armor", 1) == 1, "Steps of one armor")
    assert(allocator:step("health", -100) == 110, "A step is one increment whatever the size given")
    local kept = allocator:set_fraction("speed", 0.5)
    local limits = TemplateConstraints.stats.speed
    assert((kept - limits.min) % StatAllocator.STATS.speed.increment == 0, "Sliders snap to the increment")
    assert(math.abs(kept - (limits.min + limits.max) / 2) <= StatAllocator.STATS.speed.increment / 2, "Near the middle")
    assert(allocator:set_fraction("speed", -3) == limits.min, "The slider's ends are the limits")
    assert(allocator:reset("speed") == TemplateCosts.bodies.melee.speed, "Reset is the body's value")
    assert(allocator:step("luck", 1) == nil, "Unknown stats")
    print("✓ Steps and slider test passed")
end
-- }}}

-- {{{ TestSuite.test_presets
function TestSuite.test_presets()
    for _, body in ipairs({"melee", "ranged", "tank", "support", "special"}) do
        local template = UnitTemplate.new({name = "Preset Test", unit_type = body, abilities = {"primary_melee_attack"}})
        for _, preset in ipairs(StatAllocator.PRESETS) do
            local allocator = StatAllocator:new(template)
            local ok, spent = allocator:apply_preset(preset.id)
            local result = allocator:result()
            assert(ok and result.is_valid, preset.id .. " on " .. body .. " is valid: "
                .. table.concat(result.validation_errors, "; "))
            assert(result.points_used <= result.point_budget, preset.id .. " stays in budget")
            for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
                if not preset.shares[stat] then
                    assert(result.stats[stat] == TemplateCosts.bodies[body][stat], preset.id .. " leaves " .. stat)
                end
            end
            local capped = true
            for stat in pairs(preset.shares) do
                local step = StatAllocator.STATS[stat].increment
                if result.stats[stat] + step <= TemplateConstraints.stats[stat].max then
                    capped = false
                end
            end
            assert(capped or result:points_left() < 3, preset.id .. " on " .. body .. " spends what it can (" ..
                spent .. " spent, " .. result:points_left() .. " left)")
        end
    end
    local allocator = StatAllocator:new(warrior({health = 300}))
    local _, spent = allocator:apply_preset("tank", 10)
    assert(spent <= 10 and allocator.template.stats.health > 120 and allocator.template.stats.armor > 0,
        "A preset can spend a set number of points, starting from the body's values")
    local balanced = StatAllocator:new(warrior())
    balanced:apply_preset("balanced")
    local stats = balanced.template.breakdown.stats
    assert(stats.health > 0 and stats.armor > 0 and stats.speed > 0, "Balanced buys all three")
    assert(math.abs(stats.health - 0.4 * (stats.health + stats.armor + stats.speed)) <= 3, "By its shares")
    assert(StatAllocator:new(warrior()):apply_preset("berserk") == nil, "Unknown presets")
    print("✓ Presets test passed")
end
-- }}}

-- {{{ TestSuite.test_suggestions
function TestSuite.test_suggestions()
    local plain = StatAllocator:new(warrior())
    assert(has(plain:suggestions(), "unused_points"), "Unspent points are pointed out")
    local low = StatAllocator:new(warrior({health = 60}))
    assert(has(low:suggestions(), "below_body", "health"), "A stat below the body's value saves nothing")
    local lopsided = StatAllocator:new(warrior({armor = 20}))
    assert(has(lopsided:suggestions(), "lopsided", "armor"), "One stat holding most points")
    local sight = StatAllocator:new(UnitTemplate.new({name = "Sight Test", unit_type = "melee",
        stats = {detection_range = 70}, abilities = {"primary_melee_attack", "power_strike"}}))
    assert(has(sight:suggestions(), "rounding", "detection_range"), "A step paid for but not taken")
    local over = StatAllocator:new(warrior({armor = 40}))
    assert(has(over:suggestions(), "over_budget").severity == "error", "Over budget is an error")
    local full = StatAllocator:new(warrior())
    full:apply_preset("bruiser")
    assert(not has(full:suggestions(), "unused_points") and not has(full:suggestions(), "over_budget"),
        "A preset leaves nothing to say about the budget")
    print("✓ Suggestions test passed")
end
-- }}}

-- {{{ TestSuite.test_result_and_speed
function TestSuite.test_result_and_speed()
    local original = warrior()
    local allocator = StatAllocator:new(original)
    allocator:set("armor", 4)
    assert(original.stats.armor == 0, "The original is untouched")
    local result = allocator:result()
    assert(result.stats.armor == 4 and result ~= allocator.template, "The result is a new template")
    local start = os.clock()
    for i = 1, 200 do
        allocator:set_fraction("health", (i % 20) / 20)
        allocator:rows()
    end
    local seconds = os.clock() - start
    assert(seconds < 5, string.format("200 slider moves take %.2f s", seconds))
    print(string.format("✓ Result and speed test passed (%.2f s)", seconds))
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running stat allocation tests...")
    TestSuite.test_rows()
    TestSuite.test_set_and_limits()
    TestSuite.test_steps_and_slider()
    TestSuite.test_presets()
    TestSuite.test_suggestions()
    TestSuite.test_result_and_speed()
    print("✅ All stat allocation tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
