-- {{{ Ability Cue Renderer Test Suite
-- Checks what issue 068's drawing asks the graphics object to draw, and
-- what its sound player asks the audio module to play, using stand-ins
-- that record every call instead of a window and speakers. This shows
-- the right shapes and sounds are asked for; it cannot show how they
-- look or sound, which needs LÖVE and a person.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_ability_cue_renderer').run_all()"
local TestSuite = {}

local AbilityCueRenderer = require("src.systems.ability_cue_renderer")
local SoundPlayer = require("src.systems.sound_player")
local AbilityBalance = require("src.testing.ability_balance")
local TemplateManager = require("src.managers.template_manager")
local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")

-- {{{ local function new_recorder
-- A graphics object whose every function records its name and arguments,
-- with the colour set last stored on each call.
local function new_recorder()
    local calls = {}
    local recorder = {calls = calls, color = {1, 1, 1, 1}}
    setmetatable(recorder, {__index = function(_, name)
        if name == "setColor" then
            return function(r, g, b, a)
                if type(r) == "table" then
                    recorder.color = {r[1], r[2], r[3], r[4] or 1}
                else
                    recorder.color = {r, g, b, a or 1}
                end
            end
        end
        return function(...)
            table.insert(calls, {name = name, args = {...}, color = recorder.color})
        end
    end})
    return recorder
end
-- }}}

-- {{{ local function find_calls
local function find_calls(recorder, name, predicate)
    local found = {}
    for _, call in ipairs(recorder.calls) do
        if call.name == name and (not predicate or predicate(call.args, call.color)) then
            table.insert(found, call)
        end
    end
    return found
end
-- }}}

-- {{{ local function same_color
local function same_color(a, b)
    return math.abs(a[1] - b[1]) < 1e-6 and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6
end
-- }}}

-- {{{ local function two_units
local function two_units()
    local em = EntityManager:new()
    local a = Unit.create_basic_unit(em, 0, 0, 1, "melee")
    local b = Unit.create_basic_unit(em, 10, 0, 2, "melee")
    return em, a, b
end
-- }}}

-- {{{ TestSuite.test_numbers
function TestSuite.test_numbers()
    local em, a, b = two_units()
    local renderer = AbilityCueRenderer.new()
    renderer:take({
        {kind = "damage", x = 10, y = 0, amount = 12.4, caster = a, target = b, damage_type = "physical"},
        {kind = "damage", x = 10, y = 0, amount = 7, caster = a, target = b, damage_type = "magical",
            delivery = "projectile"},
        {kind = "damage", x = 10, y = 0, amount = 3, target = b, over_time = true},
        {kind = "heal", x = 0, y = 0, amount = 20, target = a},
        {kind = "heal", x = 0, y = 0, amount = 4, target = a, over_time = true},
        {kind = "projectile_miss", x = 10, y = 0, target = b},
        {kind = "damage", x = 10, y = 0, amount = 0, target = b},
        {kind = "heal", x = 0, y = 0, amount = 0, target = a}
    }, em)
    local g = new_recorder()
    local drawn = renderer:draw(g, {entity_manager = em})
    assert(drawn.floats == 6, "Six numbers or words; nothing for zero")
    local texts = {}
    for _, call in ipairs(find_calls(g, "print")) do
        texts[call.args[1]] = call.color
    end
    local colors = AbilityCueRenderer.NUMBER_COLORS
    assert(texts["12"] and same_color(texts["12"], colors.physical), "Physical damage, rounded")
    assert(texts["7"] and same_color(texts["7"], colors.magical), "Magical damage has its own colour")
    assert(texts["3"] and same_color(texts["3"], colors.over_time), "Ticks have theirs")
    assert(texts["+20"] and same_color(texts["+20"], colors.heal), "Healing shows with a plus")
    assert(texts["+4"] and same_color(texts["+4"], colors.heal_over_time), "Healing over time too")
    assert(texts["miss"], "A miss shows as a word")

    renderer:update(0.5)
    local later = new_recorder()
    renderer:draw(later, {entity_manager = em})
    local first = find_calls(g, "print", function(args) return args[1] == "12" end)[1]
    local second = find_calls(later, "print", function(args) return args[1] == "12" end)[1]
    assert(second.args[3] < first.args[3], "Numbers rise")
    assert(second.color[4] < first.color[4], "And fade")
    renderer:update(0.6)
    assert(renderer:draw(new_recorder(), {entity_manager = em}).floats == 0, "And go")
    print("✓ Numbers test passed")
end
-- }}}

-- {{{ TestSuite.test_swings
function TestSuite.test_swings()
    local em, a, b = two_units()
    local renderer = AbilityCueRenderer.new()
    renderer:take({
        {kind = "damage", x = 10, y = 0, amount = 5, caster = a, target = b, weapon = "sword"},
        {kind = "damage", x = 10, y = 0, amount = 5, caster = a, target = b, weapon = "axe", cleave = true},
        {kind = "damage", x = 10, y = 0, amount = 5, caster = a, target = b, weapon = "spear"},
        {kind = "damage", x = 10, y = 0, amount = 5, caster = a, target = b, delivery = "projectile"},
        {kind = "damage", x = 10, y = 0, amount = 5, caster = a, target = b, over_time = true}
    }, em)
    renderer:update(renderer.swing_time / 2)
    local g = new_recorder()
    assert(renderer:draw(g, {entity_manager = em}).swings == 3, "Melee hits swing; arrows and ticks don't")
    local arcs = find_calls(g, "arc")
    assert(#arcs == 2, "Sword and axe draw arcs")
    local function width(call)
        return call.args[7] - call.args[6]
    end
    local sword = arcs[1]
    local axe = arcs[2]
    assert(same_color(sword.color, AbilityCueRenderer.WEAPONS.sword.color), "The sword's colour")
    assert(same_color(axe.color, AbilityCueRenderer.WEAPONS.axe.color), "The axe's colour")
    assert(width(axe) > width(sword), "A cleaving axe sweeps wider than a sword")
    assert(sword.args[3] == 0 and sword.args[4] == 0, "Swings start at the caster")
    local thrusts = find_calls(g, "line", function(_, color)
        return same_color(color, AbilityCueRenderer.WEAPONS.spear.color)
    end)
    assert(#thrusts == 1 and thrusts[1].args[3] == 10, "A spear thrusts straight to the target")
    print("✓ Swings test passed")
end
-- }}}

-- {{{ TestSuite.test_projectiles
function TestSuite.test_projectiles()
    local renderer = AbilityCueRenderer.new()
    local effects = {projectiles = {}}
    local looks = {"arrow_shot", "bolt_shot", "stone_shot", "javelin_throw", "poison_dart", "unknown_thing"}
    for index, visual in ipairs(looks) do
        table.insert(effects.projectiles, {x = index * 20, y = 0, dir_x = 1, dir_y = 0,
            ability = {visual_effect = visual}})
    end
    local g = new_recorder()
    assert(renderer:draw(g, {effects = effects}).projectiles == #looks, "Every projectile in flight")
    local function shapes_at(x)
        local found = {}
        for _, call in ipairs(g.calls) do
            local at = (call.name == "circle" and call.args[2] == x)
                or (call.name == "line" and (call.args[1] == x or call.args[3] == x))
            if at then
                found[call.name] = (found[call.name] or 0) + 1
            end
        end
        return found
    end
    assert(shapes_at(20).line == 3, "An arrow: a shaft and two strokes of head")
    assert(shapes_at(40).line == 1 and shapes_at(40).circle == 1, "A bolt: a short shaft and a heavy tip")
    assert(shapes_at(60).circle == 1 and not shapes_at(60).line, "A stone: a dot")
    assert(shapes_at(80).line == 3, "A javelin has a head")
    assert(shapes_at(100).line == 1, "A dart: a short line")
    assert(shapes_at(120).circle == 1, "Anything else: an orb")
    local javelin = find_calls(g, "line", function(args) return args[3] == 80 end)[1]
    local dart = find_calls(g, "line", function(args) return args[3] == 100 end)[1]
    assert(80 - javelin.args[1] > 100 - dart.args[1], "A javelin is longer than a dart")
    print("✓ Projectiles test passed")
end
-- }}}

-- {{{ TestSuite.test_areas_zones_deaths
function TestSuite.test_areas_zones_deaths()
    local renderer = AbilityCueRenderer.new()
    renderer:take({
        {kind = "area", x = 50, y = 50, radius = 30, effect = "damage"},
        {kind = "area", x = 0, y = 0, radius = 20, effect = "heal"},
        {kind = "death", x = 5, y = 5}
    })
    local persistent = {
        get_zones = function()
            return {{x = 100, y = 100, radius = 25, effect = "damage", fraction = 1},
                {x = 200, y = 100, radius = 25, effect = "damage", fraction = 0.2}}
        end
    }
    local g = new_recorder()
    local drawn = renderer:draw(g, {persistent = persistent})
    assert(drawn.flashes == 3 and drawn.zones == 2, "Flashes and zones")
    local ring = find_calls(g, "circle", function(args) return args[1] == "line" and args[4] == 30 end)
    assert(#ring == 1, "An area cast draws its circle at its radius")
    local heal_ring = find_calls(g, "circle", function(args) return args[1] == "line" and args[4] == 20 end)[1]
    assert(same_color(heal_ring.color, AbilityCueRenderer.ZONE_COLORS.heal), "A healing circle looks like one")
    local fresh = find_calls(g, "circle", function(args) return args[1] == "line" and args[2] == 100 end)[1]
    local fading = find_calls(g, "circle", function(args) return args[1] == "line" and args[2] == 200 end)[1]
    assert(fading.color[4] < fresh.color[4], "Zones fade as they run out")
    assert(#find_calls(g, "line", function(args) return args[1] == 5 - 6 end) == 2, "A death draws a cross")
    renderer:update(renderer.flash_time)
    assert(renderer:draw(new_recorder(), {persistent = persistent}).flashes == 0, "Flashes go; zones stay")
    local zoomed = new_recorder()
    renderer:draw(zoomed, {persistent = persistent, }, {zoom = 2, x = 50, y = 50})
    local moved = find_calls(zoomed, "circle", function(args) return args[1] == "line" end)[1]
    assert(moved.args[2] == 100 and moved.args[4] == 50, "The view's zoom and offset apply")
    print("✓ Areas, zones and deaths test passed")
end
-- }}}

-- {{{ TestSuite.test_markers
function TestSuite.test_markers()
    local em, a, b = two_units()
    em:add_component(a, "effects", {active = {
        fury = {kind = "buff", stacks = 2},
        ward = {kind = "buff", stacks = 1}
    }})
    em:add_component(b, "effects", {active = {bash = {kind = "debuff", stun = true, stacks = 1}}})
    local persistent = {
        get_zones = function() return {} end,
        get_effects_on = function(_, entity)
            if entity == b then
                return {{name = "poison", kind = "damage"}}
            end
            return {}
        end
    }
    local g = new_recorder()
    local drawn = AbilityCueRenderer.new():draw(g, {entity_manager = em, persistent = persistent})
    assert(drawn.markers == 4, "Two buffs, a debuff and a poison")
    local triangles = find_calls(g, "polygon")
    assert(#triangles == 3, "A triangle per buff or debuff")
    local up = find_calls(g, "polygon", function(_, color) return same_color(color, AbilityCueRenderer.EFFECT_COLORS.buff) end)
    local down = find_calls(g, "polygon", function(_, color)
        return same_color(color, AbilityCueRenderer.EFFECT_COLORS.debuff)
    end)
    assert(#up == 2 and #down == 1, "Buffs and debuffs differ in colour")
    assert(up[1].args[3] < up[1].args[5], "Buffs point up: the tip is above the base")
    assert(down[1].args[3] > down[1].args[5], "Debuffs point down")
    assert(#find_calls(g, "print", function(args) return args[1] == "x2" end) == 1, "Stacks are counted")
    assert(#find_calls(g, "circle", function(args, color)
        return args[1] == "line" and same_color(color, AbilityCueRenderer.EFFECT_COLORS.stun)
    end) == 1, "A stunned unit gets a ring")
    assert(#find_calls(g, "circle", function(args, color)
        return args[1] == "fill" and same_color(color, AbilityCueRenderer.EFFECT_COLORS.damage)
    end) == 1, "Damage over time shows as a dot")
    print("✓ Markers test passed")
end
-- }}}

-- {{{ TestSuite.test_sounds
function TestSuite.test_sounds()
    local played, loaded = {}, {}
    local audio = {newSource = function(path)
        table.insert(loaded, path)
        if path:find("broken") then
            error("bad file")
        end
        return {
            setVolume = function() end,
            stop = function() end,
            play = function() table.insert(played, path) end
        }
    end}
    local filesystem = {getInfo = function(path)
        if path == "assets/sounds/sword_hit.ogg" or path == "assets/sounds/heal_cast.wav"
                or path == "assets/sounds/broken.ogg" then
            return {type = "file"}
        end
    end}
    local player = SoundPlayer.new({audio = audio, filesystem = filesystem})
    assert(player:play("sword_hit") and played[1] == "assets/sounds/sword_hit.ogg", "A sound by name")
    assert(player:play("heal_cast") and played[2] == "assets/sounds/heal_cast.wav", "Then .wav")
    assert(player:play("nothing_here") == false, "No file, nothing played")
    assert(player:play("broken") == false and player.stats.failed == 1, "A broken file fails quietly")
    assert(player:play("../secrets") == false, "Names can't leave the sounds folder")
    player:play("sword_hit")
    assert(#loaded == 3 and #played == 3, "Each file is loaded once")
    assert(SoundPlayer.new({}):play("sword_hit") == false, "No audio at all: nothing fails")

    local renderer = AbilityCueRenderer.new({sound = player})
    renderer:take({{kind = "heal", x = 0, y = 0, amount = 5, sound = "heal_cast"}, {kind = "death", x = 0, y = 0}})
    assert(played[#played] == "assets/sounds/heal_cast.wav", "Cues play their sounds")
    print("✓ Sounds test passed")
end
-- }}}

-- {{{ TestSuite.test_real_battle
-- A real headless battle, its cues taken and drawn every frame.
function TestSuite.test_real_battle()
    local manager = TemplateManager:new()
    manager:create_default_templates()
    local world = AbilityBalance.new_world(5)
    AbilityBalance.add_team(world, 1, AbilityBalance.roster({manager:get_template("Storm Caller"),
        manager:get_template("Crossbowman"), manager:get_template("Skirmisher")}), 0)
    AbilityBalance.add_team(world, 2, AbilityBalance.roster(manager:get_template("Berserker"), 3), 40)
    local renderer = AbilityCueRenderer.new({sound = SoundPlayer.new({})})
    local seen = {zones = 0, projectiles = 0, swings = 0, markers = 0, floats = 0, flashes = 0}
    for _ = 1, 300 do
        AbilityBalance.step(world, 0.1)
        renderer:take(world.last_cues, world.em)
        renderer:update(0.1)
        local drawn = renderer:draw(new_recorder(), {entity_manager = world.em, effects = world.effects,
            persistent = world.persistent}, {zoom = 1.5})
        for key, count in pairs(drawn) do
            seen[key] = seen[key] + count
        end
    end
    for _, key in ipairs({"zones", "projectiles", "swings", "markers", "floats"}) do
        assert(seen[key] > 0, "A real battle shows " .. key)
    end
    print("✓ Real battle test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running ability cue renderer tests...")
    TestSuite.test_numbers()
    TestSuite.test_swings()
    TestSuite.test_projectiles()
    TestSuite.test_areas_zones_deaths()
    TestSuite.test_markers()
    TestSuite.test_sounds()
    TestSuite.test_real_battle()
    print("✅ All ability cue renderer tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
