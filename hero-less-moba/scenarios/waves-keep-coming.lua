-- An ordinary match, watched for a minute in the middle of the early game.
--
-- The question: does the spawner keep its promise? A wave is supposed to leave every
-- base every interval, walk down its lane, meet the enemy's, and stop being a wave once
-- the last of it is dead -- and that last part is the half nobody can see.
--
-- **A wave is the unit the upgrade economy is paid in.** Wiping one is what draws a
-- card, so a wave that never notices it is gone is a card that is never drawn, and
-- nothing about the field would look wrong while it happened. That is why the claim
-- here is about the tally of wipes rather than about the bodies: the bodies dying is
-- visible and the wave ending is not.
--
-- The clock starts at a hundred seconds so that all three lanes have troops walking
-- before the run begins, and finishes a minute later, long before any tower is in
-- danger.

return {
  covers = {"207", "208"},

  name = "Waves keep coming, and one of them ends",

  caption = "A hundred seconds in, both bases sending. Watch the wave count climb as " ..
            "the spawner fires and the wipe tally climb behind it as the first columns " ..
            "grind each other down. Six waves on the field would mean one live wave per " ..
            "lane per side; more than that means the lanes are stacking up faster than " ..
            "they are being cleared.",

  ground = "match",

  arrange = {
    {"tick", 3000},
  },

  -- **Two minutes rather than one.** A minute is enough for the waves and was not always
  -- enough for the wipe: whether the first lane finishes the other off inside sixty
  -- seconds depends on where the lines happen to meet, and an unrelated change elsewhere
  -- moved it past the edge once already. What is being claimed is that a wave ends at
  -- all, so the run is given room rather than the claim being weakened.
  ticks = 3600,

  measure = {"tick", "alive", "bodies", "waves", "wipes", "fighting", "phase"},

  always = {
    -- Nothing here is supposed to turn the phase over. A minute of ordinary play that
    -- became a siege-surge halfway through would be measuring a different game.
    {"phase", "equals", 1},
  },

  ["finally"] = {
    -- Six is one live wave per lane per side, which is what an interval that outruns
    -- the killing looks like. Anything at all proves the cadence fired.
    {"waves", "at_least", 6},

    -- **The claim this test exists for.** A wave that is wiped and does not notice
    -- leaves this at nought forever while the field looks perfectly normal.
    {"wipes", "at_least", 1},
  },
}
