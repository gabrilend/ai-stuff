-- {{{ Unit Templates Test Suite
-- Checks issue 057 without a window: templates take their body's stats,
-- price stats and abilities in points, refuse what's over budget or
-- broken, survive a save and load, build real units with abilities, and
-- the manager keeps them by name with a valid default for every set.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_unit_templates').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local TemplateManager = require("src.managers.template_manager")
local AbilityFactory = require("src.factories.ability_factory")
local AbilityTemplates = require("src.data.ability_templates")
local AbilityBalance = require("src.testing.ability_balance")

-- {{{ local function has_error
local function has_error(template, text)
    for _, message in ipairs(template.validation_errors) do
        if message:find(text, 1, true) then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ TestSuite.test_defaults_from_body
function TestSuite.test_defaults_from_body()
    local tank = UnitTemplate.new({name = "Wall", unit_type = "tank", abilities = {"primary_melee_attack"}})
    assert(tank.stats.health == 200 and tank.stats.speed == 30 and tank.stats.armor == 5, "A tank starts with a tank's stats")
    assert(tank.appearance.shape == "rectangle", "And a tank's shape")
    assert(tank.breakdown.body == 10, "Choosing a tank costs 10")
    assert(tank.points_used == 20, "Body and sword: " .. tank.points_used)
    assert(tank.is_valid, "It's valid")
    print("✓ Body defaults test passed")
end
-- }}}

-- {{{ TestSuite.test_stat_costs
function TestSuite.test_stat_costs()
    local t = UnitTemplate.new({name = "Tough", unit_type = "melee", abilities = {"primary_melee_attack"},
        stats = {health = 170, speed = 70, armor = 4, magic_resist = 1, detection_range = 100}})
    local b = t.breakdown.stats
    assert(b.health == 5, "50 health over the body's 120 is 5 points")
    assert(b.speed == 2, "10 speed over 60 is 2 points")
    assert(b.armor == 6, "4 armor is 6 points")
    assert(b.magic_resist == 2, "1 magic resist rounds up to 2 points")
    assert(b.detection_range == 2, "40 range over 60 is 2 points")
    assert(t.points_used == 5 + 2 + 6 + 2 + 2 + 10, "Stats plus the sword")

    local slow = UnitTemplate.new({name = "Slow", unit_type = "melee", abilities = {"primary_melee_attack"},
        stats = {speed = 20, health = 60}})
    assert(slow.breakdown.stats.speed == 0 and slow.breakdown.stats.health == 0, "Lowering a stat gives no points back")
    print("✓ Stat cost test passed")
end
-- }}}

-- {{{ TestSuite.test_ability_costs
function TestSuite.test_ability_costs()
    local cost = function(name, primary)
        return UnitTemplate.ability_cost(AbilityFactory.create(name), primary)
    end
    assert(cost("primary_melee_attack", true) == 10, "The sword is the reference: 10 as a primary")
    assert(cost("primary_melee_attack", false) == 20, "And 20 as a secondary")
    assert(cost("power_strike", false) > cost("primary_melee_attack", false), "A harder hit costs more")
    assert(cost("piercing_shot", false) > UnitTemplate.ability_cost(AbilityFactory.create("piercing_shot", {pierce = 1}), false),
        "Piercing costs extra")
    assert(cost("axe_attack", true) > UnitTemplate.ability_cost(AbilityFactory.create("axe_attack", {cleave_targets = 0}), true),
        "Cleave costs extra")
    assert(UnitTemplate.ability_cost(AbilityFactory.create("primary_melee_attack", {range = 40}), true) == 15,
        "Reach past 15 costs 1 per 5")
    local slow_meteor = UnitTemplate.ability_cost(AbilityFactory.create("meteor_strike", {cooldown = 60}), false)
    assert(slow_meteor < cost("meteor_strike", false), "A long cooldown makes it cheaper")
    assert(cost("battle_fury", false) == 21, "Battle fury is the buff reference (20) plus 1 for its reach of 20")
    assert(cost("static_field", false) > UnitTemplate.ability_cost(AbilityFactory.create("static_field", {zone_duration = 0}), false),
        "A lasting zone costs extra")
    print("✓ Ability cost test passed")
end
-- }}}

-- {{{ TestSuite.test_validation
function TestSuite.test_validation()
    local rich = UnitTemplate.new({name = "Greedy", unit_type = "melee", stats = {health = 500, armor = 40},
        abilities = {"primary_melee_attack"}})
    assert(not rich.is_valid and has_error(rich, "Exceeds point budget"), "Over budget is refused")
    assert(rich:points_left() < 0, "Points left goes negative")

    local none = UnitTemplate.new({name = "Empty", abilities = {}})
    assert(has_error(none, "at least 1 ability"), "No abilities is refused")
    local many = UnitTemplate.new({name = "Busy", point_budget = 1000,
        abilities = {"primary_melee_attack", "power_strike", "battle_fury", "focus", "minor_heal"}})
    assert(has_error(many, "more than 4"), "Five abilities is refused")

    local unknown = UnitTemplate.new({name = "Typo", abilities = {"primery_melee_attack"}})
    assert(has_error(unknown, "unknown ability template"), "An unknown ability template is named")
    local broken = UnitTemplate.new({name = "Broken", abilities = {{type = "damage", max_mana = 0}}})
    assert(has_error(broken, "Ability 1"), "An ability that can't be built is refused")
    local buff_first = UnitTemplate.new({name = "Buffer", abilities = {"battle_fury", "primary_melee_attack"}})
    assert(has_error(buff_first, "primary"), "The first ability must deal damage or heal")

    local odd = UnitTemplate.new({name = "Odd", unit_type = "dragon", abilities = {"primary_melee_attack"}})
    assert(has_error(odd, "Unknown unit type"), "Unknown bodies are refused")
    local frail = UnitTemplate.new({name = "Frail", stats = {health = 10}, abilities = {"primary_melee_attack"}})
    assert(has_error(frail, "health must be"), "Stats outside their range are refused")
    local nameless = UnitTemplate.new({name = "", abilities = {"primary_melee_attack"}})
    assert(has_error(nameless, "name"), "A name is needed")
    print("✓ Validation test passed")
end
-- }}}

-- {{{ TestSuite.test_save_and_load
function TestSuite.test_save_and_load()
    local original = UnitTemplate.new({name = "Saved", description = "kept", unit_type = "ranged",
        stats = {speed = 55}, appearance = {primary_color = {0, 1, 0}, size_modifier = 1.2},
        abilities = {"primary_ranged_attack", {template = "power_strike", changes = {range = 25}},
            {type = "heal", power = 20, range = 20}}})
    local data = original:to_save_data()
    assert(getmetatable(data) == nil, "Save data is a plain table")
    data.stats.speed = 999   -- changing the copy mustn't change the template
    assert(original.stats.speed == 55, "Save data is a copy")
    data.stats.speed = 55

    local loaded = UnitTemplate.from_save_data(data)
    assert(loaded.name == "Saved" and loaded.description == "kept" and loaded.unit_type == "ranged", "Basic fields return")
    assert(loaded.stats.speed == 55 and loaded.appearance.size_modifier == 1.2, "Stats and looks return")
    assert(loaded.points_used == original.points_used, "The cost is the same")
    local config = loaded:ability_config(2)
    assert(config.name == "power_strike" and config.range == 25, "Template abilities keep their changes")
    assert(loaded:ability_config(3).type == "heal", "Whole configs return")
    assert(loaded.is_valid == original.is_valid, "As valid as before")
    print("✓ Save and load test passed")
end
-- }}}

-- {{{ TestSuite.test_create_unit
function TestSuite.test_create_unit()
    local em = EntityManager:new()
    local template = UnitTemplate.new({name = "Guard", unit_type = "melee", stats = {health = 150, armor = 6, speed = 65},
        appearance = {size_modifier = 1.5}, abilities = {"primary_melee_attack", "power_strike"}})
    local unit = template:create_unit(em, 10, 20, 2)
    local health = em:get_component(unit, "health")
    assert(health.max_hp == 150 and health.current_hp == 150, "The template's health")
    assert(em:get_component(unit, "moveable").speed == 65, "Its speed")
    assert(em:get_component(unit, "stats").armor == 6, "Its armor")
    assert(em:get_component(unit, "team").player_id == 2, "On the given team")
    assert(em:get_component(unit, "unit_data").template_name == "Guard", "It remembers its template")
    assert(em:get_component(unit, "renderable").size == 12, "Size times the modifier")
    local abilities = em:get_component(unit, "abilities")
    assert(#abilities.abilities == 2 and abilities.abilities[2].name == "power_strike", "With its abilities")
    assert(#em:get_component(unit, "mana").bars == 2, "And a mana bar each")

    local bad = UnitTemplate.new({name = "Bad", abilities = {}})
    assert(not pcall(bad.create_unit, bad, em, 0, 0, 1), "An invalid template builds nothing")
    print("✓ Create unit test passed")
end
-- }}}

-- {{{ TestSuite.test_manager
function TestSuite.test_manager()
    local manager = TemplateManager:new()
    local defaults = manager:create_default_templates()
    local count = 0
    for _ in pairs(AbilityTemplates.sets) do
        count = count + 1
    end
    assert(#manager:list() == count, "A default for every ability set")
    for name, template in pairs(defaults) do
        assert(template.is_valid, name .. " is valid")
        assert(template.points_used <= TemplateCosts.default_point_budget, name .. " fits the budget")
        assert(manager:is_default(name), name .. " is marked default")
    end
    assert(manager:get_template("Warrior").unit_type == "melee", "Found by name")

    local ok = manager:register_template({name = "Mine", abilities = {"dagger_attack"}})
    assert(ok and manager:get_template("Mine"), "Data can be registered directly")
    assert(not manager:is_default("Mine"), "A player's template isn't a default")
    local refused, errors = manager:register_template(UnitTemplate.new({name = "Nope", abilities = {}}))
    assert(not refused and #errors > 0 and not manager:get_template("Nope"), "Invalid templates are refused with reasons")
    assert(manager:remove_template("Mine") and not manager:get_template("Mine"), "Templates can be removed")
    assert(not manager:remove_template("Mine"), "Removing twice says so")
    print("✓ Template manager test passed")
end
-- }}}

-- {{{ TestSuite.test_templates_fight
-- Units built from two default templates fight in the balance harness's
-- world.
function TestSuite.test_templates_fight()
    local manager = TemplateManager:new()
    manager:create_default_templates()
    local world = AbilityBalance.new_world(11)
    for i = 1, 3 do
        local a = manager:get_template("Warrior"):create_unit(world.em, 0, i * 10, 1)
        local b = manager:get_template("Archer"):create_unit(world.em, 50, i * 10, 2)
        table.insert(world.units[1], a)
        table.insert(world.units[2], b)
        world.reach[a] = 15
        world.reach[b] = 30
    end
    for _ = 1, 300 do
        AbilityBalance.step(world, 0.1)
    end
    assert(world.activation.stats.activations > 0, "Template units use their abilities")
    assert(world.damage_by_team[1] > 0 and world.damage_by_team[2] > 0, "Both sides deal damage")
    print("✓ Templates fight test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running unit template tests...")
    TestSuite.test_defaults_from_body()
    TestSuite.test_stat_costs()
    TestSuite.test_ability_costs()
    TestSuite.test_validation()
    TestSuite.test_save_and_load()
    TestSuite.test_create_unit()
    TestSuite.test_manager()
    TestSuite.test_templates_fight()
    print("✅ All unit template tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
