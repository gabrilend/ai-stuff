-- The terminal viewer: the whole field as characters, redrawn in place.
--
-- It exists so nobody works blind, and so there are **two** viewers rather than one --
-- which is what stops either of them quietly becoming part of the simulation.

return {
  covers = {"109"},

  name = "Three lanes drawn as text",

  caption = "The map as characters, redrawn in place while a match runs. Ctrl-C to stop.",

  ground = "person",

  run = "./run-prototype terminal",

  ask = {
    {"109", "Could you follow what was happening in all three lanes from the text alone?"},
  },
}
