-- A match dropped into a siege-surge with four upgrades sitting in one team's chest.
--
-- The question: what does a surge do to a chest? The answer the design settled on is
-- the counter-intuitive one -- **a surge does not take your upgrades, it deals them.**
-- All three lanes spawn on one shared timer, and the whole chest is split across the
-- three bodies each fire puts out, starting at a random lane so the short share rotates.
--
-- Nothing is lost. What happens instead is that a team's careful concentration in one
-- lane is flattened across three, which is what makes a surge a comeback mechanism: it
-- is not a gift to the loser, it is the removal of the winner's arrangement.
--
-- **The chest does not empty, and that is the thing worth seeing.** "Deals" turned out
-- to mean deals a copy: the count of upgrades held stays exactly where it was for the
-- whole surge while the count of bodies carrying something climbs into the hundreds.
-- Nothing is lost because nothing left. What the surge takes is not the upgrades, it is
-- the arrangement of them -- the concentration in one lane is gone the moment every body
-- leaving any base is stamped from the same pile.
--
-- And nothing at all is earned: towers cannot fall during a surge and there are no
-- discrete waves to wipe, so both of the ways a chest grows are shut off.

return {
  covers = {"601", "602", "603"},

  name = "The surge deals the whole chest",

  caption = "Four upgrades held, then a siege-surge. The chest count does not move. " ..
            "The count of bodies carrying something climbs into the hundreds, because " ..
            "every body the stream puts out is stamped from that same unchanged pile. " ..
            "The tally of wiped waves does not move either, and no tower falls: during " ..
            "a surge there is nothing to earn.",

  ground = "match",

  arrange = {
    {"tick", 3000},
    {"stone", 1, 1, "chest"},
    {"stone", 1, 2, "chest"},
    {"stone", 1, 3, "chest"},
    {"stone", 1, 4, "chest"},
    {"phase", "surge"},
  },

  ticks = 900,

  measure = {"tick", "phase", "alive", "chest", "carried", "wipes", "towers", "rubble"},

  always = {
    -- **Nothing is earned during a surge.** Towers are invulnerable and there are no
    -- waves to wipe, so both counters have to sit exactly where they started.
    {"wipes", "equals", 0},
    {"rubble", "equals", 0},
    {"towers", "equals", 18},

    -- **The chest is never spent.** A surge that emptied it would be a punishment for
    -- holding upgrades, and this is the claim that would catch somebody implementing it
    -- that way by accident.
    {"chest", "equals", 4},
  },

  ["finally"] = {
    -- A stream running for half a minute puts out far more bodies than a wave does, and
    -- every one of them is stamped. Well under what it actually reaches, so that a
    -- change to the stream's rate is not a failure of this test.
    {"carried", "at_least", 40},
  },
}
