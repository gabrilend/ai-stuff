-- An ordinary match read as a question about movement rather than about fighting.
--
-- Every body that goes anywhere in this game does it in two steps that used to be one.
-- A **pattern** writes down where the body wants to be and how urgently, in world paces,
-- for every kind of body alike. Then a single mover pulls that want back to one pace of
-- ground, moves it out of anybody already standing there, and puts the body down. The
-- pattern may not look at what is in the way; the mover may not have an opinion about
-- where anybody is going.
--
-- That split replaced nine early returns inside one walking routine. Every one of them
-- was correct, and the *order between them* was the policy -- which meant the policy
-- could only be read by reading the sequence, and could only be changed by moving a
-- return statement past another one. They are rows in a table now, tried in order, and
-- the order is a line of the file rather than a shape of the control flow.
--
-- Three things are watched, and each is the visible consequence of one of those claims:
--
--   * bodies **walk the graph** -- they leave a base, follow the edges of their lane and
--     get somewhere, which is the front creeping up the road;
--   * **more than one row is in use at once**, which is what makes it a table rather than
--     a routine with an unused table beside it;
--   * **some bodies hurry**, which is the gait reversal -- hurry is faster than marching,
--     and a body that has left the line to charge is allowed to run.
--
-- The gait count is read at the tick it is taken rather than tallied, because a pace is
-- chosen fresh every tick by whichever pattern placed the goal. A column that charged and
-- settled back into a march reads nought afterwards, correctly.

return {
  covers = {"202", "216", "216a", "216b", "216c"},

  name = "How a body decides where to put its foot",

  caption = "A hundred seconds in, watched for a minute. The front creeps up the road " ..
            "as bodies walk the edges of their lane. Watch the count of movement " ..
            "patterns in use come off one as the first bodies leave their lines, and the " ..
            "count of bodies hurrying come off nought behind it -- that is charging, " ..
            "which is faster than marching and is the only place it is allowed to be.",

  ground = "match",

  arrange = {
    {"tick", 3000},
  },

  ticks = 1800,

  measure = {"tick", "alive", "bodies", "front", "back", "patterns", "hurrying",
             "walking", "closing"},

  ["finally"] = {
    -- **They walked.** Bodies leave a base at nought and this is how far the leading one
    -- has got along its lane, which is only possible by following edges.
    {"front", "at_least", 500},
  },

  always = {
    -- **The table is a table.** One row doing all the work, with four kept beside it for
    -- decoration, looks identical from outside until you count.
    {"patterns", "ever_at_least", 2},

    -- **And hurry exists.** Nought here for a whole minute of a match would mean the
    -- fastest gait is never reached by anything, which would make it a number in a
    -- catalogue rather than a rule.
    {"hurrying", "ever_at_least", 1},
  },
}
