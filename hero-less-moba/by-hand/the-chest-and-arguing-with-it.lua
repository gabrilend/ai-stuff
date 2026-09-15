-- The chest panel, the drag that places an upgrade, and what happens when the game says
-- no.
--
-- This is the centre of the game and it is entirely an interface question. Three people
-- share one chest; the whole design rests on placement being a conversation, and a
-- conversation needs the refusals to be **loud**. A placement that is quietly ignored
-- reads as a placement that worked and then stopped mattering, which is the worst thing
-- an interface can do to somebody who is trying to decide something with two other people.

return {
  covers = {"703", "704"},

  name = "The chest, and arguing with it",

  caption = "The panel holding what your team has drawn, and the drag that puts one of " ..
            "them into a lane or into stone. Try a placement the game will not allow -- " ..
            "during a surge, or onto somebody else's stone -- and see what it does about " ..
            "it.",

  ground = "person",

  run = "./run-prototype play",

  ask = {
    "Can you tell, without clicking anything, what your team is holding?",
    "Does dragging one into a lane work, and can you see afterwards that it landed?",
    "Does a soldier that walks out after that placement look different from one that " ..
      "walked out before it?",
    "When the game refuses a placement, does it say so loudly enough that you would " ..
      "notice while looking somewhere else?",
    "Does the refusal say **why**, rather than just declining?",
    "Is a placement that is on its way -- moving from one slot to another -- visible as " ..
      "being on its way?",
  },
}
