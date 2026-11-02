-- {{{ Ability Selection Test Suite
-- Checks issue 064 without a window: the ability library covers every
-- ability the game runs, search and filters find the right ones, tuning
-- is held to limits and priced exactly as templates are charged, and the
-- selector's flow (slot, choose, tune, preview, apply, clear, custom)
-- keeps the template valid.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_ability_selection').run_all()"
local TestSuite = {}

local AbilityLibrary = require("src.data.ability_library")
local AbilitySelector = require("src.editor.ability_selector")
local AbilityTemplates = require("src.data.ability_templates")
local AbilityFactory = require("src.factories.ability_factory")
local UnitTemplate = require("src.data.unit_template")
local TemplateConstraints = require("src.data.template_constraints")

local library = AbilityLibrary:new()

-- {{{ local function ids
local function ids(entries)
    local list = {}
    for index, entry in ipairs(entries) do
        list[index] = entry.id
    end
    return list
end
-- }}}

-- {{{ local function contains
local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ local function warrior
local function warrior()
    return UnitTemplate.new({name = "Test Warrior", unit_type = "melee",
        abilities = {"primary_melee_attack", "power_strike"}})
end
-- }}}

-- {{{ TestSuite.test_library_coverage
function TestSuite.test_library_coverage()
    local count = 0
    for name in pairs(AbilityTemplates.abilities) do
        local entry = library:get(name)
        assert(entry, name .. " is in the library")
        assert(entry.description ~= "", name .. " is described")
        assert(#entry.customizable > 0, name .. " can be tuned")
        count = count + 1
    end
    assert(#library.order == count, "The library holds every ability once")
    local categories = library:categories()
    assert(table.concat(categories, ",") == "area,buff,damage,debuff,heal", "Every kind is a category")
    assert(library:get("meteor_strike").subcategory == "burst", "Meteor strike is a burst")
    assert(library:get("static_field").subcategory == "zone", "Static field is a zone")
    assert(library:get("poison_dart").subcategory == "over_time", "Poison dart works over time")
    assert(library:get("axe_attack").subcategory == "melee", "The axe is melee")
    assert(contains(library:get("axe_attack").tags, "cleave"), "The axe cleaves")
    assert(not library:get("focus").can_be_primary and library:get("minor_heal").can_be_primary,
        "Only damage and heal abilities can be a primary")
    print("✓ Library coverage test passed")
end
-- }}}

-- {{{ TestSuite.test_search
function TestSuite.test_search()
    local heals = ids(library:search("heal"))
    for _, id in ipairs({"minor_heal", "emergency_heal", "healing_circle"}) do
        assert(contains(heals, id), "Searching heal finds " .. id)
    end
    assert(heals[1] ~= "weakness_curse", "A name match comes before a description match")
    assert(contains(heals, "weakness_curse"), "Descriptions are searched too")
    local slow = ids(library:search("slow"))
    assert(contains(slow, "crippling_blow") and contains(slow, "static_field"), "Tags are searched")
    assert(#library:search("power strike") == 1, "Every word must match")
    assert(#library:search("dragon") == 0, "Nothing matches nonsense")
    assert(#library:search("") == #library.order, "An empty search lists everything")
    assert(#library:search(nil) == #library.order, "No search lists everything")

    for _, entry in ipairs(library:search("", {category = "debuff"})) do
        assert(entry.category == "debuff", "The category filter holds")
    end
    for _, entry in ipairs(library:search("", {primary_only = true})) do
        assert(entry.can_be_primary, "primary_only keeps primaries")
    end
    for _, entry in ipairs(library:search("", {tag = "weapon"})) do
        assert(contains(entry.tags, "weapon"), "The tag filter holds")
    end
    for _, entry in ipairs(library:search("", {max_cost = 20})) do
        assert(library:cost(entry.id) <= 20, "max_cost holds")
    end
    assert(#library:search("", {subcategory = "zone"}) == 1, "One zone ability")

    local again = ids(library:search("attack"))
    local first = ids(library:search("attack"))
    assert(table.concat(again, ",") == table.concat(first, ","), "Search order is the same every time")
    print("✓ Search test passed")
end
-- }}}

-- {{{ TestSuite.test_limits_and_clamping
function TestSuite.test_limits_and_clamping()
    local hard = TemplateConstraints.abilities
    for _, id in ipairs(library.order) do
        for property, limit in pairs(library:limits(id)) do
            assert(limit.min <= limit.base and limit.base <= limit.max, id .. " " .. property .. " brackets its base")
        end
        local limits = library:limits(id)
        if limits.power then
            assert(limits.power.max <= math.max(hard.max_power, limits.power.base), id .. " power within the cap")
        end
        assert(limits.range.max <= math.max(hard.max_range, limits.range.base), id .. " range within the cap")
    end
    local config, clean, notes = library:create_config("meteor_strike", {power = 999, range = 5, speed = 3})
    assert(config.power == 60 and clean.power == 60, "Power is held to 1.5 times the template's")
    assert(config.range == 22.5, "Range is held to half the template's")
    assert(config.speed == nil and #notes == 3, "Untunable properties are refused, with a note each")
    local _, clean_same = library:create_config("meteor_strike", {power = 40})
    assert(next(clean_same) == nil, "A change to the template's own value is no change")
    local _, _, bad = library:create_config("meteor_strike", {power = "lots"})
    assert(bad[1]:find("number"), "Non-numbers are refused")
    local none, _, unknown = library:create_config("dragon_breath")
    assert(none == nil and unknown[1]:find("dragon_breath"), "Unknown abilities are refused")
    print("✓ Limits and clamping test passed")
end
-- }}}

-- {{{ TestSuite.test_cost_matches_template
function TestSuite.test_cost_matches_template()
    for _, id in ipairs(library.order) do
        local cheap = library:cost(id, {mana_rate = library:limits(id).mana_rate.min}, false)
        local dear = library:cost(id, {mana_rate = library:limits(id).mana_rate.max}, false)
        assert(cheap <= library:cost(id) and library:cost(id) <= dear, id .. " charges faster for more")
        local template = UnitTemplate.new({name = "Cost Check", unit_type = "melee",
            abilities = {"primary_melee_attack", {template = id, changes = {mana_rate = library:limits(id).mana_rate.max}}}})
        assert(template.breakdown.abilities[2] == dear, id .. " costs on a template what the library says")
    end
    local as_primary = UnitTemplate.new({name = "Cost Check", unit_type = "ranged", abilities = {"crossbow_attack"}})
    assert(as_primary.breakdown.abilities[1] == library:cost("crossbow_attack", nil, true), "Primary prices match")
    print("✓ Cost matches template test passed")
end
-- }}}

-- {{{ TestSuite.test_selector_flow
function TestSuite.test_selector_flow()
    local original = warrior()
    local selector = AbilitySelector:new(original)
    local slots = selector:slots()
    assert(#slots == TemplateConstraints.abilities.max_count, "A row for every slot")
    assert(slots[1].primary and slots[2].id == "power_strike" and not slots[3].filled, "Slots show what they hold")

    assert(selector:select_slot(4) == 3, "A far slot means the next empty one")
    assert(selector:preview() == nil, "No preview without a draft")
    assert(selector:choose("crippling_blow").category == "debuff", "Choosing returns the library entry")
    local preview = selector:preview()
    assert(preview.valid and preview.was == 0, "Adding to an empty slot")
    assert(preview.cost == library:cost("crippling_blow"), "Preview cost is the library's cost")
    assert(preview.change == preview.cost, "The total grows by the ability's cost")
    assert(preview.points_left == original:points_left() - preview.cost, "Points left follow")

    local kept, notes = selector:set_property("duration", 100)
    assert(kept == library:limits("crippling_blow").duration.max and #notes == 1, "Tuning is held, with a note")
    local tuned = selector:preview()
    assert(tuned.cost > preview.cost, "A longer slow costs more")
    assert(tuned.cost == library:cost("crippling_blow", {duration = kept}), "Tuned cost matches the library")
    assert(tuned.config.duration == kept, "The preview shows the tuned config")
    assert(#original.abilities == 2, "Nothing changes before apply")
    local ok = selector:apply()
    assert(ok and #selector.template.abilities == 3, "Apply fills the slot")

    local result = selector:result()
    assert(result.abilities[3].template == "crippling_blow" and result.abilities[3].changes.duration == kept,
        "The result keeps the library id and its changes")
    assert(result.is_valid and result.points_used == tuned.points_used, "The result is what was previewed")

    selector:select_slot(3)
    assert(selector.draft.changes.duration == kept, "Selecting a filled slot loads it for editing")
    selector:reset_property("duration")
    assert(selector:preview().cost == preview.cost, "Reset puts the template's value back")

    assert(selector:clear_slot(2), "A secondary can be cleared")
    assert(selector:result().abilities[2].template == "crippling_blow", "Later slots move up")
    print("✓ Selector flow test passed")
end
-- }}}

-- {{{ TestSuite.test_primary_and_refusals
function TestSuite.test_primary_and_refusals()
    local selector = AbilitySelector:new(warrior())
    assert(selector:choose("focus") == nil, "No choosing before a slot")
    assert(selector:select_slot(0) == nil and selector:select_slot(1.5) == nil, "Slot numbers are checked")
    selector:select_slot(1)
    local refused, why = selector:choose("focus")
    assert(refused == nil and why:find("primary"), "A buff can't be the primary")
    assert(selector:choose("dragon_breath") == nil, "Unknown abilities are refused")
    assert(selector:choose("axe_attack"), "A weapon can be the primary")
    assert(selector:apply(), "Swapping the primary")
    assert(selector:result().abilities[1].template == "axe_attack", "The new primary is in place")

    local expensive = AbilitySelector:new(UnitTemplate.new({name = "Full Up", unit_type = "melee",
        abilities = {"primary_melee_attack", "power_strike", "battle_fury"}}))
    expensive:select_slot(4)
    expensive:choose("static_field")
    local ok, preview = expensive:apply()
    assert(ok == false and not preview.valid, "Going over budget is refused")
    assert(preview.points_left < 0, "The preview says by how much")
    assert(#expensive:result().abilities == 3, "A refused apply changes nothing")

    local single = AbilitySelector:new(UnitTemplate.new({name = "Single", unit_type = "melee",
        abilities = {"primary_melee_attack"}}))
    assert(single:clear_slot(1) == nil, "The last ability can't be cleared")
    local pair = AbilitySelector:new(UnitTemplate.new({name = "Pair", unit_type = "melee",
        abilities = {"primary_melee_attack", "focus"}}))
    local cleared, reason = pair:clear_slot(1)
    assert(cleared == nil and reason:find("primary"), "Clearing the primary can't leave a buff in its place")
    assert(pair:clear_slot(3) == nil, "Empty slots can't be cleared")
    print("✓ Primary and refusals test passed")
end
-- }}}

-- {{{ TestSuite.test_custom_abilities
function TestSuite.test_custom_abilities()
    local selector = AbilitySelector:new(warrior())
    selector:select_slot(3)
    assert(selector:custom({type = "magic"}) == nil, "A config that can't be built is refused")
    assert(selector:custom("fireball") == nil, "A custom ability is a table")
    local config = AbilityFactory.create_config("sunder_armor", {name = "Rust Touch", duration = 4})
    assert(selector:custom(config), "A whole config is taken")
    local preview = selector:preview()
    assert(preview.valid and preview.config.name == "Rust Touch", "The custom ability previews")
    selector:set_property("range", 300)
    local wide = selector:preview()
    assert(not wide.valid and table.concat(wide.errors, " "):find("range 300"), "Custom values are judged by the rules")
    assert(selector:apply() == false, "And an invalid one can't be applied")
    selector:set_property("range", 20)
    assert(selector:apply(), "A fixed one can")
    local result = selector:result()
    assert(result.abilities[3].config and result.abilities[3].config.name == "Rust Touch", "Custom configs are kept")
    local reloaded = UnitTemplate.from_save_data(result:to_save_data())
    assert(reloaded.points_used == result.points_used, "Custom abilities save and load")
    print("✓ Custom abilities test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local start = os.clock()
    for _ = 1, 50 do
        library:search("a")
    end
    local selector = AbilitySelector:new(warrior())
    selector:select_slot(3)
    selector:choose("sunder_armor")
    for step = 1, 200 do
        selector:set_property("duration", 3 + step % 10)
        selector:preview()
    end
    local seconds = os.clock() - start
    assert(seconds < 5, string.format("50 searches and 200 previews take %.2f s", seconds))
    print(string.format("✓ Performance test passed (%.2f s)", seconds))
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running ability selection tests...")
    TestSuite.test_library_coverage()
    TestSuite.test_search()
    TestSuite.test_limits_and_clamping()
    TestSuite.test_cost_matches_template()
    TestSuite.test_selector_flow()
    TestSuite.test_primary_and_refusals()
    TestSuite.test_custom_abilities()
    TestSuite.test_performance()
    print("✅ All ability selection tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
