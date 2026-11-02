-- {{{ Match Test Suite
-- Runs whole matches without a window: the game state creates a match with
-- two bases, shields, turrets and the unit reset, and a match is played
-- through a shield falling, the reset clearing the attackers, and finally a
-- base falling and the match ending.
--
-- Units cannot attack bases yet, so the tests stand in for that: each
-- living attacker near a base deals a steady amount of damage per second
-- to it through Base.apply_damage, as a unit's attack would.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_match').run_all()"
local TestSuite = {}

local Base = require("src.entities.base")
local Unit = require("src.entities.unit")
local DefenseShield = require("src.entities.defense_shield")
local Match = require("src.systems.match")

local FRAME = 1 / 60

-- {{{ local function attack_base
-- The stand-in for unit attacks: every living unit of attacker_team within
-- `reach` of the target base hits it for dps * dt.
local function attack_base(match, attacker_team, dps, dt, reach)
    local em = match.entity_manager
    local target = match:get_base(attacker_team == 1 and 2 or 1)
    local base_pos = em:get_component(target, "position")
    reach = reach or 150
    for _, unit in ipairs(match:get_units(attacker_team)) do
        if Unit.is_alive(em, unit) then
            local pos = em:get_component(unit, "position")
            local dx, dy = pos.x - base_pos.x, pos.y - base_pos.y
            if dx * dx + dy * dy <= reach * reach then
                Base.apply_damage(em, target, dps * dt, attacker_team, unit.id)
            end
        end
    end
end
-- }}}

-- {{{ local function count_events
local function count_events(events, event_type)
    local count = 0
    for _, event in ipairs(events) do
        if event.type == event_type then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ local function spawn_attackers
-- Five team-1 tanks in front of team 2's base, inside its turret's range.
local function spawn_attackers(match)
    local base_pos = match.entity_manager:get_component(match:get_base(2), "position")
    local units = {}
    for i = 1, 5 do
        table.insert(units, match:spawn_unit(1, "tank", base_pos.x - 70, base_pos.y - 40 + i * 15))
    end
    return units
end
-- }}}

-- {{{ TestSuite.test_match_setup
function TestSuite.test_match_setup()
    local match = Match:new({width = 1024, height = 768})
    local em = match.entity_manager
    local left = em:get_component(match:get_base(1), "position")
    local right = em:get_component(match:get_base(2), "position")

    assert(left.x == Match.BASE_INSET and right.x == 1024 - Match.BASE_INSET, "Bases sit at either edge")
    assert(left.y == 384 and right.y == 384, "Bases sit at mid-height")
    assert(#Base.get_shields(em, match:get_base(1)) == 3, "Each base has three shields")
    assert(Base.get_shields(em, match:get_base(2))[1].x < right.x, "Team 2's front shield faces team 1")
    assert(not match:is_over() and not match:is_resetting(), "A new match is running and calm")

    print("✓ Match setup test passed")
end
-- }}}

-- {{{ TestSuite.test_shield_fall_and_reset
function TestSuite.test_shield_fall_and_reset()
    local match = Match:new({random = function() return 0 end})
    local em = match.entity_manager
    local target = match:get_base(2)
    local shields = Base.get_shields(em, target)
    local core = em:get_component(target, "health")
    local attackers = spawn_attackers(match)
    local defender = match:spawn_unit(2, "melee", 1000, 100)    -- far from the fight

    local seen = {}
    local elapsed = 0
    while shields[1].active and elapsed < 120 do
        attack_base(match, 1, 30, FRAME)
        match:update(FRAME)
        elapsed = elapsed + FRAME
        for _, event in ipairs(match:pop_events()) do
            table.insert(seen, event)
        end
    end
    assert(not shields[1].active, "Five attackers break the front shield")
    assert(count_events(seen, "turret_fired") > 0, "The turret fought back meanwhile")
    assert(core.current_hp == core.max_hp, "The core is untouched while shields stand")

    -- The shield_destroyed event is collected on the next frame, which
    -- starts the reset.
    match:update(FRAME)
    for _, event in ipairs(match:pop_events()) do
        table.insert(seen, event)
    end
    assert(count_events(seen, "shield_destroyed") == 1, "The fall is reported once")
    assert(match:is_resetting(), "The reset has begun")

    for _ = 1, math.ceil(3.2 / FRAME) do
        match:update(FRAME)
        for _, event in ipairs(match:pop_events()) do
            table.insert(seen, event)
        end
    end
    assert(not match:is_resetting(), "The reset has finished")
    assert(count_events(seen, "reset_completed") == 1, "The reset completed once")
    assert(#match:get_units(1) == 0, "Every attacker is gone")
    for _, unit in ipairs(attackers) do
        assert(em:get_entity_by_id(unit.id) == nil, "Attacker removed from the entity manager")
    end
    assert(em:get_entity_by_id(defender.id) ~= nil, "The defender's own unit stays")
    assert(DefenseShield.count_active(shields) == 2, "Two shields still stand")
    assert(not match:is_over(), "Losing a shield does not end the match")

    print("✓ Shield fall and reset test passed")
end
-- }}}

-- {{{ TestSuite.test_match_to_victory
function TestSuite.test_match_to_victory()
    local match = Match:new({random = function() return 1 end})   -- turrets always miss
    local em = match.entity_manager
    local target = match:get_base(2)
    local shields = Base.get_shields(em, target)

    -- Three waves: each breaks a shield and is cleared by the reset. The
    -- seal (issue 039) holds each later shield at 1 health until 30 seconds
    -- after the last fall, so the loops allow up to 200 seconds.
    local resets = 0
    for wave = 1, 3 do
        spawn_attackers(match)
        local elapsed = 0
        while shields[wave].active and elapsed < 200 do
            attack_base(match, 1, 40, FRAME)
            match:update(FRAME)
            elapsed = elapsed + FRAME
        end
        assert(not shields[wave].active, "Wave " .. wave .. " breaks shield " .. wave)
        for _ = 1, math.ceil(3.5 / FRAME) do
            match:update(FRAME)
        end
        resets = resets + count_events(match:pop_events(), "reset_completed")
        assert(#match:get_units(1) == 0, "Wave " .. wave .. " is cleared by its reset")
    end
    assert(resets == 3, "Three shields, three resets")

    -- The core alone: the last wave destroys it.
    spawn_attackers(match)
    local elapsed = 0
    while not match:is_over() and elapsed < 120 do
        attack_base(match, 1, 40, FRAME)
        match:update(FRAME)
        elapsed = elapsed + FRAME
    end
    assert(match:is_over(), "The base falls once its shields are gone")
    assert(match:get_winner() == 1, "Team 1 wins")
    local events = match:pop_events()
    assert(count_events(events, "victory") == 1, "Victory is reported")

    local time = match.time
    match:update(1.0)
    assert(match.time == time, "A finished match stops updating")

    print("✓ Match to victory test passed")
end
-- }}}

-- {{{ local function with_love_stub
-- Just enough of LÖVE for the game state to enter and update headlessly.
local function with_love_stub(fn)
    local saved = rawget(_G, "love")
    local noop = function() end
    _G.love = {
        graphics = {
            setBackgroundColor = noop,
            getWidth = function() return 1024 end,
            getHeight = function() return 768 end
        },
        timer = {getTime = function() return 0 end}
    }
    local ok, err = pcall(fn)
    _G.love = saved
    if not ok then
        error(err, 0)
    end
end
-- }}}

-- {{{ TestSuite.test_game_state_runs_the_match
function TestSuite.test_game_state_runs_the_match()
    with_love_stub(function()
        package.loaded["src.systems.game_state"] = nil
        local GameState = require("src.systems.game_state")
        GameState:enter()

        local match = GameState:get_match()
        assert(match, "Entering the game state creates a match")
        assert(match.width == 1024 and match.height == 768, "The field is the window's size")

        GameState:update(1.0)
        assert(GameState:is_paused() and match.time == 0, "The match waits while the tutorial runs")

        GameState:keypressed("escape")    -- closes the tutorial
        assert(not GameState:is_paused(), "Closing the tutorial starts play")

        local em = match.entity_manager
        local shields = Base.get_shields(em, match:get_base(2))
        spawn_attackers(match)
        local elapsed = 0
        while shields[1].active and elapsed < 120 do
            attack_base(match, 1, 30, FRAME)
            GameState:update(FRAME)
            elapsed = elapsed + FRAME
        end
        assert(not shields[1].active, "Play reaches a shield falling")
        for _ = 1, math.ceil(3.5 / FRAME) do
            GameState:update(FRAME)
        end
        assert(#match:get_units(1) == 0, "The game state's match runs the reset")

        GameState:keypressed("r")
        assert(GameState:get_match() ~= match, "R starts a fresh match")
        GameState:exit()
        assert(GameState:get_match() == nil, "Leaving the game state drops the match")
    end)

    print("✓ Game state runs the match test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running Match Tests...")
    print(string.rep("=", 40))

    TestSuite.test_match_setup()
    TestSuite.test_shield_fall_and_reset()
    TestSuite.test_match_to_victory()
    TestSuite.test_game_state_runs_the_match()

    print(string.rep("=", 40))
    print("✅ All match tests passed!")
end
-- }}}

return TestSuite
-- }}}
