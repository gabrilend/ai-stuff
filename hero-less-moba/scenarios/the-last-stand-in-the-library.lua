-- One upgrade in the blue team's library slot, and one in a lane, and nothing else.
--
-- The question: are the three places an upgrade can stand actually three places? They
-- are the same shape in memory -- counts per upgrade kind -- because placing one is
-- moving a number from one count to another, and the risk of three identical structures
-- is that a mistake in one of them looks exactly like correct behaviour in another.
--
-- The library slot is the one with the strangest rule attached: it feeds the base towers
-- of **every** lane rather than one, because the base is the last stand and the last
-- stand does not get to pick a side of the map. So the interesting number here is not
-- that the library slot fills -- it is how many towers pick something up from it.

return {
  covers = {"409", "410"},

  name = "The last stand in the library",

  caption = "One Whetstone in the blue library, one in the blue top lane. The three " ..
            "slot counts stay separate -- one in a lane, none in stone, one in the " ..
            "library -- and the towers that arm are the ones that can see either: the " ..
            "base towers inherit from every lane and from the library alike.",

  ground = "match",

  arrange = {
    {"tick", 3000},
    {"stone", 1, 1, "library"},
    {"stone", 1, 2, "lane", 1},
  },

  ticks = 600,

  measure = {"tick", "in_lanes", "in_stone", "in_library", "armed_towers", "carried"},

  always = {
    -- Three places, three counts, and nothing leaking between them.
    {"in_library", "equals", 1},
    {"in_lanes", "equals", 1},
    {"in_stone", "equals", 0},

    -- **A library slot arms stone even though nothing was put in any stone.** That is
    -- the inheritance, stated as a number: were the base towers reading only their own
    -- lane's stone, this would be nought for the whole run.
    {"armed_towers", "at_least", 1},
  },
}
