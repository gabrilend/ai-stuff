-- An ordinary match in full flow, read as five numbers instead of as a picture.
--
-- The brain is a dispatch table with a row per state and no chain of conditions anywhere
-- in it: a body is walking, closing on something, fighting it, walking back to a tower
-- it strayed from, or dying. Which row runs is the whole of what a body is doing.
--
-- The question this asks is whether the table is actually a table. A dispatch table that
-- has quietly collapsed into one busy row and four dead ones looks exactly like a
-- working one from outside -- the bodies still march, still meet, still die -- and the
-- only way to tell is to count how many rows are in use at once.
--
-- **Two of the seven rows are deliberately empty.** Waiting and recovering exist in the
-- table so that it is the list of states rather than the list of built ones, and nothing
-- here counts them: a reading that returned nought forever would be indistinguishable
-- from a broken one.

return {
  covers = {"203"},

  name = "Every body is doing one of five things",

  caption = "A minute of ordinary play, with every living body sorted into the row of " ..
            "the brain it is running. The five add up to the living. Watch closing " ..
            "appear as the lines find each other and fighting appear behind it -- and " ..
            "watch leashing stay at nothing, because no guard has been pulled off its " ..
            "tower yet.",

  ground = "match",

  arrange = {
    {"tick", 3000},
  },

  ticks = 1800,

  measure = {"tick", "alive", "walking", "closing", "fighting", "leashing", "dying"},

  always = {
    -- Three rows in use, which is the least that can be called a table.
    --
    -- **Asked of the highest each reached rather than of the last tick.** A first version
    -- asked for somebody to be fighting at the moment the run stopped; it passed, and then
    -- failed the day an unrelated change moved the match along a slightly different line
    -- and the last tick happened to fall between two engagements. Which row of a dispatch
    -- table has ever run is the question; which one is running at an arbitrary instant is
    -- not.
    {"walking", "ever_at_least", 1},
    {"closing", "ever_at_least", 1},
    {"fighting", "ever_at_least", 1},

    -- And the two rows that are not built stay empty. A count coming off nought here
    -- would mean a state nobody has written is being entered.
    {"leashing", "at_most", 0},
  },
}
