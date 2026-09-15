-- The proving ground: a straight piece of road, a few bodies, and only the machinery the
-- scene asked for.
--
-- **The arena is the ground the other tests stand on**, so a test of it would be the
-- instrument measuring itself.

return {
  covers = {"111"},

  name = "A short road and nothing else",

  caption = "A window holding one formation and one ally standing in its way, held until " ..
            "you press P. Nothing from a match is on the screen: no map, no stone, no " ..
            "waves.",

  ground = "person",

  run = "./scripts/run-a-test a-formation-meets-a-stray",

  ask = {
    {"111", "Did the window open holding, and show you only what the scene put there?"},
  },
}
