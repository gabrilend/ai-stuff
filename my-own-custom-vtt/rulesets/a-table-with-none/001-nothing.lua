--
-- 001-nothing.lua -- a tabletop with no rules at all.
--
-- The other sample refuses commands, limits movement, and shows everybody's
-- numbers. This one does none of those things.
--
-- Between them they are the test: TWO RULESETS THAT DISAGREE ABOUT WHAT IS
-- LEGAL, WHAT A THING IS, AND WHO MAY KNOW WHAT, OVER ONE UNCHANGED SERVER.
--
-- One ruleset proves an interface exists. Two prove it is an interface -- if the
-- second needed the server changed, the first was the game wearing a ruleset's
-- clothes.
--

-- {{{ function on_load
function on_load()
    wandering = vtt.stream("wandering")
end
-- }}}

-- {{{ function on_command
function on_command(viewer, verb, subject, ax, ay)
    -- Everything is allowed. There are no turns, no ranges, and no conditions.
    -- The people at the table sort it out between themselves, which is what a
    -- great many tables actually do.
    return true
end
-- }}}

-- {{{ function may_know
function may_know(viewer, thing)
    -- Nothing is public. Not a secret-keeping mechanism -- there is simply
    -- nothing to know, because this ruleset keeps no numbers.
    return nil
end
-- }}}

-- {{{ function describe
function describe(kind)
    -- Abstract tokens with a colour. The server never learned that kind 1 was
    -- called a goblin under the other ruleset, which is the point.
    local colours = { "red", "blue", "amber", "violet", "white" }

    return "token," .. colours[(kind % #colours) + 1]
end
-- }}}

-- {{{ function on_action
function on_action(viewer, subject, a, b)
    -- A pool of six-sided dice, counting successes. A different question of the
    -- same streams the other ruleset asks a d20 of.
    local successes = 0

    for i = 1, 5 do
        if wandering:between(1, 6) >= 5 then
            successes = successes + 1
        end
    end

    if successes > 0 then
        return true, string.format("%d success%s",
                                   successes, successes == 1 and "" or "es")
    end

    return false, "no successes"
end
-- }}}
