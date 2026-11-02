-- {{{ Repricing Test Suite
-- Checks the machinery of issue 058 (src/testing/repricing.lua): the
-- fit moves prices the right way on made-up win rates, holds parts with
-- too little evidence, never touches src/data/template_costs.lua, marks
-- everything it prints provisional, and gives the same answer for the
-- same seed. It does not check that any price is right: tuning waits
-- until issue 067 puts ability sets into real matches.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_repricing').run_all()"
local TestSuite = {}

local Repricing = require("src.testing.repricing")
local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local TemplateManager = require("src.managers.template_manager")

-- {{{ local function snapshot
-- Today's prices as text, to show they didn't change.
local function snapshot()
    local parts = {}
    for _, name in ipairs({"melee", "ranged", "tank", "support", "special"}) do
        table.insert(parts, name .. "=" .. TemplateCosts.bodies[name].cost)
    end
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        table.insert(parts, stat .. "=" .. TemplateCosts.stats[stat].per_unit)
    end
    local keys = {}
    for key in pairs(TemplateCosts.abilities) do
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        table.insert(parts, key .. "=" .. TemplateCosts.abilities[key])
    end
    return table.concat(parts, ",")
end
-- }}}

-- {{{ local function made_up
-- Two templates sharing the sword and differing in their second ability.
local function made_up()
    local strong = UnitTemplate.new({name = "Strong One", unit_type = "melee",
        abilities = {"primary_melee_attack", "power_strike"}})
    local weak = UnitTemplate.new({name = "Weak One", unit_type = "melee",
        abilities = {"primary_melee_attack", "sunder_armor"}})
    return strong, weak
end
-- }}}

-- {{{ local function small_field
local function small_field()
    local manager = TemplateManager:new()
    manager:create_default_templates({"starter"})
    return {manager:get_template("Archer"), manager:get_template("Warrior"), manager:get_template("Brute")}
end
-- }}}

local QUICK = {battles = 2, max_time = 30, calibration_battles = 2, calibration_points = {0, 10}}

-- {{{ TestSuite.test_logit
function TestSuite.test_logit()
    assert(math.abs(Repricing.logit(5, 10)) < 1e-12, "Half the battles won is even")
    assert(math.abs(Repricing.logit(9, 10) + Repricing.logit(1, 10)) < 1e-12, "Winning and losing mirror each other")
    local all, none = Repricing.logit(10, 10), Repricing.logit(0, 10)
    assert(all > 0 and all < 10 and none < 0 and none > -10, "All or no wins stay finite")
    print("✓ Logit test passed")
end
-- }}}

-- {{{ TestSuite.test_fit_direction
function TestSuite.test_fit_direction()
    local before = snapshot()
    local strong, weak = made_up()
    local proposal = Repricing.fit({
        {name = strong.name, template = strong, score = 18, battles = 20},
        {name = weak.name, template = weak, score = 2, battles = 20}
    }, {points_per_logit = 10})
    assert(proposal.provisional, "A proposal is provisional")
    assert(proposal.templates[1].gap > 0 and proposal.templates[2].gap < 0, "Winners are worth more, losers less")
    assert(proposal.factors["ability:power_strike"].factor > 1, "The winner's own ability gets dearer")
    assert(proposal.factors["ability:sunder_armor"].factor < 1, "The loser's own ability gets cheaper")
    local shared = proposal.factors["ability:primary_melee_attack"].factor
    assert(shared > proposal.factors["ability:sunder_armor"].factor
        and shared < proposal.factors["ability:power_strike"].factor, "A shared part lands in between")
    assert(proposal.factors["ability:primary_melee_attack"].templates == 2, "Evidence is counted")
    assert(proposal.spread_after < proposal.spread_before, "The factors bring prices nearer fair costs")
    assert(snapshot() == before, "template_costs.lua's prices are untouched")
    print("✓ Fit direction test passed")
end
-- }}}

-- {{{ TestSuite.test_fit_limits
function TestSuite.test_fit_limits()
    local strong, weak = made_up()
    local even = Repricing.fit({
        {name = strong.name, template = strong, score = 10, battles = 20},
        {name = weak.name, template = weak, score = 10, battles = 20}
    }, {points_per_logit = 10})
    for _, key in ipairs(even.order) do
        assert(math.abs(even.factors[key].factor - 1) < 1e-9, "Even results change nothing: " .. key)
    end
    local wild = Repricing.fit({{name = strong.name, template = strong, score = 1000, battles = 1000}},
        {points_per_logit = 1000, damping = 1})
    for _, key in ipairs(wild.order) do
        assert(wild.factors[key].factor <= Repricing.DEFAULTS.max_factor + 1e-9, "Factors are held to the range")
    end
    local strict = Repricing.fit({{name = strong.name, template = strong, score = 18, battles = 20}},
        {points_per_logit = 10, min_evidence = 0.9})
    assert(not strict.factors["ability:power_strike"].moved and strict.factors["ability:power_strike"].factor == 1,
        "A part with too little evidence is held")
    local unchanged = Repricing.cost_under(strong, {factors = {}})
    assert(math.abs(unchanged - strong.points_used) < 1e-9, "With no factors a template costs what it does today")
    print("✓ Fit limits test passed")
end
-- }}}

-- {{{ TestSuite.test_suggested_prices
function TestSuite.test_suggested_prices()
    local tank = UnitTemplate.new({name = "Armored", unit_type = "tank", stats = {armor = 12},
        abilities = {"primary_melee_attack"}})
    local proposal = Repricing.fit({{name = tank.name, template = tank, score = 19, battles = 20}},
        {points_per_logit = 10, min_evidence = 0})
    local prices = Repricing.suggested_prices(proposal)
    assert(prices.provisional, "Suggested prices are provisional")
    assert(prices.stats.armor.now == TemplateCosts.stats.armor.per_unit, "Today's price is shown")
    assert(prices.stats.armor.suggested > prices.stats.armor.now, "A winning tank's armor gets dearer")
    assert(prices.bodies.tank.suggested > prices.bodies.tank.now, "And its body")
    assert(prices.abilities.primary_melee_attack.factor > 1, "Abilities get a factor")
    print("✓ Suggested prices test passed")
end
-- }}}

-- {{{ TestSuite.test_lines_provisional
function TestSuite.test_lines_provisional()
    local strong, weak = made_up()
    local proposal = Repricing.fit({
        {name = strong.name, template = strong, score = 15, battles = 20},
        {name = weak.name, template = weak, score = 5, battles = 20}
    }, {points_per_logit = 10})
    local lines = Repricing.lines(proposal)
    assert(#lines > 5, "The proposal is put in words")
    for _, line in ipairs(lines) do
        assert(line:sub(1, #Repricing.MARK) == Repricing.MARK, "Every line is marked provisional: " .. line)
    end
    assert(lines[1]:find("NOT applied", 1, true), "It says nothing was applied")
    assert(table.concat(lines, "\n"):find("067", 1, true), "It says what tuning waits on")
    print("✓ Lines provisional test passed")
end
-- }}}

-- {{{ TestSuite.test_calibrate
function TestSuite.test_calibrate()
    local field = small_field()
    local per_logit, steps, note = Repricing.calibrate(field[2], field, QUICK)
    assert(per_logit > 0 and #steps == 2, "Calibration gives points per log-odds")
    assert(steps[2].health == 100 and steps[2].points == 10, "Ten points of health is 100 health")
    assert(steps[1].battles == 2 * 2, "Each step fights every other template")
    if not note then
        assert(steps[2].win_rate > steps[1].win_rate, "More health wins more")
    end
    local fallback, _, why = Repricing.calibrate(field[2], field, {battles = 2, max_time = 30, calibration_battles = 2,
        calibration_points = {0, 0}})
    assert(fallback == Repricing.DEFAULTS.fallback_points_per_logit and why, "No spread in points falls back, with a note")
    print("✓ Calibrate test passed")
end
-- }}}

-- {{{ TestSuite.test_reproducible
function TestSuite.test_reproducible()
    local before = snapshot()
    local first = table.concat(Repricing.lines(Repricing.run(small_field(), QUICK)), "\n")
    local second = table.concat(Repricing.lines(Repricing.run(small_field(), QUICK)), "\n")
    assert(first == second, "The same seed gives the same proposal")
    local given = Repricing.run(small_field(), {battles = 2, max_time = 30, points_per_logit = 12})
    assert(given.calibration == nil and given.points_per_logit == 12, "A given points per log-odds skips calibration")
    assert(snapshot() == before, "A full run leaves the prices alone")
    print("✓ Reproducible test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running repricing tests...")
    TestSuite.test_logit()
    TestSuite.test_fit_direction()
    TestSuite.test_fit_limits()
    TestSuite.test_suggested_prices()
    TestSuite.test_lines_provisional()
    TestSuite.test_calibrate()
    TestSuite.test_reproducible()
    print("✅ All repricing tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
