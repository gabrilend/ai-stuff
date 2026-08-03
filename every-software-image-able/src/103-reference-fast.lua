-- 103-reference-fast.lua
--
-- The readable twin of the fast matrix product. A second specification, not
-- a faster version of the first.
--
-- For a general: the exact kernel adds each product into one running total,
-- in order, so its answer is the same on every machine that has ever run it.
-- Keeping that order is what costs the speed -- each addition waits for the
-- one before it, and the processor's adder idles in between. This one keeps
-- four totals and lets four additions be in flight at once.
--
-- THE ANSWER DIFFERS, AND THAT IS THE TRADE. Floating-point addition is not
-- associative: adding the same numbers in a different order gives a
-- different result in the last bits. Neither is wrong. They are answers to
-- slightly different questions, and this file writes down which question
-- this one answers so that an assembly version can be held to it exactly.
--
-- WHAT IS GIVEN UP, said plainly. Two machines of different architectures
-- running this will produce slightly different numbers, so a thought that
-- came out of one cannot be reproduced on the other. That was a deliberate
-- decision: the same machine remains perfectly reproducible, and the exact
-- kernel remains available for proving that a port is honest.
--
-- WHAT IS KEPT. On one machine, this is as deterministic as the exact one --
-- same image, same carried numbers, same input, same output, every time.
-- Determinism was never the thing being given up; portability of the exact
-- bits was.

local ffi = require("ffi")

local M = {}

-- {{{ single -- one value, rounded the way the machine rounds
--
-- Every accumulation is single precision, exactly as in the exact
-- specification. That part does not change: what changes is only HOW MANY
-- accumulators there are and the order they are combined in.
local box = ffi.new("float[1]")
local function single(value)
  box[0] = value
  return box[0]
end
M.single = single
-- }}}

-- {{{ M.LANES -- how many totals are kept at once
--
-- Four, because that is how many single-precision numbers fit in one vector
-- register on the architectures this project targets. It is a property of
-- the silicon rather than a tuning choice, which is why it is named here
-- rather than being a number somebody could raise.
M.LANES = 4
-- }}}

-- {{{ M.matrix_vector_fast(out, matrix, input, rows, columns)
-- One row at a time, four totals at a time.
--
-- The combining order is part of the specification. It follows what the
-- vector instructions naturally do rather than what reads most tidily:
--
--   lane0 += lane2 and lane1 += lane3, together
--   then lane0 += lane1
--   then anything that did not fit in a group of four, one at a time
--
-- Written the other way round -- remainder first, or a left-to-right sum of
-- the four -- gives a different answer, and a reader who assumes the tidy
-- order will be looking at a disagreement that is really a misreading.
function M.matrix_vector_fast(out, matrix, input, rows, columns)
  for row = 0, rows - 1 do
    local lane = { 0, 0, 0, 0 }
    local whole = columns - (columns % M.LANES)
    local base = row * columns

    local column = 0
    while column < whole do
      for slot = 0, M.LANES - 1 do
        local product = single(single(matrix[base + column + slot])
                               * single(input[column + slot]))
        lane[slot + 1] = single(lane[slot + 1] + product)
      end
      column = column + M.LANES
    end

    -- the combining, in the order the instructions do it
    local first = single(lane[1] + lane[3])
    local second = single(lane[2] + lane[4])
    local total = single(first + second)

    -- and the remainder afterwards, one at a time
    while column < columns do
      local product = single(single(matrix[base + column])
                             * single(input[column]))
      total = single(total + product)
      column = column + 1
    end

    out[row] = total
  end
  return out
end
-- }}}

-- {{{ M.differs_from_exact(fast, exact, count)
-- How far apart the two specifications land, so the price of the speed is a
-- measured number rather than an assurance.
--
-- Reported as the largest relative difference rather than the largest
-- absolute one: the values in a forward pass span several orders of
-- magnitude, and an absolute difference says more about the size of the
-- numbers than about the arithmetic.
function M.differs_from_exact(fast, exact, count)
  local worst, worst_at = 0, nil
  local same = 0
  for index = 0, count - 1 do
    if fast[index] == exact[index] then
      same = same + 1
    else
      local scale = math.abs(exact[index])
      if scale > 0 then
        local relative = math.abs(fast[index] - exact[index]) / scale
        if relative > worst then worst, worst_at = relative, index end
      end
    end
  end
  return { worst = worst, at = worst_at, identical = same, of = count }
end
-- }}}

return M
