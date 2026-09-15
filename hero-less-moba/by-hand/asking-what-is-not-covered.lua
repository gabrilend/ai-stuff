-- The census: how many of this project's mechanics have a test naming them, and which do
-- not.
--
-- **It cannot be covered by a test, because it is the thing counting them.** A test
-- asserting the census works would be the census marking its own homework, and would be
-- counted by the number it was checking.
--
-- The question below is the one that actually matters about it. A census that names rows
-- nobody can act on is a number that stops being read -- which is how this directory came
-- to exist in the first place.

return {
  covers = {"111a"},

  name = "Asking what is not covered",

  caption = "The census, and the list under it.",

  ground = "person",

  run = "./scripts/census-the-mechanics",

  ask = {
    {"111a", "Is every row it lists as missing something somebody could actually go and " ..
             "write a test for?"},
  },
}
