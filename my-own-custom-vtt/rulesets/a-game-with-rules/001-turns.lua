--
-- 001-turns.lua -- initiative, and refusing out of turn.
--
-- This ruleset exists to be OPINIONATED. It is not trying to be a good game;
-- it is trying to be a game with rules, so that the other sample -- which has
-- none -- proves the server has no opinions of its own.
--
-- If this file needs a change to the server to work, then the server was not
-- system-agnostic and one of the phase 7 issues was wrong.
--

local order = {}
local whose_turn = 1
local turn_length = 40   -- beats

-- {{{ local function is_their_turn
local function is_their_turn(viewer)
    if #order == 0 then
        return true   -- nobody has joined the order yet.
    end

    return order[whose_turn] == viewer
end
-- }}}

-- {{{ local function join_the_order
local function join_the_order(viewer)
    for _, who in ipairs(order) do
        if who == viewer then return end
    end

    order[#order + 1] = viewer

    -- Sorted, so that two runs with the same participants produce the same
    -- order. An initiative that depends on who happened to speak first is an
    -- initiative that makes a replay diverge.
    table.sort(order)
end
-- }}}

-- {{{ function on_load
function on_load()
    initiative = vtt.stream("initiative")
    attack = vtt.stream("attack")
end
-- }}}

-- {{{ function on_tick
function on_tick(beat)
    if #order == 0 then return end

    -- Whose turn it is advances on a cadence. Beat-driven rather than
    -- clock-driven, because the ruleset is given the beat and has no access to
    -- the time of day.
    local which = math.floor(beat / turn_length) % #order

    whose_turn = which + 1
end
-- }}}

-- {{{ function on_command
function on_command(viewer, verb, subject, ax, ay)
    join_the_order(viewer)

    if verb == "order-stop" then
        return true   -- stopping is always allowed. Nobody is trapped.
    end

    if not is_their_turn(viewer) then
        return false, "it is not your turn -- viewer "
                      .. tostring(order[whose_turn]) .. " is acting"
    end

    -- A movement limit, enforced by refusing rather than by clamping. Clamping
    -- would move somebody a distance they did not ask for, which is worse than
    -- not moving them.
    if verb == "order-move" then
        local body = vtt.thing(subject)

        if body ~= nil then
            local far = math.abs(ax - body.x) + math.abs(ay - body.y)

            if far > 8 then
                return false, string.format(
                    "that is %.0f metres and you may move 8 in a turn", far)
            end
        end
    end

    return true
end
-- }}}

-- {{{ function may_know
function may_know(viewer, thing)
    -- Everybody's numbers are visible. A game with rules is a game where you
    -- can see what the rules are operating on.
    return "hp,armour,name"
end
-- }}}

-- {{{ function describe
function describe(kind)
    if kind == 1 then return "goblin,green,small" end
    if kind == 2 then return "cup,brown,tiny" end
    if kind == 3 then return "torch,orange,tiny" end
    return "creature,grey,medium"
end
-- }}}

-- {{{ function on_action
function on_action(viewer, subject, a, b)
    -- One action: attack. A twenty-sided roll against a target number.
    local roll = attack:between(1, 20)

    if roll >= 11 then
        local sheet = vtt.sheet(subject)
        sheet.hp = (sheet.hp or 10) - attack:between(1, 6)

        return true, string.format("hit, rolling %d -- it has %d left", roll, sheet.hp)
    end

    return false, string.format("missed, rolling %d", roll)
end
-- }}}

-- {{{ function on_region_enter
function on_region_enter(thing, left, entered)
    local where = vtt.region_name(entered)

    if where ~= nil and where ~= "" then
        local sheet = vtt.sheet(thing)
        sheet.last_seen_in = where
    end
end
-- }}}
