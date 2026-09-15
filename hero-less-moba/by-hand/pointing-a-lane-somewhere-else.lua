-- The sign-posts: three per team, clicked where they stand in the world.
--
-- They are the only steering anybody has over a hero, because there is no manual control
-- over one at all. A sign-post that cannot be found is a player with no say in half of
-- one of the two economies.

return {
  covers = {"705"},

  name = "Pointing a lane somewhere else",

  caption = "A match in a window. Find one of your three sign-posts in the world and " ..
            "click it.",

  ground = "person",

  run = "./run-prototype play",

  ask = {
    {"705", "Did you find a sign-post without being told where it was, and did clicking " ..
            "it visibly change which way it points?"},
  },
}
