-- A challenge already under way: the Field Dragon standing in the middle of the
-- centre lane, both teams' production funnelling into it, and one team's stone
-- already knocked out of the top lane.
--
-- This is what a match test is for. Reaching this state by playing takes eight
-- minutes; reaching it by loading takes no time at all, and it arrives held, so it
-- can be looked at before it moves.
--
-- Run it with:   ./run-a-test the-dragon-at-the-midpoint

return {
  -- What a person looking at this is looking at. The monster in the middle is the
  -- subject; the placed upgrades are the other half of the picture and are visibly
  -- what they are, sitting in lanes and in towers.
  covers = {"606", "404", "408"},

  name = "The dragon at the midpoint",

  caption = "Eight minutes into a match that has been going badly for one side in the " ..
            "top lane. The Field Dragon is out in the centre and both teams are feeding " ..
            "into it. One team has committed everything it holds to the middle; the " ..
            "other has spread its holding across all three lanes. What to watch is which " ..
            "of those two ways of spending a chest is still standing in a minute.",

  ground = "match",

  -- Every row is a verb the gate already owns. Nothing here is defined by this file --
  -- it names things the engine does and the engine does them, in this order.
  arrange = {
    -- The clock first, because setting it moves every other clock with it: the wave
    -- timer, the surge timer, the wallet ladder and the phase deadline. A scenario that
    -- placed bodies before setting the tick would be placing them into a world whose
    -- spawner was still a whole match behind.
    {"tick", 14000},
    {"challenge", 2},

    -- Team 1 has lost both of its lane towers in the top lane, which is the shape of a
    -- team that has been losing there for a while.
    {"rubble", 1, 1, 3},
    {"rubble", 1, 1, 2},

    -- And has answered by committing everything it holds to the middle.
    {"stone", 1, 1, "lane", 2},
    {"stone", 1, 1, "lane", 2},
    {"stone", 1, 3, "lane", 2},
    {"stone", 1, 7, "lane", 2},
    {"stone", 1, 4, "towers", 2},

    -- Team 2 has spread its holding instead.
    {"stone", 2, 1, "lane", 1},
    {"stone", 2, 3, "lane", 2},
    {"stone", 2, 5, "lane", 3},
    {"stone", 2, 2, "towers", 1},

    -- Both sides have bodies already in the corridor.
    --
    -- **These two rows place nothing, and the run says so.** The `wave` verb asks the
    -- spawner for a wave, and the `tick` verb has just pushed the spawner's own clock
    -- forward so that it does not dump every wave it thinks it owes -- which means no
    -- wave is due and none is made. The archers test carries the same note. It is left
    -- here rather than removed because the claim below fails on account of it, and a
    -- failing claim with a comment beside it is a bug report.
    {"wave", 1, 2, 3},
    {"wave", 2, 2, 5},

    -- Somebody has money to spend and is about to.
    {"points", 1, 1, 8},
    {"points", 1, 5, 8},

    -- And thirty seconds in, they spend it. The same dispatch table, fired later:
    -- anything a test can arrange at load, it can arrange as happening at a tick.
    {"at", 14900, "points", 1, 1, 8},
  },

  ticks = 600,

  always = {
    -- Nobody standing inside anybody, on a whole map with hundreds of bodies on it.
    -- This walks every pair and is the expensive reading in the catalogue; it is here
    -- because a match is where the rule about room has the most chances to fail.
    {"overlaps", "equals", 0},

  },

  -- A match test whose field emptied would report clean numbers for every other reading
  -- in the catalogue while showing nothing at all. Asked at the end rather than
  -- throughout, because the clock verb leaves the field momentarily empty by design.
  ["finally"] = {
    {"bodies", "at_least", 1},
  },
}
