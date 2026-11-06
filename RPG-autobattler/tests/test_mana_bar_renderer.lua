-- {{{ Mana Bar Renderer Test Suite
-- Checks what the mana bar drawing asks the graphics object to draw, using
-- a stand-in that records every call instead of a window. This shows the
-- right shapes are requested in the right places; it cannot show how they
-- look, which needs LÖVE and a person.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_mana_bar_renderer').run_all()"
local TestSuite = {}

local EntityManager = require("src.systems.entity_manager")
local Unit = require("src.entities.unit")
local UnitAbilities = require("src.components.unit_abilities")
local ManaSystem = require("src.systems.mana_system")
local ManaBarRenderer = require("src.systems.mana_bar_renderer")

-- {{{ local function new_recorder
-- A graphics object whose every function records its name and arguments.
-- The colour set last is stored with each call as `color`.
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

-- {{{ local function assert_near
local function assert_near(a, b, message, epsilon)
    epsilon = epsilon or 1e-6
    if math.abs(a - b) > epsilon then
        error(string.format("%s: expected %f, got %f", message, b, a))
    end
end
-- }}}

-- {{{ local function same_color
local function same_color(a, b)
    return math.abs(a[1] - b[1]) < 1e-6 and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6
end
-- }}}

-- {{{ local function setup
-- One unit at (100, 100) with an ability of each of four types.
local function setup()
    local em = EntityManager:new()
    local unit = Unit.create_basic_unit(em, 100, 100, 1, "support")
    local abilities, mana = UnitAbilities.attach(em, unit, {
        {name = "strike", type = "damage"},
        {name = "mend", type = "heal"},
        {name = "rally", type = "buff"},
        {name = "blast", type = "area"}
    })
    return em, unit, abilities, mana
end
-- }}}

-- {{{ local function fills
-- The coloured fill rectangles (not the dark backgrounds or covers).
local function fills(g)
    return find_calls(g, "rectangle", function(args, color)
        return args[1] == "fill" and color[4] > 0 and (color[1] + color[2] + color[3]) > 0.5
    end)
end
-- }}}

-- {{{ TestSuite.test_one_bar_per_ability
function TestSuite.test_one_bar_per_ability()
    local em, _, _, mana = setup()
    mana.bars[1].current = 50
    mana.bars[3].current = 25
    local renderer = ManaBarRenderer.new()
    local g = new_recorder()
    renderer:draw(g, em)

    local backgrounds = find_calls(g, "rectangle", function(args, color) return args[1] == "fill" and same_color(color, {0.1, 0.1, 0.1}) end)
    assert(#backgrounds == 4, "A background for each of four bars, got " .. #backgrounds)
    local found = {}
    for _, call in ipairs(fills(g)) do
        for index, bar in ipairs(mana.bars) do
            if same_color(call.color, ManaSystem.TYPE_COLORS[bar.type]) then
                found[index] = call.args[4]
            end
        end
    end
    assert_near(found[1], 12, "Half of the 24-wide damage bar")
    assert_near(found[3], 6, "A quarter of the buff bar")
    assert(found[2] == 0, "An empty heal bar has no width")

    -- Stacked above the unit, primary on top and taller.
    local tops = {}
    for _, call in ipairs(backgrounds) do table.insert(tops, {y = call.args[3], h = call.args[5]}) end
    table.sort(tops, function(a, b) return a.y < b.y end)
    assert(tops[4].y + tops[4].h <= 100 - 14 + 1e-6, "Bars sit above the unit")
    assert(tops[1].h > tops[2].h, "The primary bar, on top, is taller")

    print("✓ One bar per ability test passed")
end
-- }}}

-- {{{ TestSuite.test_patterns_and_shapes
function TestSuite.test_patterns_and_shapes()
    local em, _, _, mana = setup()
    for _, bar in ipairs(mana.bars) do bar.current = bar.max * 0.9 end
    local renderer = ManaBarRenderer.new()

    local g = new_recorder()
    renderer:draw(g, em, {zoom = 1})
    assert(#find_calls(g, "polygon") == 1, "A triangle marks the damage bar")
    assert(#find_calls(g, "circle", function(a) return a[1] == "line" end) == 1, "A ring marks the area bar")
    assert(#find_calls(g, "points") > 0, "Dots pattern the buff bar")
    local faint = find_calls(g, "line", function(_, color) return color[4] > 0.3 and color[4] < 0.4 end)
    assert(#faint > 10, "Pattern lines are drawn over the fills")

    local medium = new_recorder()
    renderer:draw(medium, em, {zoom = 0.7})
    assert(#find_calls(medium, "polygon") == 0 and #find_calls(medium, "points") == 0, "No patterns or shapes at medium zoom")

    print("✓ Patterns and shapes test passed")
end
-- }}}

-- {{{ TestSuite.test_ready_and_charging
function TestSuite.test_ready_and_charging()
    local em, _, _, mana = setup()
    mana.bars[1].current = mana.bars[1].max
    mana.bars[2].current = 40
    mana.bars[2].charging = true
    local renderer = ManaBarRenderer.new()

    local g = new_recorder()
    renderer:draw(g, em)
    local white_borders = find_calls(g, "rectangle", function(args, color)
        return args[1] == "line" and color[1] == 1 and color[2] == 1 and color[3] == 1
    end)
    assert(#white_borders == 1, "Only the full bar gets a white border")
    local tick = find_calls(g, "line", function(args, color)
        -- An upright white line inside the bar's span (the shape marks sit
        -- to the right of it).
        return color[4] == 1 and color[1] == 1 and math.abs(args[1] - args[3]) < 1e-6
            and args[4] - args[2] > 3 and args[1] <= 112
    end)
    assert(#tick == 1, "One charging tick, on the charging bar")
    assert_near(tick[1].args[1], 100 - 12 + 24 * 0.4, "At the edge of its fill")

    local alphas = {}
    for i = 1, 4 do
        renderer:update(0.125)
        local frame = new_recorder()
        renderer:draw(frame, em)
        local border = find_calls(frame, "rectangle", function(args, color)
            return args[1] == "line" and color[1] == 1 and color[2] == 1 and color[3] == 1
        end)[1]
        alphas[i] = border.color[4]
    end
    assert(math.max(alphas[1], alphas[2], alphas[3], alphas[4]) - math.min(alphas[1], alphas[2], alphas[3], alphas[4]) > 0.2,
        "The ready border pulses")

    print("✓ Ready and charging test passed")
end
-- }}}

-- {{{ TestSuite.test_cooldown_and_kept_mana
function TestSuite.test_cooldown_and_kept_mana()
    local em, unit, abilities, mana = setup()
    abilities.cooldowns[1] = 1
    abilities.cooldown_durations = {4}
    mana.bars[1].current = 60
    local renderer = ManaBarRenderer.new()

    local g = new_recorder()
    renderer:draw(g, em)
    local covers = find_calls(g, "rectangle", function(args, color) return args[1] == "fill" and color[4] == 0.6 and color[1] == 0 end)
    assert(#covers == 1, "One cooldown cover")
    assert_near(covers[1].args[4], 6, "A quarter of the cooldown left covers a quarter of the bar")
    assert_near(covers[1].args[2], 100 - 12 + 18, "From the right-hand end")

    renderer:notice({caster = unit, index = 1, ability = abilities.abilities[1], mana_spent = 40})
    g = new_recorder()
    renderer:draw(g, em)
    local kept = find_calls(g, "rectangle", function(args, color) return args[1] == "line" and color[4] == 0.9 and color[1] == 1 end)
    assert(#kept == 1 and math.abs(kept[1].args[4] - 24 * 0.6) < 1e-6, "The 60% the cast kept is outlined")

    renderer:update(1.0)
    g = new_recorder()
    renderer:draw(g, em)
    kept = find_calls(g, "rectangle", function(args, color) return args[1] == "line" and color[4] == 0.9 and color[1] == 1 end)
    assert(#kept == 0, "Only for a moment")

    renderer:notice({caster = unit, index = 1, ability = abilities.abilities[1], mana_spent = 100})
    assert(renderer.kept[unit] == nil, "A full-bar cast keeps nothing to show")

    print("✓ Cooldown and kept mana test passed")
end
-- }}}

-- {{{ TestSuite.test_zoom
function TestSuite.test_zoom()
    local em = setup()
    local renderer = ManaBarRenderer.new()

    local big = new_recorder()
    renderer:draw(big, em, {zoom = 2})
    local width = find_calls(big, "rectangle", function(args) return args[1] == "fill" end)[1].args[4]
    assert_near(width, 48, "Twice the zoom, twice as wide")
    local x = find_calls(big, "rectangle", function(args) return args[1] == "fill" end)[1].args[2]
    assert_near(x, 200 - 24, "Centred on the unit's place on screen")

    local huge = new_recorder()
    renderer:draw(huge, em, {zoom = 5})
    assert_near(find_calls(huge, "rectangle", function(args) return args[1] == "fill" end)[1].args[4], 48, "No wider than twice")

    local far = new_recorder()
    renderer:draw(far, em, {zoom = 0.3})
    assert(#find_calls(far, "rectangle") == 0, "Far out, no bars")
    assert(#find_calls(far, "circle") == 4, "But a dot per ability")

    print("✓ Zoom test passed")
end
-- }}}

-- {{{ TestSuite.test_culling_and_dead
function TestSuite.test_culling_and_dead()
    local em = setup()
    local off = Unit.create_basic_unit(em, 2000, 100, 1, "melee")
    UnitAbilities.attach(em, off, {{type = "damage"}})
    local dead = Unit.create_basic_unit(em, 120, 100, 2, "melee")
    UnitAbilities.attach(em, dead, {{type = "damage"}})
    Unit.damage_unit(em, dead, 10000)

    local renderer = ManaBarRenderer.new()
    local drawn = renderer:draw(new_recorder(), em, {zoom = 1, width = 800, height = 600})
    assert(drawn == 1, "Only the living unit on screen is drawn, got " .. drawn)
    drawn = renderer:draw(new_recorder(), em, {x = 1800, y = 0, zoom = 1, width = 800, height = 600})
    assert(drawn == 1, "Scrolling over brings the other into view")

    print("✓ Culling and dead test passed")
end
-- }}}

-- {{{ TestSuite.test_performance
function TestSuite.test_performance()
    local em = EntityManager:new()
    for i = 1, 150 do
        local unit = Unit.create_basic_unit(em, (i % 15) * 40, math.floor(i / 15) * 40, 1, "melee")
        local _, mana = UnitAbilities.attach(em, unit, {{type = "damage"}, {type = "heal"}, {type = "buff"}, {type = "area"}})
        for _, bar in ipairs(mana.bars) do bar.current = (i * 7) % 100; bar.charging = true end
    end
    local renderer = ManaBarRenderer.new()
    local quiet = setmetatable({}, {__index = function() return function() end end})
    local start = os.clock()
    for _ = 1, 60 do
        renderer:update(1 / 60)
        renderer:draw(quiet, em, {zoom = 1})
    end
    local elapsed = os.clock() - start
    print(string.format("  150 units x 4 bars, 60 frames: %.3fs", elapsed))
    assert(renderer.drawn_last == 150, "All drawn")
    assert(elapsed < 1.0, "Drawing mana bars stays cheap")

    print("✓ Performance test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Mana Bar Renderer Tests...")
    print(string.rep("=", 40))

    TestSuite.test_one_bar_per_ability()
    TestSuite.test_patterns_and_shapes()
    TestSuite.test_ready_and_charging()
    TestSuite.test_cooldown_and_kept_mana()
    TestSuite.test_zoom()
    TestSuite.test_culling_and_dead()
    TestSuite.test_performance()

    print(string.rep("=", 40))
    print("✅ All mana bar renderer tests passed!")
end
-- }}}

return TestSuite
-- }}}
