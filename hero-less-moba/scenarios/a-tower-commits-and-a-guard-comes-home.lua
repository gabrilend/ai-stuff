-- A match run from the opening wave until the lanes are grinding against stone.
--
-- **A tower picks the nearest body in range and keeps it while it lives.** The keeping
-- is the whole of a tower's personality. One that re-chose every tick would spread its
-- damage evenly across a wave and kill nobody in it, and the only visible difference
-- from outside is that the wave walks past -- which looks like a balance problem and is
-- not one.
--
-- ## And the thing this test went looking for and did not find
--
-- It was written to watch two rules and it can only claim one. The other is the leash:
-- a guard will walk out at something, turn round at the end of its rope, and **refuse to
-- acquire anything at all on the way back**. That refusal is the rule that matters,
-- because a guard which re-acquires on the way home never gets home, and the ground
-- around the tower it was meant to be denying quietly empties.
--
-- Across five thousand ticks of a real match, with four towers felled and forty bodies
-- fighting at the end of it, **no guard ever enters the leashing state.** The mechanism
-- is there and reads correctly -- the tower pass measures every guard against its leash
-- node each tick and flips the state when it is outside -- so the finding is not that it
-- is broken. It is that ordinary play never asks for it: a guard's reach and its wander
-- both keep it well inside the radius, and the rope is never pulled tight.
--
-- That is left as a claim here rather than deleted, because a change that starts sending
-- guards down the lane should be noticed by something, and this is the only thing
-- watching. But **it does not cover the leashing mechanic** and this file does not claim
-- to: an assertion that a state is never entered is not a demonstration that the state
-- works.

return {
  covers = {"302"},

  name = "A tower commits, and no guard ever leaves",

  caption = "Played from the opening wave until the lanes are grinding against stone. " ..
            "Watch the aiming tower count come off nought as the first bodies walk into " ..
            "reach and stay there while those bodies live. Watch the leashing count, " ..
            "which never comes off nought at all: in ordinary play no guard is ever " ..
            "pulled far enough from its tower to be walked back.",

  ground = "match",

  -- **Stopped while the match is still running.** A claim in the `finally` block is
  -- asked of the world where it stopped, and a finished match is a field with no live
  -- targets in it -- every tower would read as aiming at nothing and the claim below
  -- would fail for the one reason that is not a fault. Five thousand ticks is well into
  -- the contact and well short of the end.
  ticks = 5000,

  measure = {"tick", "alive", "guards", "aiming_towers", "leashing", "fighting",
             "towers", "stone_health"},

  always = {
    -- A tower cannot aim at more things than there are towers.
    {"aiming_towers", "at_most", 18},

    -- **The finding, written as a claim.** Not a rule anybody wants -- a guard that
    -- strays is supposed to be walked back. It is here so that the day this starts
    -- failing, somebody is told that guards have begun leaving their towers, which is
    -- a change in how the ground around stone behaves and would otherwise be invisible.
    {"leashing", "at_most", 0},
  },

  ["finally"] = {
    -- **Towers are shooting.** Nought here after two and a half minutes of contact
    -- would mean no tower ever acquires anything.
    {"aiming_towers", "at_least", 1},

    -- **And stone has been hurt**, which is the other half: a tower that aims and never
    -- fires, and a body that reaches a tower and cannot hit it, both leave this whole.
    {"stone_health", "at_most", 29399},
  },
}
