-- {{{ Default Templates Test Suite
-- Checks issue 061 without a window: every default template is valid and
-- within budget, draws only the warnings it is meant to, the sets cover
-- every archetype, body and ability, the guide in docs/ matches the data,
-- the defaults save and load, and they fight real battles.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_default_templates').run_all()"
local TestSuite = {}

local DefaultTemplates = require("src.data.default_templates")
local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local TemplateManager = require("src.managers.template_manager")
local TemplateStorage = require("src.storage.template_storage")
local FileBackends = require("src.storage.file_backends")
local TemplateDocumentation = require("src.utils.template_documentation")
local AbilityTemplates = require("src.data.ability_templates")
local AbilityBalance = require("src.testing.ability_balance")

-- {{{ local function all_templates
local function all_templates()
    local list = {}
    for _, data in ipairs(DefaultTemplates.data()) do
        table.insert(list, {data = data, template = UnitTemplate.new(data)})
    end
    return list
end
-- }}}

-- {{{ TestSuite.test_all_valid
function TestSuite.test_all_valid()
    local names = {}
    for _, row in ipairs(all_templates()) do
        local t, data = row.template, row.data
        assert(t.is_valid, t.name .. " is valid: " .. table.concat(t.validation_errors, "; "))
        assert(t.points_used <= TemplateCosts.default_point_budget, t.name .. " fits the budget")
        assert(not names[t.name], t.name .. " is the only template of its name")
        names[t.name] = true
        assert(data.description and data.strategy and data.archetype, t.name .. " is described for the guide")
    end
    print("✓ All valid test passed")
end
-- }}}

-- {{{ TestSuite.test_only_expected_warnings
function TestSuite.test_only_expected_warnings()
    for _, row in ipairs(all_templates()) do
        local t, expected = row.template, row.data.expected_warnings or {}
        for _, warning in ipairs(t.validation_warnings) do
            local known = false
            for _, text in ipairs(expected) do
                if warning:find(text, 1, true) then
                    known = true
                end
            end
            assert(known, t.name .. " has an unexpected warning: " .. warning)
        end
        for _, text in ipairs(expected) do
            local found = false
            for _, warning in ipairs(t.validation_warnings) do
                if warning:find(text, 1, true) then
                    found = true
                end
            end
            assert(found, t.name .. " should warn about: " .. text)
        end
        if row.data.set == "experimental" then
            assert(#t.validation_warnings > 0, t.name .. " is experimental, so it warns")
        end
    end
    print("✓ Expected warnings test passed")
end
-- }}}

-- {{{ TestSuite.test_coverage
function TestSuite.test_coverage()
    local archetypes, bodies, abilities, sets = {}, {}, {}, {}
    local counts = {}
    for _, row in ipairs(all_templates()) do
        local t = row.template
        archetypes[row.data.archetype] = true
        bodies[t.unit_type] = true
        sets[row.data.set] = true
        counts[#t.abilities] = true
        for index = 1, #t.abilities do
            abilities[t:ability_config(index).name] = true
        end
    end
    for _, archetype in ipairs({"tank", "damage", "ranged_damage", "support", "crowd_control", "hybrid", "speed",
            "glass_cannon"}) do
        assert(archetypes[archetype], "An example of the " .. archetype .. " archetype")
        assert(DefaultTemplates.by_archetype(archetype).archetype == archetype, "Found by archetype")
    end
    for body in pairs(TemplateCosts.bodies) do
        assert(bodies[body], "An example of the " .. body .. " body")
    end
    for name in pairs(AbilityTemplates.abilities) do
        assert(abilities[name], "Some default uses " .. name)
    end
    for _, set in ipairs(DefaultTemplates.SET_ORDER) do
        assert(sets[set], "The " .. set .. " set has templates")
    end
    assert(counts[2] and counts[3] and counts[4], "Templates with two, three and four abilities")
    assert(DefaultTemplates.by_archetype("dragon") == nil, "Unknown archetypes find nothing")
    assert(not pcall(DefaultTemplates.data, {"secret"}), "Unknown sets are refused")
    print("✓ Coverage test passed")
end
-- }}}

-- {{{ TestSuite.test_guide_up_to_date
function TestSuite.test_guide_up_to_date()
    local file = io.open("docs/default-templates.md", "rb")
    assert(file, "docs/default-templates.md exists")
    local written = file:read("*a")
    file:close()
    local fresh = TemplateDocumentation.generate_guide()
    assert(written == fresh, "docs/default-templates.md matches the data; run ./run <dir> template-docs")
    for _, data in ipairs(DefaultTemplates.data()) do
        assert(fresh:find("### " .. data.name, 1, true), data.name .. " is in the guide")
    end
    print("✓ Guide up to date test passed")
end
-- }}}

-- {{{ TestSuite.test_store_and_reload
function TestSuite.test_store_and_reload()
    local storage = TemplateStorage:new({backend = FileBackends.memory()})
    local manager = TemplateManager:new()
    local made = manager:create_default_templates()
    local saved = manager:save_to_storage(storage)
    assert(saved == #DefaultTemplates.data(), "Every default is saved")
    local fresh = TemplateManager:new()
    fresh:load_from_storage(storage, "default")
    for name, template in pairs(made) do
        assert(fresh:get_template(name).points_used == template.points_used, name .. " comes back the same")
        assert(template.default_set and template.archetype, name .. " knows its set and archetype")
    end
    print("✓ Store and reload test passed")
end
-- }}}

-- {{{ TestSuite.test_defaults_fight
function TestSuite.test_defaults_fight()
    local manager = TemplateManager:new()
    manager:create_default_templates()
    local get = function(name) return manager:get_template(name) end
    local battle = AbilityBalance.run_battle({team_a = {get("Heavy Knight"), get("Sniper"), get("Battle Cleric")},
        team_b = {get("Assassin"), get("Frost Mage"), get("Spearman")}, seed = 4, max_time = 40})
    assert(battle.damage[1] > 0 and battle.damage[2] > 0, "Both sides of default templates fight")
    assert(battle.activations > 0, "Their abilities fire")
    local round = AbilityBalance.round_robin({get("Warrior"), get("Archer"), get("Fortress")}, {battles = 2, seed = 2,
        max_time = 30})
    assert(round.overall["Warrior"] and round.overall["Fortress"].battles == 4, "Templates can enter a round robin")
    print("✓ Defaults fight test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running default template tests...")
    TestSuite.test_all_valid()
    TestSuite.test_only_expected_warnings()
    TestSuite.test_coverage()
    TestSuite.test_guide_up_to_date()
    TestSuite.test_store_and_reload()
    TestSuite.test_defaults_fight()
    print("✅ All default template tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
