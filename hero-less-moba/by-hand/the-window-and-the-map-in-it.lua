-- The real viewer: a window, the whole map, and a match running in it.
--
-- Two mechanics at once because they cannot be separated by looking. The window holds two
-- snapshots and draws between them, and the map draws itself from the same description
-- the simulation walks -- and the only way to tell either of those is working is that the
-- picture is smooth and that what is drawn is where things are.
--
-- **Zoom reveals detail; it never reveals events.** That is the rule the whole viewing
-- layer is built on and it is the third question below: everything a player has to react
-- to has to be legible at the default view, or the game is asking people to hunt.

return {
  covers = {"701", "702"},

  name = "The window, and the map in it",

  caption = "A whole match in a window. Three lanes, two bases, stone at the lane " ..
            "mouths, waves walking out of both ends. Wheel to zoom, and the zoom is " ..
            "anchored to the cursor rather than to the middle of the screen.",

  ground = "person",

  run = "./run-prototype play",

  ask = {
    "Is the movement smooth, rather than stepping once a tick?",
    "At the default view, can you see all three lanes and both bases at once?",
    "Is there anything you have to zoom in to notice, rather than to examine?",
    "Does zooming go toward the cursor rather than the centre of the screen?",
    "Can you tell a melee body from one with a bow without zooming?",
    "When a tower falls, is the rubble still drawn where it was?",
  },
}
