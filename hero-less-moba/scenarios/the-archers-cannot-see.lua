-- The top lane at three minutes twenty, with the ordinary waves in it.
--
-- Staged for one question: when an ordinary arrow needs a clear line, what do the
-- bodies with a reach actually do about it? The clock starts far enough in that all
-- three lanes have waves walking and meeting, and early enough that no tower has
-- fallen and the shape of a line is still a line.
--
-- Run it with:   ./watch-the-arrows blocked     -- arrows need a clear line
--                ./watch-the-arrows arcing      -- they do not, which is the shipped rule
--
-- or without the window:   ./run-a-test the-archers-cannot-see report
--
-- **This file wanted to put two waves nose to nose in the top lane and now can.** For a
-- long time it could not: the `wave` verb asked the spawner for a wave by running the
-- whole spawn pass, and the spawn pass only produces anything when the clock says one is
-- due -- so in any scenario that also set the clock, which is every scenario, it placed
-- nothing and said nothing about having placed nothing. The rows were kept here as a
-- comment, because a test that quietly does half of what it says is worse than one that
-- does not try. A wave is now raised directly and the rows are back.

return {
  covers = {"204"},

  name = "The archers cannot see",

  caption = "Three minutes twenty into an ordinary match, before any tower has fallen. " ..
            "Watch the rank behind the line. If an arrow needs a clear line to what it " ..
            "is shooting at, the archers spread out looking for an angle past their own " ..
            "front rank; if it does not, they stay in their files and shoot over the top. " ..
            "Same bodies, same map, one line of difference in the unit catalogue.",

  ground = "match",

  arrange = {
    {"tick", 6000},
    -- Two waves, both teams, the top lane, four milestones in -- which is about where
    -- they would have met on their own, posed so they are there from the first tick
    -- rather than ninety seconds in.
    {"wave", 1, 1, 4},
    {"wave", 2, 1, 4},
  },

  ticks = 900,

  always = {
    {"overlaps", "equals", 0},
  },

  -- The two posed waves are on the field from the first tick, so unlike most match tests
  -- this one can ask for bodies throughout rather than only at the end.
  ["finally"] = {
    {"bodies", "at_least", 1},
  },
}
