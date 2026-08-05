#!/usr/bin/env luajit
-- 124-test-quantised.lua
--
-- The small stored form, checked against what it claims about itself. Issue
-- 108.
--
-- For a general: weights at four bits each instead of thirty-two. This
-- checks that the packing and the unpacking are inverses of each other, that
-- the error is where the arithmetic says it should be, and that the bytes
-- laid down are the bytes the format describes -- because a size and a
-- format are different things, and two programs can agree exactly on how
-- many bytes a tensor takes while disagreeing completely about what they
-- mean.
--
-- WHAT THIS DELIBERATELY DOES NOT CHECK: that the quantised product agrees
-- with the plain one. It does not and must not. Quantising loses
-- information; the answer is different and is meant to be. What is checked
-- is that the loss is bounded by what the form's own arithmetic predicts.
--
-- usage:
--   luajit 124-test-quantised.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

say("")
say("  weights at four bits, and what that costs")
say("  " .. string.rep("-", 58))
say("")

local format = dofile(DIR .. "/src/024-blob-format.lua")
local quantised = dofile(DIR .. "/src/123-reference-quantised.lua")
local reference = dofile(DIR .. "/src/035-reference-forward.lua")

local passed, failed = 0, 0
local function check(what, ok, detail)
  if ok then
    passed = passed + 1
    say(string.format("  %-50s ok", what))
  else
    failed = failed + 1
    say(string.format("  %-50s WRONG", what))
    if detail then say("      " .. detail) end
  end
end

local BLOCK = format.block_of("q40")

-- {{{ the 16-bit float, round-tripped
--
-- Written out rather than borrowed, for the same reason the exponential is:
-- a conversion that differs between machines makes every weight downstream
-- of it incomparable. So it is checked on its own before anything uses it.
local f16_exact, f16_trouble = true, nil
for _, value in ipairs({ 0, 1, -1, 0.5, 2, -2, 1024, -1024, 0.0001220703125 }) do
  local back = quantised.from_f16_bits(quantised.to_f16_bits(value))
  if back ~= value then
    f16_exact = false
    f16_trouble = f16_trouble or (value .. " came back as " .. back)
  end
end
check("values a 16-bit float holds exactly come back exactly",
      f16_exact, f16_trouble)

-- and one that it cannot hold: the error is bounded by the spacing at that
-- magnitude, which for a value near one is about one part in a thousand.
local third = quantised.from_f16_bits(quantised.to_f16_bits(1 / 3))
check("and one it cannot hold lands within its own spacing",
      math.abs(third - 1 / 3) < 0.001,
      string.format("%.9g against %.9g", third, 1 / 3))

check("the largest it holds saturates rather than becoming infinite",
      quantised.from_f16_bits(quantised.to_f16_bits(1e30)) < math.huge,
      "a scale of infinity makes a whole block useless; one slightly too "
      .. "small loses only the extremes of one block")
-- }}}

-- {{{ a block round-trips, and the error is where the arithmetic says
--
-- Sixteen steps between the most negative weight and the most positive, so
-- the worst a weight can be wrong by is half a step -- half of the largest
-- magnitude divided by eight. That is a prediction rather than a tolerance,
-- and it is checked as one.
local values = ffi.new("float[?]", BLOCK)
local largest = 0
for index = 0, BLOCK - 1 do
  values[index] = ((index * 2654435761) % 1000003) / 500000.0 - 1.0
  if math.abs(values[index]) > largest then largest = math.abs(values[index]) end
end

local bytes = quantised.quantise(values, BLOCK, format)
check("a block packs to exactly the bytes the format says",
      #bytes == format.block_bytes("q40"),
      #bytes .. " against " .. format.block_bytes("q40"))

local worst, worst_at = 0, nil
for index = 0, BLOCK - 1 do
  local back = quantised.read_weight(bytes, 0, index, format)
  local error_here = math.abs(back - values[index])
  if error_here > worst then worst, worst_at = error_here, index end
end

local step = largest / 8
check("every weight comes back within half a step",
      worst <= step / 2 + 1e-7,
      string.format("worst was %.9g at %d, and half a step is %.9g",
                    worst, worst_at or -1, step / 2))

-- The bound must also be tight, or it is not measuring anything: a
-- quantiser that returned zeroes would pass a loose one.
check("and the worst is close enough to that bound to be real",
      worst > step / 8,
      string.format("worst %.9g against a half-step of %.9g -- suspiciously "
                    .. "small, which is what a quantiser that lost the values "
                    .. "entirely would look like", worst, step / 2))
-- }}}

-- {{{ nothing clips, which is the reason the scale divides by seven
--
-- This is the check that produced the specification. The scale was first
-- written as the largest magnitude over EIGHT, which puts a weight at the
-- positive extreme on index sixteen -- and four bits do not have one, so it
-- clipped. Clipping is not a rounding error: it is unbounded by the step
-- size and it lands on the largest weight in the block, which is the one
-- that matters most. The check above caught it at nearly double the
-- predicted error.
--
-- Dividing by seven leaves index zero unused and guarantees every weight
-- lands between one and fifteen. So that is checked directly, over blocks
-- built to attack it: every value at the positive extreme, every value at
-- the negative extreme, and both extremes in one block.
local layout = format.BLOCK_LAYOUT.q40

local function extremes_of(build)
  local block_values = ffi.new("float[?]", BLOCK)
  for index = 0, BLOCK - 1 do block_values[index] = build(index) end
  local packed_block = quantised.quantise(block_values, BLOCK, format)
  local lowest, highest = 15, 0
  for index = 0, BLOCK - 1 do
    local which_byte = layout.scale_bytes
      + math.floor(index / layout.weights_per_byte) + 1
    local byte = packed_block:byte(which_byte)
    local nibble
    if (index % 2 == 0) == layout.low_nibble_first then
      nibble = byte % 16
    else
      nibble = math.floor(byte / 16)
    end
    if nibble < lowest then lowest = nibble end
    if nibble > highest then highest = nibble end
  end
  return lowest, highest
end

local clipped, clip_trouble = false, nil
local ATTACKS = {
  { name = "everything at the positive extreme", build = function() return 3.5 end },
  { name = "everything at the negative extreme", build = function() return -3.5 end },
  { name = "both extremes together",
    build = function(index) return index % 2 == 0 and 3.5 or -3.5 end },
  { name = "one large value among small ones",
    build = function(index) return index == 0 and 100 or 0.001 end },
}
for _, attack in ipairs(ATTACKS) do
  local lowest, highest = extremes_of(attack.build)
  if lowest == 0 or highest == 15 then
    -- fifteen is reachable and correct; zero is only reachable by clipping
    -- downward, and a run that touches BOTH ends has been squeezed
    if lowest == 0 then
      clipped = true
      clip_trouble = clip_trouble or
        (attack.name .. " produced index zero, which the divisor of seven "
         .. "exists to make unreachable")
    end
  end
end
check("no weight is ever squeezed off the end of the range",
      not clipped, clip_trouble)
-- }}}

-- {{{ the bytes are laid out as described, not merely sized
--
-- A size and a format are different things. This checks the three decisions
-- that a reader guessing would get wrong half the time, and which produce
-- numbers rather than errors when got wrong: where the scale sits, which
-- half of a byte the earlier weight is in, and what the zero point is.

-- a block whose weights are known by construction: all at the top of the
-- range, so every stored weight must be fifteen
local known = ffi.new("float[?]", BLOCK)
for index = 0, BLOCK - 1 do known[index] = 8 end
local known_bytes = quantised.quantise(known, BLOCK, format)

local all_top = true
for at = layout.scale_bytes + 1, #known_bytes do
  if known_bytes:byte(at) ~= 0xff then all_top = false end
end
check("weights at the top of the range store as the top of the range",
      all_top, "the zero point or the range is not what the format says")

-- and one where the two halves of a byte must differ, which is the check
-- that catches a reader taking them in the wrong order
local mixed = ffi.new("float[?]", BLOCK)
for index = 0, BLOCK - 1 do
  mixed[index] = (index % 2 == 0) and 8 or -8
end
local mixed_bytes = quantised.quantise(mixed, BLOCK, format)
local first_pair = mixed_bytes:byte(layout.scale_bytes + 1)
check("the earlier weight is in the half of the byte the format names",
      layout.low_nibble_first and (first_pair % 16) == 15
        or (not layout.low_nibble_first and math.floor(first_pair / 16) == 15),
      string.format("the first byte of weights is 0x%02x, and the earlier "
                    .. "weight should be the %s half", first_pair,
                    layout.low_nibble_first and "low" or "high"))

check("a block of nothing but zeroes costs nothing to store exactly",
      (function()
        local zeroes = ffi.new("float[?]", BLOCK)
        local zero_bytes = quantised.quantise(zeroes, BLOCK, format)
        for at = 0, BLOCK - 1 do
          if quantised.read_weight(zero_bytes, 0, at, format) ~= 0 then
            return false
          end
        end
        return true
      end)(),
      "the one case where quantising loses nothing at all")
-- }}}

-- {{{ the product, against the same product done the slow obvious way
--
-- Not against the plain product -- that answer is different on purpose. This
-- checks the quantised product against unpacking every weight first and
-- multiplying in the same order, which is the same specification written
-- twice: once reading blocks as it goes, once not.
local ROWS, COLUMNS = 5, BLOCK * 3
local matrix = ffi.new("float[?]", ROWS * COLUMNS)
local input = ffi.new("float[?]", COLUMNS)
for index = 0, ROWS * COLUMNS - 1 do
  matrix[index] = ((index * 2654435761) % 1000003) / 500000.0 - 1.0
end
for index = 0, COLUMNS - 1 do
  input[index] = ((index * 40503) % 1000003) / 500000.0 - 1.0
end

local packed = quantised.quantise(matrix, ROWS * COLUMNS, format)
local out = ffi.new("float[?]", ROWS)
quantised.matrix_vector_quantised(out, packed, input, ROWS, COLUMNS, format)

local slow = ffi.new("float[?]", ROWS)
for row = 0, ROWS - 1 do
  local total = 0
  for column = 0, COLUMNS - 1 do
    local weight = quantised.read_weight(packed, row * (COLUMNS / BLOCK)
                                         * format.block_bytes("q40"),
                                         column, format)
    total = quantised.single(total + quantised.single(weight * input[column]))
  end
  slow[row] = total
end

local same, where = true, nil
for row = 0, ROWS - 1 do
  if out[row] ~= slow[row] then
    same = false
    where = where or string.format("row %d: %.9g against %.9g",
                                   row, out[row], slow[row])
  end
end
check("the product agrees with the same sum done the obvious way",
      same, where)
-- }}}

-- {{{ and it does NOT agree with the plain product, which is the point
--
-- If these matched, either the quantising is not doing anything or the
-- comparison is not measuring anything. The difference is bounded, and the
-- bound is what the arithmetic predicts: each weight is out by at most half
-- a step, and the errors accumulate across a row.
local plain = ffi.new("float[?]", ROWS)
for row = 0, ROWS - 1 do
  local total = 0
  for column = 0, COLUMNS - 1 do
    total = quantised.single(
      total + quantised.single(matrix[row * COLUMNS + column] * input[column]))
  end
  plain[row] = total
end

local differs = false
for row = 0, ROWS - 1 do
  if out[row] ~= plain[row] then differs = true end
end
check("and it does not agree with the plain product, on purpose",
      differs,
      "if these matched, either nothing was quantised or nothing was compared")

-- the difference, bounded by what the form's own arithmetic predicts
local worst_row = 0
for row = 0, ROWS - 1 do
  local apart = math.abs(out[row] - plain[row])
  if apart > worst_row then worst_row = apart end
end

local predicted = 0
for column = 0, COLUMNS - 1 do
  predicted = predicted + math.abs(input[column])
end
-- half a step per weight, and a step is the block's largest magnitude over
-- eight. Using the whole matrix's largest is looser than per-block and is
-- the honest direction to be loose in.
local biggest = 0
for index = 0, ROWS * COLUMNS - 1 do
  if math.abs(matrix[index]) > biggest then biggest = math.abs(matrix[index]) end
end
predicted = predicted * (biggest / 8) / 2

check("and the difference stays inside what the arithmetic predicts",
      worst_row <= predicted,
      string.format("worst row differed by %.9g, and the bound is %.9g",
                    worst_row, predicted))

say("")
say(string.format("  quantising this matrix cost %.4f of accuracy at worst,",
                  worst_row))
say(string.format("  and %.2f%% of the space -- %d bytes against %d.",
                  100 * #packed / (ROWS * COLUMNS * 4),
                  #packed, ROWS * COLUMNS * 4))
-- }}}

-- {{{ a run that is not a whole number of blocks is refused
local partial = pcall(quantised.quantise, matrix, BLOCK + 1, format)
check("a run that is not whole blocks is refused, not padded",
      not partial,
      "padding would put the next tensor's first weight inside this "
      .. "tensor's last block")

local partial_row = pcall(quantised.matrix_vector_quantised, out, packed,
                          input, ROWS, BLOCK + 1, format)
check("and a row that would start mid-block is refused too",
      not partial_row,
      "every row must begin where a block begins, or the scales belong to "
      .. "the wrong weights")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not check:")
say("    - that any of it runs on the machine. This is the readable half;")
say("      the assembly is held to these answers on all three architectures")
say("      as one piece of work, and that is the rest of 108.")
say("    - whether a model quantised this way still thinks well. That is a")
say("      question about models rather than about arithmetic, and the only")
say("      honest answer comes from running one.")
say("")

os.exit(failed == 0 and 0 or 1)
-- }}}
