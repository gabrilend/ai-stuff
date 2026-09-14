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
-- **Half of that now happens and half does not, and the half that does not is the
-- interesting half.**
--
-- The formation does not care: it holds its depth to within a pace or two the whole
-- way down the road, walks up to the stray and past him, and nothing about its shape
-- changes. Nobody stands inside him -- measured over nine hundred ticks, the closest
-- any two bodies in this scene ever come is half again the room the two of them need.
--
-- But the file he is standing in never gets past him, and after a few hundred ticks
-- the whole line stops. The reason is a property of the rule rather than a bug in it:
-- a body walking dead at an obstacle has its step pushed **straight back along its own
-- path**, because the snap runs from the obstacle's centre through the body's own, and
-- head-on there is no sideways in that direction at all. So the body behind him waits,
-- and the formation's anchor waits for its own stragglers, and one man standing in a
-- field stops fifteen after all.
--
-- Filtering round him needs something the rule does not have: a way for a body to
-- change file. That is W1 through W3 in issue 214, and it is open.
--
-- ## What it does today, which is the picture the scene wanted
--
-- Everything above is the account as it stood before bodies were pushed apart after
-- moving rather than only refused before it. It is left standing because it is how the
-- question was arrived at.
--
-- The formation now **filters round him and closes up behind**, which is exactly what the
-- top of this file says it should do. The column reaches the far end of the road with its
-- depth unchanged. The stray moves a tenth of a pace in nine hundred ticks -- he is walked
-- around, not shoved aside -- and nobody is ever inside anybody, at any tick, by any
-- amount.
--
-- The thing that made it work is not a way to change file. It is that a body which ends a
-- tick inside somebody is pushed out along the line between their centres, and in a crowd
-- those lines point every way at once -- so the sideways the head-on rule has none of
-- turns up as soon as more than two bodies are involved.

return {
  -- Which mechanics a person watching this is watching. The room rule and the size a
  -- body takes up are the subject; the queue is here because what the scene actually
  -- ends up showing is a rank stopping behind somebody, which is what a queue is.
  covers = {"206", "214", "215"},

  name = "A formation meets a stray",

  caption = "Fifteen bodies marching right, one ally standing at the middle milestone. " ..
            "The formation holds its shape and its pace, filters round him, and closes up " ..
            "behind. He is walked around rather than shoved: he moves a tenth of a pace " ..
            "in the whole run. Nobody is ever inside anybody. What makes it work is not a " ..
            "way to change file -- it is that a body ending a tick inside somebody is " ..
            "pushed out along the line between their centres, and in a crowd those lines " ..
            "point every way at once.",

  ground = "arena",

  -- The mechanics this scene runs, and nothing else is hung on the world.
  --
  -- Walking moves a body, formations decide where each body's place is, the frontline
  -- module holds both rules about room -- the rank one and the physical one -- targeting
  -- owns the spatial grid they ask their questions through, and waves and the chest are
  -- what a body is made out of at birth. There is no brain, no combat, no phase clock,
  -- no spawner, no bot -- so nothing on this screen is anything but marching.
  want = {"walking", "targeting", "frontline", "formations", "waves", "chest",
          "patterns"},

  note = "targeting is present for its spatial grid only -- nothing here picks a target, " ..
         "and nothing here is anybody's enemy",

  -- A short straight road, three abreast, the ordinary side-lane width.
  shape = {length = 900, width = 132, files = 3},

  -- Marching: everybody into the grid, every formation plans, every formed body steps.
  -- Named rather than listed, so that what marching consists of is the engine's opinion
  -- and not this file's.
  stages = "marching",

  arrange = {
    -- Nine melee and six with a reach: an ordinary wave's shape, standing at the left
    -- end with the whole road ahead of it.
    {"formation", 1, 120, 9, 6},

    -- The stray, dead on the centre line at the middle of the road, where the
    -- formation's own centre file will walk straight into him. On the centre line on
    -- purpose: off to one side he would be a thing one file has to deal with, and in
    -- the middle he is a thing the formation has to decide about.
    {"body", 1, 500, 0},
  },

  ticks = 900,

  -- True at every tick of the run, not merely when it stops.
  always = {
    -- The rule this scene is really about, stated as a number: **nobody is ever inside
    -- anybody.** Everything else here is a question with no settled answer; this is the
    -- one thing that would be a defect rather than a design decision.
    {"overlaps", "equals", 0},

    -- And the sixteen bodies are on the field the whole way. Nothing in this scene can
    -- kill anything -- there is no combat module hung on the world at all -- so a body
    -- that went missing went missing through a bug in placing or reaping.
    {"bodies", "equals", 15},
    {"strays", "equals", 1},

    -- Nobody leaves the road. The arena is wider than its lane by a full lane width on
    -- every side, so a body stepping aside has somewhere to go -- but stepping *off*
    -- the road is a body escaping the thing it is supposed to be walking down.
    {"off_the_road", "equals", 0},
  },
}
