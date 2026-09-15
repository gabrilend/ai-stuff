-- The census itself: the count of how many of this project's mechanics have a test naming
-- them, and the list of the ones that do not.
--
-- **It cannot be covered by a test, because it is the thing counting them.** A test
-- asserting the census works would be the census marking its own homework, and it would
-- be counted by the number it was checking.
--
-- So it is read by a person, which is also the only way to check the thing that actually
-- matters about it: whether the list of what is missing is a list somebody can act on.
-- A census that says forty-nine of eighty and names thirty-one rows nobody can do
-- anything about is a number that stops being read.
--
-- This file is also the answer to a question the census raised about itself. A third of
-- what it counted was tools and windows rather than mechanics a world can be measured
-- for, and those rows were never going to come off the list. The answer was to ask a
-- person instead -- which is what the directory this file sits in is for, and this test
-- is the smallest possible example of it.

return {
  covers = {"111a"},

  name = "Asking what is not covered",

  caption = "The census, and the list under it. Run it, read the number, and read the " ..
            "rows it says have no test.",

  ground = "person",

  run = "./scripts/census-the-mechanics",

  ask = {
    "Does the number look right to you, against what you know is built?",
    "Take one row it says has no test -- is that true? Is there really nothing " ..
      "checking it?",
    "Is every row on that list something somebody could write a test for, or are some " ..
      "of them things that only a person can look at?",
    "Does the documentation validator fail on this, and is that the behaviour you want " ..
      "while the list is still long?",
  },
}
