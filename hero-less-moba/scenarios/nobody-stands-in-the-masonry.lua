-- A whole match, watched for one thing: is anybody standing inside a building?
--
-- **A tower had no size.** The only place one existed was a number typed into a drawing
-- routine -- nineteen paces on a side for a tower, thirty for a library -- so nothing in
-- the simulation knew that stone occupied any ground. Two consequences, and both of them
-- were on screen the whole time for anybody who looked:
--
--   * bodies walked through towers, because the rule about what a body may not stand
--     inside only ever asked about other bodies;
--   * **a tower's own guards were placed inside it.** They were offset from the tower's
--     centre by their own width times their place in the queue, which put the first pair
--     a little under eight paces out, well inside a nineteen-pace square. A guard that is
--     meant to make the ground around a tower dangerous was standing in the masonry.
--
-- A structure now carries a radius on its record, measured to the corner of the square it
-- is drawn as, and the drawing is derived back out of it so the two cannot drift apart
-- again. Guards stand on a ring outside it -- the tower's radius plus their own plus a
-- pace or two of daylight -- spread round it a pair at a time. And the rule about room
-- checks the stone at both ends of the edge a body is walking along, so nothing walks
-- into a building any more either.
--
-- Rubble is still walked over. A fallen tower that went on blocking a lane would make
-- felling one a punishment for the team that managed it.
--
-- ## What it does today, and the one body it cannot account for
--
-- At the first tick, nought. Through the whole opening of a match, nought. Two things got
-- it there beyond the radius itself:
--
--   * **a base tower's guards now stand around the library**, not around the tower that
--     made them. The three towers inside a base sit close enough to the library that a
--     ring drawn outside one of them is still inside the other, and four guards spent
--     every match being shoved back and forth between two walls by a correction that ran
--     every tick and never finished. Standing them around the library is also what the
--     design already said: a base guard is leashed to the library rather than to its
--     tower, because the interior of a base is one open room;
--   * **the separation pass pushes bodies out of stone**, after the crowd has settled and
--     once rather than inside every round -- twenty grid queries times a hundred and
--     twenty-eight rounds took a whole match from nine seconds to longer than anybody
--     waited.
--
-- **And then, about four minutes in, one guard gets wedged and stays wedged.** With seven
-- towers down it goes to one and does not come back to nought. It is not a blip: the same
-- body is inside the same stone for the rest of the match, which means something is
-- walking it back in as fast as the push takes it out. The claim below is left stating
-- the rule rather than the observed number, so this file keeps reporting it.
--
-- ## And the half that is not started at all
--
-- **Wave bodies still walk through towers.** The wider count is nought at the end of a
-- match now, but a column meeting a tower is a column that walks over it rather than
-- round it: the push moves each body out one pace at a time while the column keeps
-- putting them back. Steering a column round a building means saying it in the lane's own
-- coordinates -- how far across the road to go, for how long -- which is the same problem
-- as a body changing file, and is open under that name.

return {
  covers = {"305"},

  name = "Nobody stands in the masonry",

  caption = "A whole match with nobody's hand on it, watching two numbers. Guards " ..
            "inside stone is nought at the first tick, when they are put out on a ring " ..
            "around the tower, and nought at every tick after it. Bodies inside stone " ..
            "is not: a column walking a lane still walks through the tower standing on " ..
            "it, because a lane body has no sideways to be nudged into.",

  ground = "match",

  ticks = 40000,

  measure = {"tick", "alive", "guards", "guards_inside_stone", "inside_stone",
             "towers", "rubble", "libraries"},

  always = {
    -- **The claim.** Not "few" and not "eventually" -- a guard inside a wall is a body
    -- the picture and the simulation disagree about, and one is enough to mean the
    -- ground is not what it is drawn as.
    {"guards_inside_stone", "equals", 0},

    -- And guards exist to be checked. A run where towers had stopped putting anybody
    -- out would satisfy the claim above by having nothing to place.
    {"guards", "at_least", 1},
  },
}
