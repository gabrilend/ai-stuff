-- The sign-posts: three per team, one per lane, clicked in the world rather than in a
-- panel.
--
-- They are the only steering anybody has over a hero, because there is no manual control
-- over one at all -- a hero's entire personality is where it walks and when its abilities
-- fire. So a sign-post that is hard to find, or hard to tell the state of, is a player
-- with no say in half of one of the two economies.

return {
  covers = {"705"},

  name = "Pointing a lane somewhere else",

  caption = "Three sign-posts, one at each of your lanes' corners, clicked where they " ..
            "stand in the world. They steer what walks past them.",

  ground = "person",

  run = "./run-prototype play",

  ask = {
    "Can you find the sign-posts without being told where they are?",
    "Can you tell which way one is currently pointing?",
    "After clicking one, can you see something actually turn?",
    "Can you tell your own sign-posts from the enemy's -- and can you see theirs at all?",
  },
}
