-- The chest panel and the drag that places an upgrade, and what happens when the game
-- says no.
--
-- Three people share one chest, so placement is a conversation -- and a conversation needs
-- the refusals to be **loud**. A placement quietly ignored reads as one that worked and
-- then stopped mattering, which is the worst thing this interface can do to somebody
-- deciding something with two other people.

return {
  covers = {"703", "704"},

  name = "The chest, and arguing with it",

  caption = "A match in a window. Drag an upgrade from the panel into one of your lanes. " ..
            "Then try one the game will not allow -- another player's stone, or anything " ..
            "at all during a siege-surge.",

  ground = "person",

  run = "./run-prototype play",

  ask = {
    {"703", "Did dragging an upgrade into a lane work, and could you see afterwards " ..
            "that it had landed there?"},
    {"704", "When a placement was refused, did you notice without looking for it, and " ..
            "did it say why?"},
  },
}
