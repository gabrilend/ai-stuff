-- The proving ground: a window with a straight piece of road in it, a handful of bodies,
-- and only the machinery a scene asked for.
--
-- **The arena is the ground the other tests stand on**, which is why it cannot be tested
-- by one of them without the instrument measuring itself. What is being checked is that
-- the picture is legible and that it is showing the rule it says it is showing -- bodies
-- ringed when they had to move out of somebody, a stray drawn with the room it keeps.

return {
  covers = {"111"},

  name = "A short road and nothing else",

  caption = "A window holding a straight road with a formation on it, held at the gate " ..
            "until you press P. No map, no bases, no stone, no waves -- only the bodies " ..
            "the scene put there and the machinery it named.",

  ground = "person",

  run = "./scripts/run-a-test a-formation-meets-a-stray",

  ask = {
    "Does it open held, so you can look before anything moves?",
    "Can you see the single yellow body standing in the road, drawn with the room it " ..
      "keeps around itself?",
    "When you press P, does the formation walk up to him and filter round rather than " ..
      "stopping or walking through?",
    "Are the bodies that had to step out of somebody ringed, and does the ringing " ..
      "appear where you would expect it to?",
    "Does the readout under the picture change as it runs, and do the numbers match " ..
      "what you can see?",
  },
}
