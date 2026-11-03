-- {{{ Match Renderer Test Suite
-- Checks what the match drawing asks the graphics object to draw, using a
-- stand-in that records every call instead of a window. This shows the
-- right shapes are requested in the right places; it cannot show how they
-- look, which needs LÖVE and a person.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_match_renderer').run_all()"
local TestSuite = {}

local Base = require("src.entities.base")
local Match = require("src.systems.match")
local MatchRenderer = require("src.systems.match_renderer")

-- {{{ local function new_recorder
-- A graphics object whose every function records its name and arguments.
-- getWidth/getHeight answer as a 1024 x 768 window would.
local function new_recorder()
    local calls = {}
    local recorder = {calls = calls}
    setmetatable(recorder, {__index = function(_, name)
        if name == "getWidth" then return function() return 1024 end end
        if name == "getHeight" then return function() return 768 end end
        return function(...)
            table.insert(calls, {name = name, args = {...}})
        end
    end})
    return recorder
end
-- }}}

-- {{{ local function find_calls
local function find_calls(recorder, name, predicate)
    local found = {}
    for _, call in ipairs(recorder.calls) do
        if call.name == name and (not predicate or predicate(call.args)) then
            table.insert(found, call)
        end
    end
    return found
end
-- }}}

-- {{{ local function printed
-- Every bit of text drawn, joined, to search in.
local function printed(recorder)
    local texts = {}
    for _, call in ipairs(recorder.calls) do
        if call.name == "print" or call.name == "printf" then
            table.insert(texts, tostring(call.args[1]))
        end
    end
    return table.concat(texts, "\n")
end
-- }}}

-- {{{ local function at
local function at(x, y)
    return function(args)
        return math.abs(args[2] - x) < 1e-6 and math.abs(args[3] - y) < 1e-6
    end
end
-- }}}

-- {{{ TestSuite.test_fresh_match
function TestSuite.test_fresh_match()
    local match = Match:new()
    local g = new_recorder()
    MatchRenderer.draw(g, match)

    assert(#find_calls(g, "rectangle", function(a) return a[1] == "fill" and a[2] < 100 end) >= 1,
        "Team 1's base is a square on the left")
    assert(#find_calls(g, "polygon", function(a) return a[2] > 900 end) == 1, "Team 2's base is a diamond on the right")

    local em = match.entity_manager
    for team = 1, 2 do
        for _, shield in ipairs(Base.get_shields(em, match:get_base(team))) do
            assert(#find_calls(g, "circle", function(a) return a[1] == "line" and at(shield.x, shield.y)({nil, a[2], a[3]}) end) == 1,
                "Each standing shield is drawn as a ring")
        end
    end
    -- Turrets appear once the turret system has seen the bases.
    match:update(1 / 60)
    g = new_recorder()
    MatchRenderer.draw(g, match)
    assert(#find_calls(g, "setLineWidth", function(a) return a[1] == 3 end) == 2, "Two turret barrels")
    assert(not printed(g):find("Shield down"), "No reset banner in a calm match")
    assert(not printed(g):find("wins"), "No victory text while playing")
    assert(printed(g):find("pristine"), "Each base's damage stage is written beside it")

    print("✓ Fresh match test passed")
end
-- }}}

-- {{{ TestSuite.test_fallen_shield_is_a_cross
function TestSuite.test_fallen_shield_is_a_cross()
    local match = Match:new()
    local em = match.entity_manager
    local shield = Base.get_shields(em, match:get_base(2))[1]
    Base.apply_damage(em, match:get_base(2), shield.max_hp, 1)

    local g = new_recorder()
    MatchRenderer.draw(g, match)
    local near = function(a) return math.abs((a[1] + a[3]) / 2 - shield.x) < 1e-6 and math.abs((a[2] + a[4]) / 2 - shield.y) < 1e-6 end
    assert(#find_calls(g, "line", near) == 2, "A fallen shield is drawn as an x")

    print("✓ Fallen shield is a cross test passed")
end
-- }}}

-- {{{ TestSuite.test_units_by_shape
function TestSuite.test_units_by_shape()
    local match = Match:new()
    match:spawn_unit(1, "melee", 300, 300)
    match:spawn_unit(1, "ranged", 320, 300)
    match:spawn_unit(2, "tank", 340, 300)

    local g = new_recorder()
    MatchRenderer.draw(g, match)
    assert(#find_calls(g, "circle", at(300, 300)) == 1, "Melee units are circles")
    assert(#find_calls(g, "polygon", function(a) return a[2] == 320 end) == 1, "Ranged units are triangles")
    assert(#find_calls(g, "rectangle", function(a) return a[2] == 340 - 6 end) == 1, "Tanks are squares")

    print("✓ Units by shape test passed")
end
-- }}}

-- {{{ TestSuite.test_reset_banner
function TestSuite.test_reset_banner()
    local match = Match:new()
    local em = match.entity_manager
    match:spawn_unit(1, "melee", 850, 384)
    Base.apply_damage(em, match:get_base(2), Base.get_shields(em, match:get_base(2))[1].max_hp, 1)
    match:update(1 / 60)
    assert(match:is_resetting(), "Reset running")

    local g = new_recorder()
    MatchRenderer.draw(g, match)
    assert(printed(g):find("Shield down"), "A banner announces the reset")
    assert(printed(g):find("team 2 defends"), "The banner names the defender")

    for _ = 1, 90 do match:update(1 / 60) end   -- into collection
    g = new_recorder()
    MatchRenderer.draw(g, match)
    local faded = find_calls(g, "setColor", function(a) return type(a[1]) == "table" and a[1][4] and a[1][4] < 0.5 end)
    assert(#faded > 0, "Units being removed are drawn faded")

    print("✓ Reset banner test passed")
end
-- }}}

-- {{{ TestSuite.test_victory_text
function TestSuite.test_victory_text()
    local match = Match:new()
    local em = match.entity_manager
    local base = match:get_base(2)
    em:get_component(base, "base").shields = {}
    Base.apply_damage(em, base, 100000, 1)
    match:update(1 / 60)

    local g = new_recorder()
    MatchRenderer.draw(g, match)
    assert(printed(g):find("Team 1 wins"), "The winner is announced")
    assert(printed(g):find("Press R"), "It says how to start again")

    print("✓ Victory text test passed")
end
-- }}}

-- {{{ TestSuite.test_game_state_draws_match_in_play
function TestSuite.test_game_state_draws_match_in_play()
    local saved = rawget(_G, "love")
    local g = new_recorder()
    _G.love = {graphics = g, timer = {getTime = function() return 0 end, getFPS = function() return 60 end}}
    local ok, err = pcall(function()
        package.loaded["src.systems.game_state"] = nil
        local GameState = require("src.systems.game_state")
        GameState:enter()

        GameState:draw()
        assert(#find_calls(g, "circle", function(a) return a[2] == 50 and a[3] == 50 and a[4] == 30 end) == 1,
            "During the tutorial the test pattern it explains is drawn")
        assert(#find_calls(g, "polygon") == 0, "No match drawing during the tutorial")

        GameState:keypressed("escape")
        for k in pairs(g.calls) do g.calls[k] = nil end
        GameState:draw()
        assert(#g.calls > 0, "Something is drawn in play")
        local polygons = 0
        for _, call in ipairs(g.calls) do
            if call.name == "polygon" then polygons = polygons + 1 end
        end
        assert(polygons >= 1, "In play the match is drawn (team 2's diamond)")
        GameState:exit()
    end)
    _G.love = saved
    if not ok then
        error(err, 0)
    end

    print("✓ Game state draws the match in play test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Match Renderer Tests...")
    print(string.rep("=", 40))

    TestSuite.test_fresh_match()
    TestSuite.test_fallen_shield_is_a_cross()
    TestSuite.test_units_by_shape()
    TestSuite.test_reset_banner()
    TestSuite.test_victory_text()
    TestSuite.test_game_state_draws_match_in_play()

    print(string.rep("=", 40))
    print("✅ All match renderer tests passed!")
end
-- }}}

return TestSuite
-- }}}
