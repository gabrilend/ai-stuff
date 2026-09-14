-- The same two columns that cross in the scene next door, run through a tick with the
-- row that moves anything taken out of it.
--
-- The tick is an ordered array of named systems rather than a function with the order
-- written into its body. That is a claim about the shape of the code, and the way to
-- test a claim about shape is to **change the shape and watch the outcome change**: name
-- a shorter list of stages and the world behaves differently, in exactly the way the
-- missing row predicts and in no other way.
--
-- So this scene runs two rows and stops. Everybody is put into the spatial grid, every
-- formation works out where each of its bodies ought to be standing -- and then nothing
-- steps, because the row that steps was not named. The formations sit exactly as they
-- were placed for the whole run. Thirty bodies, fifteen seconds, not one pace.
--
-- **Two numbers say it.** No movement pattern is ever chosen, because choosing one is
-- the first thing the missing row does; and the widest any body stands from the centre
-- line never changes, because that number moves the instant a formation begins dressing
-- itself. Run the crossing scene beside this one -- same bodies, same road, same
-- arrangement, the full list of rows -- and the second number goes from twenty-two paces
-- to sixty-five while these thirty bodies walk past each other.
--
-- The quieter thing it demonstrates: the grid-building row appears **twice** in the real
-- order, once before the move and once after, because a separation pass reading a grid
-- built before the move misses exactly the pairs that moved into each other. A tick
-- written as a function body would have that repetition buried in it. Written as a list,
-- it is a line you can point at, and a test can leave one of the two out.

return {
  covers = {"104"},

  name = "The tick is a list you can shorten",

  caption = "Two allied columns placed nose to nose, run through a tick made of two " ..
            "rows: put everyone in the grid, and let each formation work out where its " ..
            "bodies belong. The row that takes a step is not in the list. Nothing moves " ..
            "for fifteen seconds. The crossing scene beside this one is the same " ..
            "arrangement with the row put back.",

  ground = "arena",

  want = {"walking", "targeting", "frontline", "formations", "waves", "chest",
          "patterns"},

  note = "targeting is present for its spatial grid only -- nothing here picks a target, " ..
         "and nothing here is anybody's enemy",

  shape = {length = 900, width = 132, files = 3},

  -- **The real rows, named, minus the one that matters.** These come out of the tick's
  -- own table rather than being written again here, so a change to what a stage does
  -- reaches this scene without anybody editing it.
  stages = {"index", "form"},

  arrange = {
    {"formation", 1, 150, 9, 6, 1},
    {"formation", 1, 750, 9, 6, -1},
  },

  ticks = 900,

  measure = {"tick", "alive", "bodies", "patterns", "widest_offset", "going_round",
             "overlaps"},

  always = {
    -- Nothing here can kill anything, and nothing here can move anything either.
    {"bodies", "equals", 30},

    -- **No body ever wants to be anywhere.** Choosing a movement pattern is the first
    -- thing the missing row does, so a shortened list that quietly ran the whole tick
    -- anyway would put this above nought within one tick.
    {"patterns", "equals", 0},

    -- **And nothing dresses its line.** Twenty-two paces is where the two formations
    -- were placed; the crossing scene reaches sixty-five. A tolerance of a tenth of a
    -- pace rather than an exact equality, because the number came out of arithmetic on
    -- positions and insisting on the last bit of a double is insisting on an accident.
    {"widest_offset", "within", 22.0, 0.1},

    -- Nobody was pushed out of anybody, because nobody went anywhere.
    {"going_round", "equals", 0},
    {"overlaps", "equals", 0},
  },
}
