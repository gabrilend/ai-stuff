-- {{{ Template Preview Test Suite
-- Checks the logic of issue 066 without a window: the analysis agrees
-- with the damage rules and the prices, simulations run against one
-- opponent of each body and repeat exactly, comparisons name every
-- difference, and the view's state (mode, zoom, overlays) and caches
-- behave.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_template_preview').run_all()"
local TestSuite = {}

local TemplatePreview = require("src.editor.template_preview")
local UnitTemplate = require("src.data.unit_template")
local TemplateManager = require("src.managers.template_manager")
local DamageAbility = require("src.components.abilities.damage_ability")

local defaults = TemplateManager:new():create_default_templates()

-- {{{ TestSuite.test_analysis
function TestSuite.test_analysis()
    local warrior = defaults["Warrior"]
    local analysis = TemplatePreview.analyze(warrior)
    local survival = analysis.survival
    -- The damage rule: armor A lets through 100 / (100 + A) of a hit.
    local hit = DamageAbility.reduce(100, "physical", 0, {armor = warrior.stats.armor})
    assert(math.abs(survival.effective_health_physical - warrior.stats.health * 100 / hit) < 1e-6,
        "Effective health follows the armor rule")
    assert(survival.effective_health_magical == warrior.stats.health * (1 + warrior.stats.magic_resist / 100),
        "And the magic resist rule")
    assert(#analysis.abilities == 2 and analysis.abilities[1].role == "primary", "Every ability, primary first")
    local sword = analysis.abilities[1]
    assert(sword.per_cast == 25 and math.abs(sword.cycle - 10) < 1e-9, "The sword: 25 a cast, every 10 seconds")
    assert(math.abs(sword.per_second - 2.5) < 1e-9, "So 2.5 a second")
    assert(analysis.abilities[2].conditional, "Power strike waits on a trigger")
    local total = 0
    for _, row in ipairs(analysis.abilities) do
        total = total + (row.per_second or 0)
    end
    assert(math.abs(analysis.offense.damage_per_second - total) < 1e-9, "Damage a second adds up")
    assert(analysis.offense.reach == 15 and analysis.offense.primary_reach == 15, "Reach")

    local cleric = TemplatePreview.analyze(defaults["Cleric"])
    assert(cleric.offense.healing_per_second > 0 and cleric.support.buffs == 1, "Healing and buffs are counted")
    local mage = TemplatePreview.analyze(defaults["Battle Mage"])
    assert(mage.kinds.area == 1 and mage.offense.reach == 45, "Area damage and its reach")
    local storm = TemplatePreview.analyze(defaults["Storm Caller"])
    assert(storm.kinds.over_time >= 1 and storm.kinds.crowd_control >= 1, "Zones slow and burn over time")
    local axe = TemplatePreview.analyze(defaults["Berserker"])
    assert(axe.kinds.cleave == 1 and axe.abilities[1].targets > 1, "Cleaving reaches more than one")
    local broken = TemplatePreview.analyze(UnitTemplate.new({name = "Broken", abilities = {"primary_melee_attack",
        "no_such_ability"}}))
    assert(#broken.abilities == 1, "Abilities that can't be built are left out")
    print("✓ Analysis test passed")
end
-- }}}

-- {{{ TestSuite.test_simulation
function TestSuite.test_simulation()
    local options = {battles = 2, max_time = 30}
    local result = TemplatePreview.simulate(defaults["Warrior"], options)
    local bodies = {}
    for _, row in ipairs(result.rows) do
        bodies[row.body] = true
        assert(row.wins + row.losses + row.draws == 2, row.opponent .. ": every battle is counted")
        assert(row.low <= row.win_rate and row.win_rate <= row.high, row.opponent .. ": rate inside its interval")
    end
    for _, body in ipairs({"melee", "ranged", "tank", "support", "special"}) do
        assert(bodies[body], "An opponent with a " .. body .. " body")
    end
    assert(result.overall.battles == 2 * #result.rows, "The overall counts every battle")
    assert(result.note:find("don't read them as real match odds", 1, true), "Says what the numbers are not")
    local again = TemplatePreview.simulate(defaults["Warrior"], options)
    for index, row in ipairs(result.rows) do
        assert(again.rows[index].win_rate == row.win_rate and again.rows[index].average_time == row.average_time,
            "The same seed gives the same battles")
    end
    local one = TemplatePreview.simulate(defaults["Warrior"], {battles = 2, max_time = 30,
        opponents = {defaults["Fortress"]}})
    assert(#one.rows == 1 and one.rows[1].opponent == "Fortress", "Opponents can be chosen")
    print("✓ Simulation test passed")
end
-- }}}

-- {{{ TestSuite.test_compare
function TestSuite.test_compare()
    local result = TemplatePreview.compare(defaults["Warrior"], defaults["Berserker"])
    assert(result.a == "Warrior" and result.b == "Berserker", "Names")
    assert(result.points.diff == defaults["Berserker"].points_used - defaults["Warrior"].points_used, "Points")
    local health
    for _, row in ipairs(result.stats) do
        if row.stat == "health" then
            health = row
        end
    end
    assert(health.diff == 50, "Stat differences")
    assert(table.concat(result.abilities.added, ",") == "axe_attack,battle_fury", "Abilities only b has")
    assert(table.concat(result.abilities.removed, ",") == "primary_melee_attack,power_strike", "Only a has")
    local text = table.concat(result.lines, "\n")
    assert(text:find("Berserker has +50 health (170 against 120)", 1, true), "In words")
    assert(text:find("damage a second", 1, true) and text:find("costs -6 points", 1, true), "Analysis and points")
    local same = TemplatePreview.compare(defaults["Warrior"], defaults["Warrior"])
    assert(#same.lines == 0 and #same.abilities.shared == 2, "A template against itself has nothing to say")
    local bodies = TemplatePreview.compare(defaults["Warrior"], defaults["Archer"])
    assert(bodies.lines[1]:find("ranged body", 1, true), "A different body comes first")
    print("✓ Compare test passed")
end
-- }}}

-- {{{ TestSuite.test_view_state
function TestSuite.test_view_state()
    local preview = TemplatePreview:new()
    assert(preview.mode == "visual" and preview:set_mode("combat") and preview.mode == "combat", "Modes")
    assert(preview:set_mode("cinema") == false and preview.mode == "combat", "Unknown modes are refused")
    for _ = 1, 20 do
        preview:zoom_by(1)
    end
    assert(preview.zoom == TemplatePreview.ZOOM.max, "Zoom stops at its limit")
    for _ = 1, 20 do
        preview:zoom_by(-1)
    end
    assert(preview.zoom == TemplatePreview.ZOOM.min, "Both ways")
    preview.zoom = 1
    local mage = defaults["Battle Mage"]
    local shapes = preview:overlay_shapes(mage)
    assert(#shapes.circles == 1 + #mage.abilities, "A sight circle and one per ability")
    assert(shapes.circles[1].radius == mage.stats.detection_range * TemplatePreview.RANGE_SCALE, "Sight radius")
    assert(shapes.unit.size == TemplatePreview.UNIT_SIZE * mage.appearance.size_modifier, "Unit size")
    assert(preview:toggle("ranges") == false, "Overlays toggle")
    assert(#preview:overlay_shapes(mage).circles == 1, "And their circles go")
    preview:zoom_by(1)
    assert(math.abs(preview:overlay_shapes(mage).circles[1].radius - shapes.circles[1].radius * 1.25) < 1e-9,
        "Zoom scales the shapes")
    assert(preview:toggle("x-ray") == nil, "Unknown overlays are refused")
    print("✓ View state test passed")
end
-- }}}

-- {{{ TestSuite.test_caching
function TestSuite.test_caching()
    local preview = TemplatePreview:new()
    local template = defaults["Warrior"]
    local first = preview:update(template)
    for _ = 1, 50 do
        assert(preview:update(template) == first, "No change, no new analysis")
    end
    assert(preview.stats.analyses == 1, "Worked out once")
    local data = template:to_save_data()
    data.stats.armor = 9
    local changed = preview:update(UnitTemplate.new(data))
    assert(changed ~= first and preview.stats.analyses == 2, "A change is noticed")
    assert(TemplatePreview.signature(template) == TemplatePreview.signature(UnitTemplate.new(template:to_save_data())),
        "Equal templates share a signature")
    local options = {battles = 1, max_time = 20, opponents = {defaults["Archer"]}}
    local sim = preview:simulation(template, options)
    assert(preview:simulation(template, options) == sim and preview.stats.simulations == 1, "Simulations are cached")
    local start = os.clock()
    for i = 1, 200 do
        data.stats.health = 120 + (i % 10) * 10
        preview:update(UnitTemplate.new(data))
    end
    local seconds = os.clock() - start
    assert(seconds < 5, string.format("200 edits take %.2f s", seconds))
    print(string.format("✓ Caching test passed (%.2f s)", seconds))
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running template preview tests...")
    TestSuite.test_analysis()
    TestSuite.test_simulation()
    TestSuite.test_compare()
    TestSuite.test_view_state()
    TestSuite.test_caching()
    print("✅ All template preview tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
