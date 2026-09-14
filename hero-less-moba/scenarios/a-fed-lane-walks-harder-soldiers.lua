-- One upgrade dropped into one team's top lane before the run starts, and nothing else
-- different about the match at all.
--
-- The question: does placing a thing in a lane actually reach the soldiers walking down
-- it? Placing is a number moving from one count to another -- there is no upgrade object
-- that could be handed to anybody -- so the only evidence that it landed is that bodies
-- start coming out of the base carrying something.
--
-- **A body is stamped once, at birth, and never reads the team's slots again.** That is
-- why this test has to wait: the soldiers already on the field when the stone is placed
-- carry nothing and will carry nothing for the rest of their lives. The first wave that
-- leaves the base after the placement is the first wave that is any different. A test
-- that measured immediately would report a placement that had gone nowhere, and would be
-- describing the rule rather than a fault.

return {
  covers = {"404", "405"},

  name = "A fed lane walks harder soldiers",

  caption = "One Whetstone in the blue team's top lane, placed before anybody moves. " ..
            "The count of upgrades sitting in a slot goes to one immediately; the count " ..
            "of bodies carrying one stays at nought until the next wave leaves the base " ..
            "and then climbs a wave at a time. The soldiers already walking never " ..
            "change -- they were stamped when they were made.",

  ground = "match",

  arrange = {
    {"tick", 3000},
    -- Team one, the first upgrade kind, into a lane slot, lane one.
    {"stone", 1, 1, "lane", 1},
  },

  ticks = 1800,

  measure = {"tick", "alive", "bodies", "chest", "placed", "carried", "waves"},

  always = {
    -- It is placed from the first tick, and nothing in an ordinary minute takes it
    -- back out again. A transit would show up here as this dropping to nought.
    {"placed", "at_least", 1},
  },

  ["finally"] = {
    -- The bodies that have been born since. One wave of one lane of one team is about
    -- a dozen, and the run is long enough for one of them to be out and walking.
    --
    -- **Half a wave rather than the number this actually reaches**, which is ten. A
    -- claim pinned to the exact figure would fail the day somebody changes a wave's
    -- composition or the interval between them, and neither of those has anything to
    -- do with whether a stamp reaches a soldier.
    {"carried", "at_least", 6},
  },
}
