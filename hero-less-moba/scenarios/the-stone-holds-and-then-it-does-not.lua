-- A whole match, from the opening wave to the library that ends it.
--
-- The long one. Everything in this phase is about stone -- a structure is a record with
-- health, a tower shoots and commits, guards make the ground around a tower dangerous,
-- and a library at nought ends the match -- and none of it can be posed, because a tower
-- falling is the end of a conversation that takes ten minutes to have.
--
-- So this runs the conversation. Nothing is arranged at all: the clock starts at nought,
-- the bots play, and the readings follow the stone down. What is being watched is a
-- sequence, not a moment:
--
--   * every structure starts whole, and the total health in them only falls;
--   * guards are on the ground from the first tick, put there by the towers;
--   * a tower reaches nought and becomes rubble, and the count of standing towers falls
--     to match;
--   * a library reaches nought, and the match has a winner.
--
-- **The last of those is the only claim in the project that a match can end.** Everything
-- else measures a match in progress.

return {
  covers = {"301", "303", "306", "307"},

  name = "The stone holds, and then it does not",

  caption = "A whole match played out with nobody's hand on it. Watch the standing " ..
            "tower count hold at eighteen for minutes and then come apart lane by lane, " ..
            "the rubble count rising to meet it, and the health left in stone falling " ..
            "the whole way. It ends when a library does.",

  ground = "match",

  ticks = 40000,

  measure = {"tick", "phase", "alive", "guards", "towers", "rubble", "libraries",
             "stone_health", "chest", "winner"},

  always = {
    -- **Stone is never repaired**, so the total in it is a number that only goes one
    -- way. A tower that healed itself would show up here and nowhere else.
    {"stone_health", "at_most", 29400},

    -- Every tower that is not standing is rubble, and there are eighteen of them. If
    -- these ever fail to add up, a structure has been lost rather than felled.
    {"towers", "at_most", 18},
    {"rubble", "at_most", 18},

    -- **Towers put guards on the ground and keep doing it.** A guard count that fell to
    -- nothing and stayed there would mean replacement had stopped, which looks from
    -- outside like a lane that suddenly got easy.
    {"guards", "at_least", 1},
  },

  ["finally"] = {
    -- The match ended, and it ended the way the design says it does: one library left
    -- standing out of two, and a team named.
    {"libraries", "equals", 1},
    {"winner", "at_least", 1},

    -- Towers fell on the way. A match won without felling anything would mean a library
    -- can be reached past whole stone.
    {"rubble", "at_least", 1},
  },
}
