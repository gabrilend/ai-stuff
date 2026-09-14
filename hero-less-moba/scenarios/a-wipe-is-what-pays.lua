-- An ordinary match watched for two minutes across the moment the first wave is wiped.
--
-- The question: where does an upgrade come from? Not from time, and not from kills. A
-- chest grows when a **whole wave** is wiped out, which is a different event from killing
-- a lot of people in a lane: it requires the last one, and requiring the last one is what
-- makes a lane either worth pushing or not worth pushing rather than worth grinding.
--
-- Both halves have to be true and they fail independently. A wipe that is not noticed
-- pays nothing, and the field looks perfectly ordinary while it happens. A draw that
-- happens without a wipe pays everybody constantly and the whole economy goes flat.
--
-- So the two numbers are watched together: the tally of wipes, which only ever rises, and
-- the upgrades held in hand.
--
-- **What has been placed is watched and not claimed.** A bot is playing both sides and a
-- bot places what it draws, so the count in the lanes is a reading about how the bots
-- happen to be playing this particular match rather than about whether a wipe pays.
-- Claiming it passed for a while and then failed on a run where the bots had not got
-- round to placing yet, which is a test reporting the wrong thing having gone right.

return {
  covers = {"403"},

  name = "A wipe is what pays",

  caption = "Two minutes of ordinary play from a hundred seconds in. The wipe tally " ..
            "climbs as lanes finish each other off, and the upgrades appear behind it -- " ..
            "some still in hand, some already put into lanes by the bots. A chest that " ..
            "filled without a wipe, or a wipe that paid nothing, would both look like " ..
            "an ordinary match from the outside.",

  ground = "match",

  arrange = {
    {"tick", 3000},
  },

  ticks = 3600,

  measure = {"tick", "alive", "waves", "wipes", "chest", "placed"},

  ["finally"] = {
    -- Waves were finished off.
    {"wipes", "at_least", 1},

    -- **And it paid.** Nought in both of these with the tally above at anything is a
    -- wipe that nobody was paid for. They are claimed separately rather than added,
    -- because a reading is one number and adding two of them would be arithmetic in
    -- a test -- which is the one thing a test here is not allowed to contain.
    {"chest", "at_least", 1},
  },

}
