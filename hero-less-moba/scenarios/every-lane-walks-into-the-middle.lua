-- A match dropped into a challenge, with the first monster standing at the midpoint.
--
-- A challenge turns the three lanes into one. Waves still leave the bases on the ordinary
-- cadence, and every one of them is routed into the centre instead of down its own road,
-- where they arrive abreast rather than through one another -- a wave raised for a side
-- lane was formed for a side lane and keeps that shape, which is how a player can see
-- which of the three converging groups came from where.
--
-- The monster is what they are converging on -- **two of them, one walking at each
-- library**, so that the two teams are answering the same question at the same time
-- rather than watching each other answer it. It is the only thing on the field that
-- belongs to nobody, and **the deadline is the walk**: it is going to a library, and how
-- long anyone has is how long that walk takes.
--
-- What is watched is the funnel. Bodies from three bases, one place.

return {
  covers = {"607"},

  name = "Every lane walks into the middle",

  caption = "Two minutes in, then a challenge with the first monster put out at the " ..
            "midpoint -- one for each team. Waves keep leaving all three bases and every " ..
            "one of them is sent to the centre. Watch the monster count hold at two and " ..
            "the bodies gather: the three lanes are one lane for as long as this lasts.",

  ground = "match",

  arrange = {
    {"tick", 3000},
    {"challenge", 1},
  },

  ticks = 1800,

  measure = {"tick", "phase", "alive", "bodies", "monsters", "waves", "fighting"},

  always = {
    -- The challenge holds for the whole run. If this turns over, everything below is
    -- about an ordinary match with a monster in it.
    {"phase", "equals", 3},

    -- **The monster is on the field.** One, put out by the challenge itself rather than
    -- spawned by anybody.
    {"monsters", "at_least", 1},
  },

  ["finally"] = {
    -- **And the lanes are still feeding it.** A challenge that stopped the spawner would
    -- be a challenge nobody could answer.
    {"waves", "at_least", 3},
    {"bodies", "at_least", 10},
  },
}
