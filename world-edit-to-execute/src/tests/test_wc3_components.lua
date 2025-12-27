--[[
Test suite for WC3 Component Definitions
Tests component registration, default values, and helper functions.
]]

-- {{{ Setup paths
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local entity = require("runtime.ecs.entity")
local component = require("runtime.ecs.component")
local ecs = require("runtime.ecs")

-- Load WC3 components (registers them)
local wc3 = require("runtime.ecs.wc3_components")
-- }}}

-- {{{ Test infrastructure
local test_count = 0
local pass_count = 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

-- reset_all: Reset all ECS state for clean test isolation
local function reset_all()
    entity.reset()
    -- Note: Don't clear component types, we need the registered WC3 components
end
-- }}}

-- {{{ Component Registration Tests
test_section("Component Registration")

test("position registered", component.get_defaults("position") ~= nil)
test("stats registered", component.get_defaults("stats") ~= nil)
test("movement registered", component.get_defaults("movement") ~= nil)
test("owner registered", component.get_defaults("owner") ~= nil)
test("unit_type registered", component.get_defaults("unit_type") ~= nil)
test("selectable registered", component.get_defaults("selectable") ~= nil)
test("abilities registered", component.get_defaults("abilities") ~= nil)
test("buffs registered", component.get_defaults("buffs") ~= nil)
test("hero registered", component.get_defaults("hero") ~= nil)
test("building registered", component.get_defaults("building") ~= nil)
test("item registered", component.get_defaults("item") ~= nil)
test("projectile registered", component.get_defaults("projectile") ~= nil)
test("destructible registered", component.get_defaults("destructible") ~= nil)
test("doodad registered", component.get_defaults("doodad") ~= nil)

local types = component.get_registered_types()
test("at least 14 types registered", #types >= 14)
-- }}}

-- {{{ Position Component Defaults
test_section("Position Component Defaults")

local pos_def = component.get_defaults("position")
test("position x default is 0", pos_def.x == 0)
test("position y default is 0", pos_def.y == 0)
test("position z default is 0", pos_def.z == 0)
test("position facing default is 0", pos_def.facing == 0)
-- }}}

-- {{{ Stats Component Defaults
test_section("Stats Component Defaults")

local stats_def = component.get_defaults("stats")
test("stats hp default is 100", stats_def.hp == 100)
test("stats hp_max default is 100", stats_def.hp_max == 100)
test("stats hp_regen default is 0", stats_def.hp_regen == 0)
test("stats mp default is 0", stats_def.mp == 0)
test("stats mp_max default is 0", stats_def.mp_max == 0)
test("stats armor default is 0", stats_def.armor == 0)
test("stats armor_type default is normal", stats_def.armor_type == "normal")
test("stats damage_min default is 0", stats_def.damage_min == 0)
test("stats damage_max default is 0", stats_def.damage_max == 0)
test("stats damage_type default is normal", stats_def.damage_type == "normal")
test("stats attack_speed default is 1", stats_def.attack_speed == 1.0)
test("stats attack_range default is 128", stats_def.attack_range == 128)
test("stats invulnerable default is false", stats_def.invulnerable == false)
test("stats ethereal default is false", stats_def.ethereal == false)
-- }}}

-- {{{ Movement Component Defaults
test_section("Movement Component Defaults")

local mov_def = component.get_defaults("movement")
test("movement speed default is 270", mov_def.speed == 270)
test("movement speed_current default is 270", mov_def.speed_current == 270)
test("movement speed_min default is 100", mov_def.speed_min == 100)
test("movement speed_max default is 522", mov_def.speed_max == 522)
test("movement pathing default is foot", mov_def.pathing == "foot")
test("movement collision_size default is 32", mov_def.collision_size == 32)
test("movement moving default is false", mov_def.moving == false)
test("movement turn_rate default is 0.6", mov_def.turn_rate == 0.6)
test("movement fly_height default is 0", mov_def.fly_height == 0)
-- }}}

-- {{{ Owner Component Defaults
test_section("Owner Component Defaults")

local owner_def = component.get_defaults("owner")
test("owner player_id default is 0", owner_def.player_id == 0)
test("owner team default is 0", owner_def.team == 0)
-- }}}

-- {{{ Unit Type Component Defaults
test_section("Unit Type Component Defaults")

local ut_def = component.get_defaults("unit_type")
test("unit_type type_id default is empty", ut_def.type_id == "")
test("unit_type name default is empty", ut_def.name == "")
test("unit_type is_hero default is false", ut_def.is_hero == false)
test("unit_type is_building default is false", ut_def.is_building == false)
test("unit_type is_summoned default is false", ut_def.is_summoned == false)
test("unit_type food_used default is 0", ut_def.food_used == 0)
test("unit_type food_made default is 0", ut_def.food_made == 0)
test("unit_type level default is 1", ut_def.level == 1)
-- }}}

-- {{{ Selectable Component Defaults
test_section("Selectable Component Defaults")

local sel_def = component.get_defaults("selectable")
test("selectable selected default is false", sel_def.selected == false)
test("selectable selection_scale default is 1", sel_def.selection_scale == 1.0)
test("selectable selection_priority default is 0", sel_def.selection_priority == 0)
test("selectable show_healthbar default is true", sel_def.show_healthbar == true)
test("selectable show_manabar default is true", sel_def.show_manabar == true)
test("selectable can_select default is true", sel_def.can_select == true)
-- }}}

-- {{{ Abilities Component Defaults
test_section("Abilities Component Defaults")

local ab_def = component.get_defaults("abilities")
test("abilities ability_ids is table", type(ab_def.ability_ids) == "table")
test("abilities cooldowns is table", type(ab_def.cooldowns) == "table")
test("abilities levels is table", type(ab_def.levels) == "table")
test("abilities disabled is table", type(ab_def.disabled) == "table")
-- }}}

-- {{{ Buffs Component Defaults
test_section("Buffs Component Defaults")

local buf_def = component.get_defaults("buffs")
test("buffs active is table", type(buf_def.active) == "table")
test("buffs speed_modifier default is 1", buf_def.speed_modifier == 1.0)
test("buffs damage_modifier default is 1", buf_def.damage_modifier == 1.0)
test("buffs armor_modifier default is 0", buf_def.armor_modifier == 0)
-- }}}

-- {{{ Hero Component Defaults
test_section("Hero Component Defaults")

local hero_def = component.get_defaults("hero")
test("hero experience default is 0", hero_def.experience == 0)
test("hero level default is 1", hero_def.level == 1)
test("hero strength default is 0", hero_def.strength == 0)
test("hero agility default is 0", hero_def.agility == 0)
test("hero intelligence default is 0", hero_def.intelligence == 0)
test("hero primary_attribute default is strength", hero_def.primary_attribute == "strength")
test("hero str_per_level default is 0", hero_def.str_per_level == 0)
test("hero inventory is table", type(hero_def.inventory) == "table")
-- }}}

-- {{{ Building Component Defaults
test_section("Building Component Defaults")

local bld_def = component.get_defaults("building")
test("building construction_progress default is 1", bld_def.construction_progress == 1.0)
test("building under_construction default is false", bld_def.under_construction == false)
test("building rally_x default is 0", bld_def.rally_x == 0)
test("building rally_y default is 0", bld_def.rally_y == 0)
test("building rally_target default is nil", bld_def.rally_target == nil)
test("building queue is table", type(bld_def.queue) == "table")
test("building queue_progress default is 0", bld_def.queue_progress == 0)
-- }}}

-- {{{ Item Component Defaults
test_section("Item Component Defaults")

local item_def = component.get_defaults("item")
test("item item_id default is empty", item_def.item_id == "")
test("item charges default is 0", item_def.charges == 0)
test("item charges_max default is 0", item_def.charges_max == 0)
test("item on_ground default is true", item_def.on_ground == true)
test("item carrier default is nil", item_def.carrier == nil)
test("item slot default is 0", item_def.slot == 0)
test("item can_be_picked_up default is true", item_def.can_be_picked_up == true)
test("item drop_on_death default is true", item_def.drop_on_death == true)
test("item sellable default is true", item_def.sellable == true)
test("item pawnable default is true", item_def.pawnable == true)
-- }}}

-- {{{ Projectile Component Defaults
test_section("Projectile Component Defaults")

local proj_def = component.get_defaults("projectile")
test("projectile source default is nil", proj_def.source == nil)
test("projectile target default is nil", proj_def.target == nil)
test("projectile target_x default is 0", proj_def.target_x == 0)
test("projectile target_y default is 0", proj_def.target_y == 0)
test("projectile speed default is 900", proj_def.speed == 900)
test("projectile arc default is 0", proj_def.arc == 0)
test("projectile homing default is true", proj_def.homing == true)
test("projectile damage default is 0", proj_def.damage == 0)
test("projectile damage_type default is normal", proj_def.damage_type == "normal")
test("projectile impact_ability default is nil", proj_def.impact_ability == nil)
test("projectile distance_traveled default is 0", proj_def.distance_traveled == 0)
-- }}}

-- {{{ Destructible Component Defaults
test_section("Destructible Component Defaults")

local dest_def = component.get_defaults("destructible")
test("destructible type_id default is empty", dest_def.type_id == "")
test("destructible alive default is true", dest_def.alive == true)
test("destructible current_animation default is stand", dest_def.current_animation == "stand")
test("destructible lumber_amount default is 0", dest_def.lumber_amount == 0)
test("destructible gold_amount default is 0", dest_def.gold_amount == 0)
-- }}}

-- {{{ Doodad Component Defaults
test_section("Doodad Component Defaults")

local dood_def = component.get_defaults("doodad")
test("doodad type_id default is empty", dood_def.type_id == "")
test("doodad variation default is 0", dood_def.variation == 0)
test("doodad scale default is 1", dood_def.scale == 1.0)
test("doodad animation default is stand", dood_def.animation == "stand")
-- }}}

-- {{{ Create Unit Helper Tests
test_section("Create Unit Helper")
reset_all()

local unit = wc3.create_unit("hfoo", 0, 100, 200, 1.57)

test("unit created", entity.exists(unit))
test("unit has position", component.has(unit, "position"))
test("unit has unit_type", component.has(unit, "unit_type"))
test("unit has owner", component.has(unit, "owner"))
test("unit has stats", component.has(unit, "stats"))
test("unit has movement", component.has(unit, "movement"))
test("unit has selectable", component.has(unit, "selectable"))
test("unit has abilities", component.has(unit, "abilities"))
test("unit has buffs", component.has(unit, "buffs"))
test("unit does NOT have hero", not component.has(unit, "hero"))
test("unit does NOT have building", not component.has(unit, "building"))

local pos = component.get(unit, "position")
test("unit position x set", pos.x == 100)
test("unit position y set", pos.y == 200)
test("unit position facing set", math.abs(pos.facing - 1.57) < 0.01)

local ut = component.get(unit, "unit_type")
test("unit type_id set", ut.type_id == "hfoo")

local owner = component.get(unit, "owner")
test("unit owner set", owner.player_id == 0)
-- }}}

-- {{{ Create Hero Helper Tests
test_section("Create Hero Helper")
reset_all()

local hero = wc3.create_hero("Hpal", 1, 500, 600, 0)

test("hero created", entity.exists(hero))
test("hero has position", component.has(hero, "position"))
test("hero has unit_type", component.has(hero, "unit_type"))
test("hero has owner", component.has(hero, "owner"))
test("hero has stats", component.has(hero, "stats"))
test("hero has movement", component.has(hero, "movement"))
test("hero has selectable", component.has(hero, "selectable"))
test("hero has abilities", component.has(hero, "abilities"))
test("hero has buffs", component.has(hero, "buffs"))
test("hero HAS hero component", component.has(hero, "hero"))

local ut = component.get(hero, "unit_type")
test("hero type_id set", ut.type_id == "Hpal")
test("hero is_hero flag set", ut.is_hero == true)

local hero_comp = component.get(hero, "hero")
test("hero level default is 1", hero_comp.level == 1)
test("hero experience default is 0", hero_comp.experience == 0)
-- }}}

-- {{{ Create Building Helper Tests
test_section("Create Building Helper")
reset_all()

local bldg = wc3.create_building("htow", 1, 500, 600, 0)

test("building created", entity.exists(bldg))
test("building has position", component.has(bldg, "position"))
test("building has unit_type", component.has(bldg, "unit_type"))
test("building has owner", component.has(bldg, "owner"))
test("building has stats", component.has(bldg, "stats"))
test("building has selectable", component.has(bldg, "selectable"))
test("building has building component", component.has(bldg, "building"))
test("building does NOT have movement", not component.has(bldg, "movement"))
test("building does NOT have abilities", not component.has(bldg, "abilities"))

local ut = component.get(bldg, "unit_type")
test("building type_id set", ut.type_id == "htow")
test("building is_building flag set", ut.is_building == true)
-- }}}

-- {{{ Create Item Helper Tests
test_section("Create Item Helper")
reset_all()

local item = wc3.create_item("rst1", 300, 400)

test("item created", entity.exists(item))
test("item has position", component.has(item, "position"))
test("item has item component", component.has(item, "item"))
test("item has selectable", component.has(item, "selectable"))
test("item does NOT have stats", not component.has(item, "stats"))

local pos = component.get(item, "position")
test("item position x set", pos.x == 300)
test("item position y set", pos.y == 400)

local item_comp = component.get(item, "item")
test("item item_id set", item_comp.item_id == "rst1")
test("item on_ground is true", item_comp.on_ground == true)
-- }}}

-- {{{ Create Destructible Helper Tests
test_section("Create Destructible Helper")
reset_all()

local dest = wc3.create_destructible("LTlt", 700, 800, 0.5, 250)

test("destructible created", entity.exists(dest))
test("destructible has position", component.has(dest, "position"))
test("destructible has stats", component.has(dest, "stats"))
test("destructible has destructible component", component.has(dest, "destructible"))
test("destructible has selectable", component.has(dest, "selectable"))

local pos = component.get(dest, "position")
test("destructible position x set", pos.x == 700)
test("destructible position y set", pos.y == 800)
test("destructible facing set", pos.facing == 0.5)

local stats = component.get(dest, "stats")
test("destructible hp set", stats.hp == 250)
test("destructible hp_max set", stats.hp_max == 250)

local dest_comp = component.get(dest, "destructible")
test("destructible type_id set", dest_comp.type_id == "LTlt")
-- }}}

-- {{{ Create Doodad Helper Tests
test_section("Create Doodad Helper")
reset_all()

local dood = wc3.create_doodad("ATtr", 1000, 1100, 0.25, 1.5, 3)

test("doodad created", entity.exists(dood))
test("doodad has position", component.has(dood, "position"))
test("doodad has doodad component", component.has(dood, "doodad"))
test("doodad does NOT have selectable", not component.has(dood, "selectable"))
test("doodad does NOT have stats", not component.has(dood, "stats"))

local pos = component.get(dood, "position")
test("doodad position x set", pos.x == 1000)
test("doodad position y set", pos.y == 1100)
test("doodad facing set", pos.facing == 0.25)

local dood_comp = component.get(dood, "doodad")
test("doodad type_id set", dood_comp.type_id == "ATtr")
test("doodad scale set", dood_comp.scale == 1.5)
test("doodad variation set", dood_comp.variation == 3)
-- }}}

-- {{{ Create Projectile Helper Tests
test_section("Create Projectile Helper")
reset_all()

-- Create source unit first
local source = wc3.create_unit("hfoo", 0, 100, 100, 0)
local target = wc3.create_unit("ogru", 1, 500, 500, 0)

local proj = wc3.create_projectile(source, target, 500, 500, 1200, 50)

test("projectile created", entity.exists(proj))
test("projectile has position", component.has(proj, "position"))
test("projectile has projectile component", component.has(proj, "projectile"))
test("projectile has movement", component.has(proj, "movement"))

local pos = component.get(proj, "position")
test("projectile starts at source x", pos.x == 100)
test("projectile starts at source y", pos.y == 100)

local proj_comp = component.get(proj, "projectile")
test("projectile source set", proj_comp.source == source)
test("projectile target set", proj_comp.target == target)
test("projectile target_x set", proj_comp.target_x == 500)
test("projectile target_y set", proj_comp.target_y == 500)
test("projectile speed set", proj_comp.speed == 1200)
test("projectile damage set", proj_comp.damage == 50)

local mov = component.get(proj, "movement")
test("projectile movement speed set", mov.speed == 1200)
test("projectile is moving", mov.moving == true)
-- }}}

-- {{{ Component Inheritance Tests
test_section("Component Inheritance")
reset_all()

local unit = wc3.create_unit("hkni", 0, 0, 0, 0)

-- Override some stats
local stats = component.get(unit, "stats")
stats.hp = 500
stats.hp_max = 500
stats.armor = 5

-- Check inheritance still works for non-overridden values
test("overridden hp", stats.hp == 500)
test("overridden hp_max", stats.hp_max == 500)
test("overridden armor", stats.armor == 5)
test("inherited mp (default 0)", stats.mp == 0)
test("inherited armor_type (default normal)", stats.armor_type == "normal")
test("inherited invulnerable (default false)", stats.invulnerable == false)

-- Override inherited value
stats.mp = 250
test("override inherited value", stats.mp == 250)
-- }}}

-- {{{ Multiple Entity Tests
test_section("Multiple Entities")
reset_all()

local unit1 = wc3.create_unit("hfoo", 0, 0, 0, 0)
local unit2 = wc3.create_unit("hfoo", 1, 100, 100, 0)
local hero1 = wc3.create_hero("Hpal", 0, 200, 200, 0)
local bldg1 = wc3.create_building("htow", 0, 300, 300, 0)
local item1 = wc3.create_item("rst1", 400, 400)

test("5 entities created", entity.get_count() == 5)

-- Modify one, check others unaffected
local stats1 = component.get(unit1, "stats")
stats1.hp = 999

local stats2 = component.get(unit2, "stats")
test("other unit unaffected", stats2.hp == 100) -- default

local hero_stats = component.get(hero1, "stats")
test("hero stats unaffected", hero_stats.hp == 100)
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed", pass_count, test_count - pass_count))
if pass_count == test_count then
    print("ALL TESTS PASSED")
else
    print("SOME TESTS FAILED")
    os.exit(1)
end
-- }}}
