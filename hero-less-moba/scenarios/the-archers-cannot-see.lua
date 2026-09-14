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
-- **This file wanted to put two waves nose to nose in the top lane and cannot.** The
-- `wave` verb does not work in any test that also sets a clock: the `tick` verb pushes
-- the wave timer forward to stop the spawner dumping every wave it thinks it owes, and
-- the `wave` verb asks that same spawner for a wave -- which is now never due. It places
-- nothing, and says nothing about having placed nothing. The rows that tried are left
-- here as a comment rather than deleted, because a test that quietly does half of what
-- it says is worse than one that does not try.
--
--   {"wave", 1, 1, 4},
--   {"wave", 2, 1, 4},
--
-- Until that is fixed, this file is a clock and the lanes fill themselves. Everything
-- it is for is still visible -- it just arrives on the game's own schedule rather than
-- being posed.

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
  },

  ticks = 900,

  always = {
    {"overlaps", "equals", 0},
  },

  -- **Not a standing claim.** Setting the clock to six thousand empties the field for a
  -- moment -- the tick verb pushes the wave timer forward so the spawner does not dump
  -- every wave it thinks it owes, which means the first waves of this world are still
  -- due. A run that demanded bodies at every tick failed on its first one, correctly.
  ["finally"] = {
    {"bodies", "at_least", 1},
  },
}
