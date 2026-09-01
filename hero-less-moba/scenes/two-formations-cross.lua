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
-- What should happen is that one goes round the other, as a body, keeping its shape.
-- Two formations do not interpenetrate and they do not stop and stare at each other.
--
-- What happens today is the queue rule's only answer, applied fifteen times over: the
-- files that meet halt, both anchors wait for their own stragglers, and two armies park
-- nose to nose in the middle of an empty road with a hundred paces of clear ground on
-- either side of them.

return {
  file = "two-formations-cross",
  name = "Two allied formations want the same ground",

  caption = "Thirty bodies, all on the same side, nothing hostile anywhere and no combat " ..
            "loaded. One formation walks right, one walks left, and the road is empty on " ..
            "both flanks. They should pass -- one giving way as a body, keeping its line. " ..
            "Instead every file that meets another stops, and both formations park.",

  -- Walking, formations and the queue. Targeting appears only because the queue asks
  -- "who is near me" through the spatial grid, which lives in that module -- **no body
  -- in this scene ever chooses a target**, because nothing that would ask it to is
  -- loaded. Waves and the chest are what a body is made out of at birth.
  want = {"walking", "targeting", "frontline", "formations", "waves", "chest"},
  note = "targeting is present for its spatial grid only -- nothing here picks a target, " ..
         "and nothing here is anybody's enemy",

  arena = {length = 900, width = 132, files = 3},

  setup = function(world, arena)
    -- Both team 1. The heading is given explicitly rather than derived from the team,
    -- which is the whole reason the arena lets those two come apart.
    arena.put_a_formation(world, 1, 150, 9, 6, 1)
    arena.put_a_formation(world, 1, 750, 9, 6, -1)
  end,
}
