-- {{{ Point Budget Test Suite
-- Checks the logic of issue 065 without a window: the budget summary's
-- segments add up to the points charged and say where each came from,
-- the status and messages carry the right severity, changes are
-- detected (including the moment to shake), and the optimizer's
-- suggestions really bring an over-budget template back within budget.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_point_budget').run_all()"
local TestSuite = {}

local PointBudget = require("src.editor.point_budget")
local BudgetOptimizer = require("src.utils.budget_optimizer")
local UnitTemplate = require("src.data.unit_template")
local TemplateManager = require("src.managers.template_manager")

-- {{{ local function heavy
-- Six points over budget.
local function heavy()
    return UnitTemplate.new({name = "Heavy Hitter", unit_type = "melee", stats = {health = 250, armor = 8},
        abilities = {"axe_attack", "power_strike", "battle_fury"}})
end
-- }}}

-- {{{ local function find
local function find(list, field, value)
    for _, item in ipairs(list) do
        if item[field] == value then
            return item
        end
    end
end
-- }}}

-- {{{ TestSuite.test_segments
function TestSuite.test_segments()
    local manager = TemplateManager:new()
    for name, template in pairs(manager:create_default_templates()) do
        local summary = PointBudget.summary(template)
        local total, last_end = 0, 0
        for _, segment in ipairs(summary.segments) do
            assert(segment.points > 0, name .. ": no empty segments")
            assert(math.abs(segment.start - last_end) < 1e-9, name .. ": segments follow each other")
            last_end = segment.start + segment.share
            total = total + segment.points
            assert(#segment.tooltip >= 1, name .. ": every segment explains itself")
        end
        assert(total == template.points_used, name .. ": segments add up to the points charged")
        assert(summary.totals.body + summary.totals.stats + summary.totals.abilities == template.points_used,
            name .. ": totals add up")
    end
    local summary = PointBudget.summary(heavy())
    local order = {}
    for _, segment in ipairs(summary.segments) do
        table.insert(order, segment.group)
    end
    assert(table.concat(order, ",") == "stats,stats,abilities,abilities,abilities", "Body, stats, then abilities")
    local armor = find(summary.segments, "key", "stat:armor")
    assert(armor.tooltip[2]:find("8 above the melee body's 0", 1, true), "A stat's tooltip says what was bought")
    local strike = find(summary.segments, "key", "ability:2")
    assert(strike.tooltip[1] == "power_strike (secondary): 42 points", "An ability's tooltip names it and its cost")
    assert(summary.scale == summary.used, "Over budget, the bar stands for the points used")
    local ranged = PointBudget.summary(UnitTemplate.new({name = "Tuned Archer", unit_type = "ranged",
        abilities = {{template = "primary_ranged_attack", changes = {mana_rate = 12}}}}))
    assert(find(ranged.segments, "key", "body").points == 10, "A body that costs points has a segment")
    assert(find(ranged.segments, "key", "ability:1").tooltip[4] == "Tuned: mana_rate 12", "Tuning is shown")
    print("✓ Segments test passed")
end
-- }}}

-- {{{ TestSuite.test_status_and_messages
function TestSuite.test_status_and_messages()
    assert(PointBudget.status_of(101, 100) == "over", "Over")
    assert(PointBudget.status_of(100, 100) == "near" and PointBudget.status_of(90, 100) == "near", "Near")
    assert(PointBudget.status_of(89, 100) == "good" and PointBudget.status_of(85, 100) == "good", "Good")
    assert(PointBudget.status_of(84, 100) == "unused", "Unused")
    local over = PointBudget.summary(heavy())
    assert(over.status == "over" and over.severity == "error" and over.message == "Over budget by 6 points", "Over")
    assert(over.messages[1].rule == "budget", "The status leads the messages")
    for _, message in ipairs(over.messages) do
        assert(message.rule ~= "point_budget", "The validator's budget error isn't repeated")
    end
    local odd = PointBudget.summary(UnitTemplate.new({name = "Odd One", unit_type = "melee",
        stats = {health = 50}, abilities = {"primary_melee_attack", "focus"}}))
    local warning = find(odd.messages, "rule", "recommended_stats")
    assert(warning and warning.severity == "warning", "Warnings keep their rule and severity")
    local broken = PointBudget.summary(UnitTemplate.new({name = "Broken", unit_type = "melee", abilities = {"focus"}}))
    local error = find(broken.messages, "rule", "abilities")
    assert(error and error.severity == "error", "Errors keep theirs")
    assert(broken.messages[2].severity == "error", "Errors come before warnings")
    print("✓ Status and messages test passed")
end
-- }}}

-- {{{ TestSuite.test_change
function TestSuite.test_change()
    local base = UnitTemplate.new({name = "Heavy Hitter", unit_type = "melee", stats = {health = 250, armor = 4},
        abilities = {"axe_attack", "power_strike", "battle_fury"}})
    local before = PointBudget.summary(base)
    local after = PointBudget.summary(heavy())
    local change = PointBudget.change(before, after)
    assert(change.delta == after.used - before.used and change.delta > 0, "The change in points")
    assert(change.became_over and change.status_changed, "Going over is the moment to shake")
    assert(change.groups.stats == change.delta and change.groups.abilities == 0, "Which group moved")
    assert(change.animate, "Anything moving animates")
    local back = PointBudget.change(after, before)
    assert(back.back_in_budget and not back.became_over, "Coming back is noticed too")
    local still = PointBudget.change(before, before)
    assert(not still.animate and not still.status_changed and still.delta == 0, "Nothing changed")
    print("✓ Change test passed")
end
-- }}}

-- {{{ TestSuite.test_optimizer
function TestSuite.test_optimizer()
    local template = heavy()
    local suggestions = BudgetOptimizer.suggest(template)
    assert(#suggestions > 0 and #suggestions <= 8, "Suggestions, at most eight")
    for _, suggestion in ipairs(suggestions) do
        local result = BudgetOptimizer.apply(suggestion)
        assert(result.points_used == suggestion.points_after, suggestion.description .. ": the result is as said")
        assert(template.points_used - result.points_used == suggestion.saves, suggestion.description .. ": saving")
        assert(suggestion.fits == (result.points_used <= result.point_budget), suggestion.description .. ": fits")
    end
    local first = suggestions[1]
    assert(first.fits and first.valid and #first.new_warnings == 0, "The first suggestion fits and adds nothing bad")
    assert(first.saves == 6, "And takes away no more than needed")
    local stat = find(suggestions, "kind", "lower_stat")
    assert(stat and stat.description:find("^Lower "), "Lowering a stat is offered")
    assert(find(suggestions, "kind", "slow_ability") and find(suggestions, "kind", "remove_ability"),
        "Slowing and removing abilities are offered")
    local everything = BudgetOptimizer.suggest(template, {limit = 50})
    assert(find(everything, "kind", "swap_ability"), "Swaps are offered")
    for _, suggestion in ipairs(everything) do
        assert(not suggestion.description:find("Remove axe_attack", 1, true), "The primary is never removed")
    end
    local fine = TemplateManager:new():create_default_templates({"starter"})["Warrior"]
    assert(#BudgetOptimizer.suggest(fine) == 0, "Nothing to suggest within budget")
    local again = BudgetOptimizer.suggest(template)
    for index, suggestion in ipairs(suggestions) do
        assert(again[index].description == suggestion.description, "The same order every time")
    end
    print("✓ Optimizer test passed")
end
-- }}}

-- {{{ TestSuite.test_speed
function TestSuite.test_speed()
    local template = heavy()
    local start = os.clock()
    for _ = 1, 100 do
        PointBudget.summary(template)
    end
    for _ = 1, 10 do
        BudgetOptimizer.suggest(template)
    end
    local seconds = os.clock() - start
    assert(seconds < 5, string.format("100 summaries and 10 optimizer runs take %.2f s", seconds))
    print(string.format("✓ Speed test passed (%.2f s)", seconds))
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running point budget tests...")
    TestSuite.test_segments()
    TestSuite.test_status_and_messages()
    TestSuite.test_change()
    TestSuite.test_optimizer()
    TestSuite.test_speed()
    print("✅ All point budget tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
