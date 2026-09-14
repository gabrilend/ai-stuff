-- Two minutes into an ordinary match, watched for a minute while the first lines meet.
--
-- The question: does killing pay, and does what it pays get spent? Two economies run
-- side by side in this game and only one of them is shared. The chest is the team's; the
-- wallet is the person's, filled by **every kill the team lands** rather than by the
-- kills that person's bodies happened to get -- so teammates have identical incomes and
-- the only thing separating two of them is what they do with the same money.
--
-- That design decision is the thing this watches. A wallet that filled only on your own
-- kills would produce a death spiral: the player whose lane is losing earns least and so
-- can do least about it. A wallet that fills on the team's kills cannot.
--
-- What is bought with it never comes back. A hero is an ordinary soldier record with a
-- bigger row behind it -- same brain, same movement, same combat -- which is why there is
-- no second system here to go wrong and why the count of heroes standing is a reading
-- about bodies rather than about purchases.

return {
  covers = {"502", "503"},

  name = "A kill pays the whole team",

  caption = "A hundred seconds in, the first lines meeting. Watch the wallets fill as " ..
            "bodies start dying, and the count of heroes standing climb behind them. " ..
            "Nothing here is placed by hand -- the bots buy, and what they buy walks out " ..
            "of a base like anything else.",

  ground = "match",

  arrange = {
    {"tick", 3000},
  },

  ticks = 1800,

  measure = {"tick", "alive", "fighting", "wallets", "bought", "heroes"},

  ["finally"] = {
    -- Something died, and somebody was paid for it. Nought here with bodies fighting
    -- would mean a kill pays nobody at all.
    {"wallets", "at_least", 1},

    -- And it was spent. A wallet that fills and never empties is a wallet nothing can
    -- be done with, which is the same as no wallet.
    {"bought", "at_least", 1},

    -- **The proof that a bought thing is a body.** A purchase that incremented a tally
    -- and put nothing on the field would satisfy the claim above and fail this one.
    {"heroes", "at_least", 1},
  },
}
