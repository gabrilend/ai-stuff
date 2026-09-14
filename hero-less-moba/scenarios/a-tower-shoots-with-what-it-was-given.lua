-- One upgrade slotted into the blue team's top-lane stone before anybody moves.
--
-- The question: does a tower notice? A tower does not read its team's record when it
-- swings -- that would be a pointer chased on the hot path once per shot per tower --
-- so it keeps its own copy of what its lane's stone holds, rebuilt whenever the slot
-- changes. A copy that is never rebuilt is the quietest bug in the project: the slot
-- says one, the interface says one, the tower shoots with nothing, and nobody finds out
-- until somebody wonders why stone upgrades feel weak.
--
-- Two numbers, and the whole test is that they agree. The count of upgrades sitting in
-- a tower slot goes to one when the arrangement is performed. The count of towers
-- actually carrying one has to follow.
--
-- **Five towers, not one.** A stone slot belongs to a lane rather than to a tower, so
-- feeding it arms every tower that team owns in that lane -- and the base towers, which
-- inherit from every lane and are therefore armed by a placement into any of the three.
-- That number is worth watching rather than a nuisance: it is the reason a stone upgrade
-- buys a wall and never a step forward.
--
-- This is the test that found the gate arming nothing at all. The team's slot counts
-- are one cache over the stones and a tower's own copy is a second, and the arrangement
-- verb was rebuilding only the first -- so every scenario ever written that slotted into
-- stone was posing a world where the number said one and the towers shot with nothing.

return {
  covers = {"408"},

  name = "A tower shoots with what it was given",

  caption = "One Whetstone in the blue team's top-lane stone, and nothing else changed. " ..
            "The slot fills immediately. Watch the count of armed towers: every tower " ..
            "that team owns in that lane picks the upgrade up, and no tower in any " ..
            "other lane does.",

  ground = "match",

  arrange = {
    {"tick", 3000},
    -- Team one, the first upgrade kind, into the stone of lane one.
    {"stone", 1, 1, "towers", 1},
  },

  ticks = 600,

  measure = {"tick", "in_lanes", "in_stone", "in_library", "armed_towers", "towers"},

  always = {
    -- It went where it was told and nowhere else.
    {"in_stone", "equals", 1},
    {"in_lanes", "equals", 0},
    {"in_library", "equals", 0},

    -- **The claim this test exists for.** Nought here with the slot at one is a copy
    -- that never happened.
    {"armed_towers", "at_least", 1},
  },
}
