-- Two formations of the **same side** walking into each other on one road.
--
-- Nothing here is hostile to anything. Both groups are team 1, and no rule about
-- enemies is loaded at all -- there is no combat, no target selection, no damage. Give
-- the two sides different teams and you get the same picture with every one of those
-- switched on, and then what you are watching is a fight rather than two bodies of
-- troops sharing a road.
--
-- The question: what should happen when two formations want the same ground?
--
-- **Answered, and the answer was neither of the two this scene was built to choose
-- between.** They do not pass through each other and no formation decides to give way,
-- because a formation is not the thing that decides anything: a body may not stand
-- where a body already is, and fifteen of them each declining to do so is the whole of
-- it. See H16 in the open questions.
--
-- What the scene shows now is the consequence, and it is worth looking at rather than
-- reading about. The two columns close, meet, and **stop against each other** --
-- measured, the closest any two bodies come is exactly the room the two of them need,
-- to three decimal places, and nothing ever overlaps. Neither column is deflected,
-- because a body walking dead at an obstacle is pushed straight back along its own
-- path: the snap runs from the obstacle's centre through ours, and head-on that
-- direction has no sideways in it at all.
--
-- **So the rule as it stands produces stopping, not going round.** Going round happens
-- when a body arrives at an angle, and two files walking directly at each other never
-- do. Whether that is the picture wanted, or whether a body needs some way to change
-- file, is W1 through W3 in issue 214 and is not answered.
--
-- ## What it does today, which is not the above
--
-- Everything from here down was found by the first run of this scene under a bench that
-- watches every tick rather than the last one, and it disagrees with the account above.
-- The account is left standing because it is the design, and this is what happened.
--
-- The two columns close, touch at around tick three hundred, and then **squeeze past
-- each other**. By tick eight hundred each has arrived at the end the other started
-- from. They do not stop.
--
-- On the way past, three things happen that the rule says should not:
--
--   * Seven pairs of bodies stand **inside** each other, by up to seventeen
--     thousandths of a pace. Small, and not nothing: the rule is that a body may not
--     stand where a body already is.
--   * Bodies reach sixty-seven and a half paces off the centre line on a road whose
--     half-width is sixty-six. They step **off the road** to get past.
--   * At the end of the run every one of those readings is clean again, which is why
--     none of it was visible until claims were judged over a whole run.
--
-- Whether the passing-through is a regression or the intended answer to H18 -- a body
-- finally being able to change file -- is a question for whoever changed it. The
-- overlapping and the leaving of the road are defects under either reading.

return {
  covers = {"214", "215"},

  name = "Two allied formations want the same ground",

  caption = "Thirty bodies, all on the same side, nothing hostile anywhere and no combat " ..
            "loaded. One formation walks right, one walks left, and the road is empty on " ..
            "both flanks. They meet and stop, touching exactly and overlapping nowhere. " ..
            "Nobody gives way, because head-on there is no sideways in the rule -- a body " ..
            "walking straight at somebody is pushed straight back along its own path.",

  ground = "arena",

  -- Walking, formations and the queue. Targeting appears only because the rules about
  -- room ask "who is near me" through the spatial grid, which lives in that module --
  -- **no body in this scene ever chooses a target**, because nothing that would ask it
  -- to is loaded. Waves and the chest are what a body is made out of at birth.
  want = {"walking", "targeting", "frontline", "formations", "waves", "chest",
          "patterns"},
  note = "targeting is present for its spatial grid only -- nothing here picks a target, " ..
         "and nothing here is anybody's enemy",

  shape = {length = 900, width = 132, files = 3},
  stages = "marching",

  arrange = {
    -- Both team 1. The heading is given explicitly rather than derived from the team,
    -- which is the whole reason the arena lets those two come apart.
    {"formation", 1, 150, 9, 6, 1},
    {"formation", 1, 750, 9, 6, -1},
  },

  ticks = 900,

  -- What the prose above claims, as numbers a run can contradict -- and **it does
  -- contradict them.** See the note at the top of this file. These rows are left
  -- stating the design rule rather than the observed behaviour, because a test that
  -- was edited to agree with a defect is a test that has stopped being able to report
  -- one.
  always = {
    {"overlaps", "equals", 0},
    {"bodies", "equals", 30},
    {"off_the_road", "equals", 0},
  },

  -- Where the two columns end up. Under the rule as written they stop against each
  -- other in the middle, so neither should ever have got near the far end.
  ["finally"] = {
    {"depth", "at_most", 700},
  },

  -- Crowding rather than marching, because the interesting numbers here are about how
  -- close the two columns get and not about how far they went.
  measure = "crowding",
}
