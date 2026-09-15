-- The headless runner: a whole match played at speed with no window at all, and a report
-- at the end of it.
--
-- **Nothing about this can be claimed by a bench**, because the thing being checked is
-- the report -- whether the numbers a person reads after a match are the numbers that
-- match actually produced, and whether they are enough to tell what happened. A reading
-- taken by a test would be a second opinion about a world nobody looked at.
--
-- What it is for: every question about balance in this project ends up here. It is the
-- only way to find out whether the frontline moves, and the report is the whole of the
-- answer -- so a report missing a column is a question nobody can ask.

return {
  covers = {"108"},

  name = "A match with nobody watching",

  caption = "One match, no window, played as fast as the machine will play it, and then " ..
            "a report. It should take a few seconds, name a winner, and say which lane " ..
            "did it.",

  ground = "person",

  run = "./run-prototype headless",

  ask = {
    "Did it finish on its own, rather than running until you stopped it?",
    "Does the report name a winner, and a lane the match was decided in?",
    "Does it say how many bodies were on the field, how many waves were wiped, " ..
      "and how many towers fell?",
    "Is there anything you wanted to know about that match that the report does not say?",
  },
}
