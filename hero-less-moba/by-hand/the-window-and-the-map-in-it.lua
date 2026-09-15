-- The real viewer, opened paused so the map can be looked at before anything moves.
--
-- Two mechanics, one window, and they fail in ways you can tell apart: the window draws
-- between two snapshots, so if that is wrong the motion steps once a tick; the map draws
-- itself from the same description the simulation walks, so if that is wrong the picture
-- and the game disagree about where things are.

return {
  covers = {"701", "702"},

  name = "The window, and the map in it",

  caption = "A match in a window, paused. Press P to start it. Wheel to zoom -- the zoom " ..
            "goes toward the cursor.",

  ground = "person",

  run = "./run-prototype watch",

  ask = {
    {"702", "At the default view, could you see all three lanes, both bases and the " ..
            "stone at the lane mouths?"},
    {"701", "Once running, did the bodies move smoothly rather than stepping once a tick?"},
  },
}
