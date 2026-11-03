-- {{{ Template Validation Test Suite
-- Checks issue 059 without a window: broken templates are refused with
-- messages that name the problem, the number and the fix; legal but odd
-- templates get warnings instead; the rules come from one configurable
-- file; new rules can be added; and validation is quick enough to run
-- on every keypress of an editor.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_template_validation').run_all()"
local TestSuite = {}

local UnitTemplate = require("src.data.unit_template")
local TemplateValidator = require("src.validators.template_validator")
local TemplateConstraints = require("src.data.template_constraints")
local TemplateManager = require("src.managers.template_manager")

-- {{{ local function find
local function find(list, text)
    for _, message in ipairs(list) do
        if message:find(text, 1, true) then
            return message
        end
    end
    return nil
end
-- }}}

-- {{{ local function template
local function template(data)
    data.name = data.name or "Tester"
    data.abilities = data.abilities or {"primary_melee_attack"}
    return UnitTemplate.new(data)
end
-- }}}

-- {{{ TestSuite.test_valid_template
function TestSuite.test_valid_template()
    local t = template({stats = {health = 160, armor = 8}, abilities = {"primary_melee_attack", "power_strike"}})
    assert(t.is_valid and #t.validation_errors == 0, "A sensible template passes: " .. table.concat(t.validation_errors, "; "))
    assert(#t.validation_warnings == 0, "With nothing to warn about: " .. table.concat(t.validation_warnings, "; "))
    print("✓ Valid template test passed")
end
-- }}}

-- {{{ TestSuite.test_names
function TestSuite.test_names()
    assert(find(template({name = "Ab"}).validation_errors, "too short (2 characters); use at least 3"), "Too short")
    assert(find(template({name = string.rep("x", 31)}).validation_errors, "too long (31 characters); use at most 30"),
        "Too long")
    assert(find(template({name = "Bad<name>"}).validation_errors, "contains \"<\""), "Bad characters are named")
    assert(find(template({name = "   "}).validation_errors, "must have a name"), "Blank names are refused")
    assert(template({name = "Ritz's Guard-2_b"}).is_valid, "Apostrophes, hyphens, digits and underscores are fine")
    assert(find(template({description = string.rep("d", 201)}).validation_errors, "Description is too long"),
        "Long descriptions are refused")
    print("✓ Name rules test passed")
end
-- }}}

-- {{{ TestSuite.test_stats
function TestSuite.test_stats()
    local t = template({stats = {health = 20, speed = 900}})
    assert(find(t.validation_errors, "health 20 is below the minimum of 50; raise it"), "Low health is named with the fix")
    assert(find(t.validation_errors, "speed 900 is above the maximum of 150; lower it"), "High speed too")
    local nan = template({stats = {armor = "lots"}})
    assert(find(nan.validation_errors, "armor must be a number"), "Stats must be numbers")
    local odd = template({unit_type = "dragon"})
    assert(find(odd.validation_errors, "choose one of melee, ranged, special, support, tank"), "Bodies are listed")
    local frail = template({stats = {health = 55}})
    assert(frail.is_valid and find(frail.validation_warnings, "health 55 is very low (usual range 60-300)"),
        "Legal but odd stats only warn")
    print("✓ Stat rules test passed")
end
-- }}}

-- {{{ TestSuite.test_abilities
function TestSuite.test_abilities()
    local none = template({abilities = {}})
    assert(find(none.validation_errors, "Needs at least 1 ability"), "No abilities")
    local five = template({point_budget = 1000,
        abilities = {"primary_melee_attack", "power_strike", "battle_fury", "focus", "minor_heal"}})
    assert(find(five.validation_errors, "Has 5 abilities; remove 1 to get to the limit of 4"), "Too many, with the fix")

    local far = template({abilities = {{template = "primary_melee_attack", changes = {range = 300}}}, point_budget = 1000})
    assert(find(far.validation_errors, "Ability 1 (primary_melee_attack): range 300 is over the limit of 100; lower it"),
        "Over-long reach is named by ability")
    local strong = template({abilities = {{type = "damage", name = "Nuke", power = 500}}, point_budget = 10000})
    assert(find(strong.validation_errors, "Ability 1 (Nuke): power 500 is over the limit of 200"), "Over-strong power")
    local no_duration = template({abilities = {"primary_melee_attack", {template = "battle_fury", changes = {duration = 0}}}})
    assert(no_duration.is_valid, "A buff with no duration takes the kind's 5-second default")
    local long = template({abilities = {"primary_melee_attack", {template = "battle_fury", changes = {duration = 90}}},
        point_budget = 10000})
    assert(find(long.validation_errors, "duration 90 is over the limit of 30"), "And not too long a one")
    local wide = template({abilities = {"primary_melee_attack", {template = "meteor_strike", changes = {area_radius = 80}}},
        point_budget = 10000})
    assert(find(wide.validation_errors, "area_radius 80 is over the limit of 50"), "Area size is capped")
    local feeble = template({abilities = {{type = "damage", name = "Poke", power = 0}}})
    assert(find(feeble.validation_errors, "a damage ability needs power above 0"), "Damage needs power")
    local stalled = template({abilities = {{type = "damage", name = "Stall", mana_rate = 0.1}}})
    assert(find(stalled.validation_errors, "mana_rate 0.1 is below 1"), "A bar that never fills is refused")
    local buff_first = template({abilities = {"battle_fury"}})
    assert(find(buff_first.validation_errors, "the first ability is the primary and must deal damage or heal"),
        "The primary must attack or heal")
    local typo = template({abilities = {"primery_melee_attack"}})
    assert(find(typo.validation_errors, "Ability 1 (primery_melee_attack) can't be built: unknown ability template"),
        "Unknown templates are named")
    print("✓ Ability rules test passed")
end
-- }}}

-- {{{ TestSuite.test_budget
function TestSuite.test_budget()
    local rich = template({stats = {health = 500, armor = 40}})
    assert(find(rich.validation_errors, "of a 100 budget; remove"), "Over budget names how much to remove")
    local cheap = template({})
    assert(cheap.is_valid and find(cheap.validation_warnings, "Uses only 10 of 100 points; it may be underpowered"),
        "Spending little is legal but warned")
    print("✓ Budget rules test passed")
end
-- }}}

-- {{{ TestSuite.test_warnings
function TestSuite.test_warnings()
    local spread = template({abilities = {"primary_melee_attack", "crippling_blow", "stunning_bash", "sunder_armor"},
        unit_type = "tank", point_budget = 200})
    assert(spread.is_valid and find(spread.validation_warnings, "3 debuff abilities"), "Three of a kind warns")
    local twice = template({abilities = {"primary_melee_attack", "power_strike", "power_strike"}, point_budget = 300})
    assert(twice.is_valid and find(twice.validation_warnings, "repeats ability 2"), "A repeated ability warns")
    local sniper = template({unit_type = "melee", abilities = {"primary_melee_attack", "piercing_shot"}})
    assert(find(sniper.validation_warnings, "reaches 40 on a melee body"), "Long reach on a melee body warns")
    local armored = template({unit_type = "ranged", stats = {armor = 15}, abilities = {"primary_ranged_attack"}})
    assert(find(armored.validation_warnings, "armor 15 is unusual for a ranged body"), "Heavy armor on a ranged body warns")
    print("✓ Warnings test passed")
end
-- }}}

-- {{{ TestSuite.test_configurable
function TestSuite.test_configurable()
    -- A stricter copy of the constraints, with nothing else changed.
    local strict = {}
    for key, value in pairs(TemplateConstraints) do
        strict[key] = value
    end
    strict.abilities = {}
    for key, value in pairs(TemplateConstraints.abilities) do
        strict.abilities[key] = value
    end
    strict.abilities.max_count = 1
    local validator = TemplateValidator:new(strict)
    local t = template({abilities = {"primary_melee_attack", "power_strike"}})
    assert(t.is_valid, "Two abilities pass the usual rules")
    local ok, errors = t:validate(validator)
    assert(not ok and find(errors, "limit of 1"), "And fail the stricter ones")
    assert(not t.is_valid, "The template remembers the last verdict")

    validator:add_rule("no_dragons", true, function(_, tpl, add)
        if tpl.name:lower():find("dragon") then
            add("Dragons are not allowed in this mode")
        end
    end)
    local ok2, findings = validator:validate_detailed(template({name = "Dragon"}))
    assert(not ok2, "An added rule can refuse a template")
    local rules = {}
    for _, finding in ipairs(findings) do
        rules[finding.rule] = finding.critical
    end
    assert(rules.no_dragons == true and rules.budget_use == false, "Findings name their rule and weight")
    print("✓ Configurable rules test passed")
end
-- }}}

-- {{{ TestSuite.test_defaults_valid
function TestSuite.test_defaults_valid()
    for _, data in ipairs(TemplateManager.default_template_data()) do
        local t = UnitTemplate.new(data)
        assert(t.is_valid, data.name .. " is valid: " .. table.concat(t.validation_errors, "; "))
    end
    print("✓ Defaults valid test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local t = template({stats = {health = 160}, abilities = {"primary_melee_attack", "power_strike", "battle_fury",
        "meteor_strike"}, point_budget = 300})
    local start = os.clock()
    for _ = 1, 1000 do
        t:validate()
    end
    local elapsed = os.clock() - start
    print(string.format("  1000 validations of a four-ability template: %.3fs", elapsed))
    assert(elapsed < 2.0, "Fast enough to run as a player edits")
    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.test_reachable_triggers
-- An ability whose trigger its body can never meet earns a warning that
-- names the trigger, and no default template has one.
function TestSuite.test_reachable_triggers()
    local factory = require("src.factories.ability_factory")
    local cannon = template({unit_type = "ranged", abilities = {"javelin_attack", "power_strike"}})
    assert(cannon.is_valid, "An unreachable trigger is a warning, not an error")
    assert(find(cannon.validation_warnings, "ranged body backs away from enemies nearer than 20"),
        "A melee-reach trigger on a ranged body warns")
    assert(find(cannon.validation_warnings, "rarely if ever fire"), "And says it may still fire when cornered")
    assert(not find(template({unit_type = "melee", abilities = {"primary_melee_attack", "power_strike"}})
        .validation_warnings, "never fire"), "The same ability on a melee body is fine")
    assert(not find(template({unit_type = "ranged", abilities = {"javelin_attack", "piercing_shot"}})
        .validation_warnings, "fire. Pick"), "A ranged trigger on a ranged body is fine")

    local function with_condition(unit_type, condition)
        local config = factory.create_config("focus", {generation_conditions = {condition}})
        return template({unit_type = unit_type, abilities = {"primary_melee_attack", config}})
    end
    assert(find(with_condition("melee", {type = "combat_state", value = "combat"}).validation_warnings,
        "combat state \"combat\", which no system sets for a melee body; it will never fire"),
        "A combat state nothing sets warns")
    assert(find(with_condition("melee", {type = "combat_state", value = "firing"}).validation_warnings,
        "never fire"), "A ranged-only combat state warns on a melee body")
    assert(not find(with_condition("ranged", {type = "combat_state", value = "firing"}).validation_warnings,
        "never fire"), "But not on a ranged body")
    assert(find(with_condition("tank", {type = "unit_type", value = "support"}).validation_warnings,
        "needs a support body, but this is a tank body"), "A trigger for another body warns")
    assert(find(with_condition("melee", {type = "enemies_nearby"}).validation_warnings,
        "unknown condition \"enemies_nearby\""), "A misspelt trigger warns")
    assert(not find(with_condition("ranged", {type = "enemies_in_range", operator = ">", value = 0, range = 40})
        .validation_warnings, "fire. Pick"), "An enemy trigger past the keep-away distance is fine")

    local manager = TemplateManager:new()
    for name, t in pairs(manager:create_default_templates()) do
        assert(not find(t.validation_warnings, "fire. Pick"), name .. " has no ability that can't fire")
    end
    print("✓ Reachable triggers test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running template validation tests...")
    TestSuite.test_valid_template()
    TestSuite.test_names()
    TestSuite.test_stats()
    TestSuite.test_abilities()
    TestSuite.test_budget()
    TestSuite.test_warnings()
    TestSuite.test_configurable()
    TestSuite.test_defaults_valid()
    TestSuite.test_reachable_triggers()
    TestSuite.test_performance()
    print("✅ All template validation tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
