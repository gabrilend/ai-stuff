-- The terminal viewer: the whole field as characters, redrawn in place.
--
-- It exists so that nobody ever works blind, and so that there are **two** viewers rather
-- than one -- which is the thing that stops either of them quietly becoming part of the
-- simulation. A drawing routine that is the only way to see the world will grow an
-- opinion about the world eventually.
--
-- Nothing here can be claimed. Whether a field of text is legible is a question about
-- reading it.

return {
  covers = {"109"},

  name = "Three lanes drawn as text",

  caption = "The whole map as characters in a terminal, redrawn in place as the match " ..
            "runs. Three lanes, two bases, bodies walking them.",

  ground = "person",

  run = "./run-prototype terminal",

  ask = {
    "Can you see three lanes, and tell them apart?",
    "Can you tell the two teams apart?",
    "When a line meets another line, can you see it happen?",
    "Does it redraw in place, rather than scrolling the terminal away?",
  },
}
