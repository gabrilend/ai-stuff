-- The documentation as browsable pages.
--
-- The generator is already checked by a machine -- a page per source file, nothing left
-- behind afterwards, no link pointing at a file that is not there. What cannot be checked
-- that way is whether the result is a thing somebody can read their way around, which is
-- the entire reason it exists.

return {
  covers = {"706"},

  name = "The documents, in a browser",

  caption = "Built and opened at the index. Pick an issue number mentioned somewhere and " ..
            "click it.",

  ground = "person",

  run = "./build-documentation && xdg-open docs/HTML/index.html",

  ask = {
    {"706", "Could you get from the index to a file's notes and on to the issue that " ..
            "asked for that file, by clicking?"},
  },
}
