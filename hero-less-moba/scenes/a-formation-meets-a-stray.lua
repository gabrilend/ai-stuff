-- A formation on the left walking right, and one allied body standing still in the
-- middle of the road.
--
-- The question: what should an army do about one of its own standing in its way?
--
-- The answer this scene is checking the design against is that the **formation should
-- not care.** It keeps its heading, its width and its pace, and the individual bodies
-- whose files run into the stray filter round it and close up again behind. One
-- soldier does not move an army; one soldier moves the three people walking at him.
--
-- What actually happens today is the opposite, and it is the reason the scene exists.

return {
  file = "a-formation-meets-a-stray",
  name = "A formation meets a stray",

  caption = "Fifteen bodies marching right, one ally standing at the middle milestone. " ..
            "The queue rule has one answer -- stop -- so the files that meet him halt, " ..
            "the formation's front waits for its own stragglers, and the whole line " ..
            "parks. Watch the red rings: four bodies blocked stops all fifteen, for ever. " ..
            "It should filter round him and close up behind.",

  -- The mechanics this scene runs, and nothing else is hung on the world.
  --
  -- Walking moves a body, formations decide where each body's place is, the frontline
  -- queue decides whether it may go there, targeting owns the spatial grid the queue
  -- asks its questions through, and waves and the chest are what a body is made out of
  -- at birth. There is no brain, no combat, no phase clock, no spawner, no bot -- so
  -- nothing on this screen is anything but marching.
  want = {"walking", "targeting", "frontline", "formations", "waves", "chest"},

  -- A short straight road, three abreast, the ordinary side-lane width.
  arena = {length = 900, width = 132, files = 3},

  setup = function(world, arena)
    -- Nine melee and six with a reach: an ordinary wave's shape, standing at the left
    -- end with the whole road ahead of it.
    arena.put_a_formation(world, 1, 120, 9, 6)

    -- The stray, dead on the centre line at the middle of the road, where the
    -- formation's own centre file will walk straight into him. On the centre line on
    -- purpose: off to one side he would be a thing one file has to deal with, and in
    -- the middle he is a thing the formation has to decide about.
    arena.put_a_body(world, 1, 500, 0)
  end,
}
