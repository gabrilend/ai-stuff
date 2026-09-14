-- A match left to fill its lanes for a minute, and then dropped into the calm.
--
-- The calm is the one stretch of a match where nothing is trying to kill anything. No
-- wave is raised, everything on the field walks home, and the players re-place what they
-- are holding with no pressure on them at all. It exists so that a boon is chosen in a
-- moment a person can think in rather than in the middle of a fight.
--
-- The question: does the map actually empty? "Everybody walks home" is a sentence about
-- intent, and two separate things have to be true for it: the spawner has to refuse, and
-- every body already out has to pick the pattern that takes it off the field. Either half
-- failing looks identical from outside -- a lane with people still standing in it -- so
-- what is watched here is the count of formed bodies, which has to fall and keep falling.
--
-- **The calm is arranged to begin part-way through the run rather than at the start.**
-- Setting the clock forward empties the field for a moment, because the wave timer moves
-- with it and the first wave of the posed world is still due. A calm imposed on an empty
-- map would empty nothing and pass anyway.

return {
  covers = {"605"},

  name = "The calm empties the lanes",

  caption = "A minute of ordinary play with troops in all three lanes, then the calm " ..
            "falls at thirty seconds from the end. Nothing new leaves either base, and " ..
            "the count of formed bodies drops toward nothing as the field walks home. " ..
            "The guards stay where they are: a guard is at home already.",

  ground = "match",

  arrange = {
    {"tick", 3000},
    -- Twenty seconds before this run stops. The calm's own length is nine hundred
    -- ticks, so the run has to end inside that window: a first attempt ended on the
    -- exact tick the calm expired, read an ordinary phase back, and failed.
    {"at", 4500, "phase", "calm"},
  },

  ticks = 2100,

  measure = {"tick", "phase", "alive", "bodies", "guards", "waves", "front", "back", "depth"},

  ["finally"] = {
    -- Still in it when the run stops. If this is one, the calm turned over early and
    -- every other number below is about an ordinary match.
    {"phase", "equals", 4},

    -- **The lanes are draining.** Seventy-five formed bodies were standing in them at
    -- the instant the calm fell and forty-four are left twenty seconds later, so the
    -- claim is pitched at sixty: comfortably below where it started and comfortably
    -- above where it lands, because what is being asserted is the direction and not
    -- the rate.
    --
    -- Not nought. **The walk is the deadline** -- a body in the far half of a lane
    -- cannot reach a base inside the calm's thirty seconds and is not supposed to.
    {"bodies", "at_most", 60},

    -- The guards are still standing at their towers, which is what stops the count of
    -- the living reaching nought. A guard is at home already.
    {"guards", "at_least", 30},
  },
}
