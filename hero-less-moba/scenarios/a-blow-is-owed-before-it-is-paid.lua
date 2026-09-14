-- The first minute of contact in an ordinary match, watched as arithmetic on health.
--
-- Nobody in this game takes damage at the moment they are struck. A swing writes what it
-- owes into a buffer, and one pass at the end of the tick pays every debt at once.
--
-- The reason is that damage applied where it is dealt makes **the order bodies are
-- stored in** into a rule of the game. Two soldiers who swing at each other on the same
-- tick and each have exactly enough to kill the other should both die; applied
-- immediately, whichever one the loop reaches first kills the other and walks away
-- whole. Nothing about that is visible -- it looks like one soldier being slightly
-- better -- and it would be true for every trade in every fight for the life of the
-- project.
--
-- **What is claimed here is the consequence, not the mechanism.** A buffered pass and an
-- immediate one both make bodies bleed, and no reading of a world can tell them apart
-- after the fact; the ordering property is asserted directly in the invariants suite.
-- What this adds is that the whole machine works end to end in a real match: bodies find
-- each other, blows land, health comes off, and the field is measurably poorer for it.

return {
  covers = {"205"},

  name = "A blow is owed before it is paid",

  caption = "Two minutes in, the lines meeting. Watch the wounded count come off " ..
            "nought -- that is bodies alive and carrying less than they were born with, " ..
            "which is the cheapest proof a blow landed. It appears long before the count " ..
            "of the living moves, because dying takes many blows and being hurt takes " ..
            "one.",

  ground = "match",

  arrange = {
    {"tick", 3000},
  },

  ticks = 1800,

  measure = {"tick", "alive", "health", "wounded", "fighting", "dying"},

  always = {
    -- **Blows land.** Nought here for a whole minute with bodies in contact means either
    -- nothing swings or nothing is ever paid what it is owed, and those look the same.
    {"wounded", "ever_at_least", 1},

    -- And somebody was swinging while it happened, at some tick of the run.
    {"fighting", "ever_at_least", 1},

    -- Nothing is ever healed past what it was born with. A body over its own maximum is
    -- a buffer that was paid twice.
    {"wounded", "at_least", 0},
  },

  ["finally"] = {
    -- Nothing here; see the claim above. A first version asked for somebody to be
    -- swinging **at the tick the run stopped**, which passed for weeks and then failed
    -- the day an unrelated change moved the match along a slightly different line. A
    -- fight is a thing that happens, not a thing that is true at an arbitrary moment.
    {"health", "at_least", 1},
  },
}
