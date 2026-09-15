-- The headless runner: a whole match at speed, no window, a report at the end.
--
-- A bench cannot check this, because the thing being checked **is** the report -- whether
-- what a person reads afterwards is enough to tell what happened. A reading taken by a
-- test would be a second opinion about a world nobody looked at.

return {
  covers = {"108"},

  name = "A match with nobody watching",

  caption = "One match, no window, a report at the end.",

  ground = "person",

  run = "./run-prototype headless",

  ask = {
    {"108", "Did it play a whole match on its own and print a report naming a winner?"},
  },
}
