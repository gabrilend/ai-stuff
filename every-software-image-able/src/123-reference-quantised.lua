-- 123-reference-quantised.lua
--
-- The readable specification of the small stored form: turning plain numbers
-- into blocks, turning blocks back into numbers, and the matrix product that
-- reads them without ever unpacking a whole tensor. Issue 108.
--
-- For a general: weights stored at four bits each instead of thirty-two, so
-- a model that needed four gigabytes needs about six hundred megabytes. The
-- cost is that every use of a weight has to undo the packing first, inside
-- the innermost loop of the machine.
--
-- THIS IS A SEPARATE SPECIFICATION, NOT A SMALLER VERSION OF THE PLAIN ONE.
-- Quantising loses information: the answer is different, and it is meant to
-- be. So this is never compared against the exact product. It is written down
-- here, its answers are recorded, and the assembly versions are held to
-- THESE -- exactly as the four-totals product is held to its own rather than
-- to the exact one it is faster than.
--
-- WHERE THE ARITHMETIC IS THE SPECIFICATION, and there are three places:
--
--   ONE. The scale is the largest magnitude in the block divided by SEVEN,
--   and the reason is the whole difference between a bound and a hope.
--
--   Four bits with a zero point of eight run from minus eight to plus seven
--   -- sixteen levels, but not symmetric. Dividing by eight puts the most
--   extreme weight at index sixteen if it happens to be positive, which does
--   not exist, so it clips. Clipping is not a rounding error: it is
--   unbounded by the step size, and it happens to exactly the largest weight
--   in the block, which is the one that matters most.
--
--   Dividing by seven leaves index zero unused and guarantees that nothing
--   ever clips: every weight lands between one and fifteen, and the error is
--   never worse than half a step. The cost is one level of sixteen, which
--   makes the step one seventh of the largest magnitude instead of one
--   eighth -- and one seventh of a half beats one eighth of one and a half.
--
--   The usual arrangement elsewhere divides by minus eight, which puts the
--   extreme at index zero and clips only in the opposite direction. That is
--   a real choice and it is not this one: it trades a guarantee for slightly
--   finer steps, and a guarantee is worth more here, because this project
--   holds three implementations to identical answers and an unbounded case
--   is where three implementations stop agreeing.
--
--   TWO. The scale is rounded to a 16-bit float BEFORE any weight is
--   quantised against it. The stored scale is what the machine will read, so
--   quantising against the unrounded one produces weights chosen for a scale
--   that no longer exists.
--
--   THREE. Every accumulation in the product is single precision, in
--   ascending index order, exactly as in the plain product. The dequantising
--   changes what is multiplied, not how the sum is built.

local ffi = require("ffi")

local M = {}

-- {{{ the two numbers the specification turns on
--
-- Named rather than repeated, because both appear in the quantiser, in the
-- product, and in every assembly version that will be held to this -- and a
-- constant that appears in five places is a constant that will eventually
-- appear as two different numbers.
--
-- THE ZERO POINT is what a stored weight of that value stands for: zero.
-- Four bits hold nought to fifteen and the values wanted are signed, so the
-- middle of the range is where nothing is.
M.ZERO_POINT = 8

-- THE DIVISOR chooses the scale: the largest magnitude in a block, over
-- this. Seven rather than eight is the no-clipping guarantee -- see the
-- header.
M.SCALE_DIVISOR = 7
-- }}}

-- {{{ single -- one value, rounded the way the machine rounds
local box = ffi.new("float[1]")
local function single(value)
  box[0] = value
  return box[0]
end
M.single = single
-- }}}

-- {{{ M.to_f16_bits(value) / M.from_f16_bits(bits)
--
-- A 16-bit float, written out rather than borrowed, for the same reason the
-- exponential is: a conversion that differs between machines makes every
-- weight downstream of it incomparable. One sign bit, five exponent bits,
-- ten mantissa bits, and a bias of fifteen.
--
-- Rounding is to nearest with ties going to even, which is what every
-- machine here does by default and what the assembly will have to match.
function M.to_f16_bits(value)
  local as_single = single(value)
  local sign = 0
  if as_single < 0 or (as_single == 0 and 1 / as_single < 0) then
    sign = 1
    as_single = -as_single
  end

  if as_single ~= as_single then return sign * 0x8000 + 0x7e00 end   -- not a number
  if as_single == math.huge then return sign * 0x8000 + 0x7c00 end

  -- the largest a 16-bit float holds, and anything past it saturates rather
  -- than becoming infinity: a scale of infinity makes a whole block useless,
  -- and a scale slightly too small only loses the extremes of one block.
  if as_single >= 65520 then return sign * 0x8000 + 0x7bff end
  if as_single == 0 then return sign * 0x8000 end

  local exponent = math.floor(math.log(as_single) / math.log(2))
  -- the logarithm can land a step out at a boundary, so it is corrected by
  -- comparison rather than trusted
  if 2 ^ exponent > as_single then exponent = exponent - 1 end
  if 2 ^ (exponent + 1) <= as_single then exponent = exponent + 1 end

  if exponent < -14 then
    -- below the smallest normal one: stored without an implied leading one
    local mantissa = M.round_to_even(as_single / 2 ^ -24)
    if mantissa >= 1024 then
      return sign * 0x8000 + 0x0400          -- rounded up into the normals
    end
    return sign * 0x8000 + mantissa
  end

  local mantissa = M.round_to_even(as_single / 2 ^ exponent * 1024) - 1024
  if mantissa >= 1024 then                   -- rounded up past the top
    mantissa = 0
    exponent = exponent + 1
    if exponent > 15 then return sign * 0x8000 + 0x7bff end
  end
  return sign * 0x8000 + (exponent + 15) * 1024 + mantissa
end

function M.from_f16_bits(bits)
  local sign = math.floor(bits / 0x8000) % 2
  local exponent = math.floor(bits / 1024) % 32
  local mantissa = bits % 1024
  local value
  if exponent == 0 then
    value = mantissa * 2 ^ -24
  elseif exponent == 31 then
    value = mantissa == 0 and math.huge or (0 / 0)
  else
    value = (1024 + mantissa) * 2 ^ (exponent - 15 - 10)
  end
  if sign == 1 then value = -value end
  return single(value)
end
-- }}}

-- {{{ M.round_to_even(value)
-- To the nearest whole number, with a value exactly halfway going to the
-- even one. Named and separate because it is the rule the hardware uses and
-- the obvious alternatives -- always up, or away from zero -- differ from it
-- on exactly the values that occur most often when quantising, which are the
-- halves.
function M.round_to_even(value)
  local down = math.floor(value)
  local remainder = value - down
  if remainder > 0.5 then return down + 1 end
  if remainder < 0.5 then return down end
  if down % 2 == 0 then return down end
  return down + 1
end
-- }}}

-- {{{ M.quantise_block(values, at, block)
-- One block of plain numbers into a scale and a run of four-bit weights.
--
-- Returns the scale's 16-bit pattern and an array of `block` numbers, each 0
-- to 15. Nothing here is packed into bytes yet -- that is layout, and it
-- happens in `pack_block` below, so that the arithmetic and the byte order
-- are separately checkable.
function M.quantise_block(values, at, block)
  local largest = 0
  for index = 0, block - 1 do
    local magnitude = math.abs(values[at + index])
    if magnitude > largest then largest = magnitude end
  end

  -- A block of nothing but zeroes has no largest magnitude to scale by. Its
  -- scale is zero, every weight is the zero point, and everything comes back
  -- as zero -- which is exact, and is the one case where quantising loses
  -- nothing at all.
  if largest == 0 then
    local weights = {}
    for index = 1, block do weights[index] = M.ZERO_POINT end
    return M.to_f16_bits(0), weights
  end

  -- Divided by seven rather than eight, so nothing ever clips -- see the
  -- header. Index zero goes unused and every weight lands between one and
  -- fifteen.
  local scale_bits = M.to_f16_bits(largest / M.SCALE_DIVISOR)
  -- and the weights are chosen against the scale AS STORED, not as computed
  local scale = M.from_f16_bits(scale_bits)

  local weights = {}
  for index = 0, block - 1 do
    local quantised = M.ZERO_POINT
    if scale ~= 0 then
      quantised = M.round_to_even(single(values[at + index] / scale))
                  + M.ZERO_POINT
    end
    -- The clamp stays, and it is a genuine last resort rather than the
    -- working path. Rounding the scale to sixteen bits can nudge it a hair
    -- below the value it was computed from, which puts the extreme weight a
    -- hair past seven. Nothing else can reach here, and a reader still has
    -- to handle index zero because a block made by hand may contain one.
    if quantised < 0 then quantised = 0 end
    if quantised > 15 then quantised = 15 end
    weights[index + 1] = quantised
  end
  return scale_bits, weights
end
-- }}}

-- {{{ M.pack_block(scale_bits, weights, layout)
-- A scale and its weights into the exact bytes the format describes: the
-- scale low byte first, then two weights per byte with the earlier weight in
-- the low four bits.
function M.pack_block(scale_bits, weights, layout)
  local bytes = { scale_bits % 256, math.floor(scale_bits / 256) }
  for index = 1, #weights, 2 do
    local low, high = weights[index], weights[index + 1]
    if layout.low_nibble_first then
      bytes[#bytes + 1] = low + high * 16
    else
      bytes[#bytes + 1] = high + low * 16
    end
  end
  return bytes
end
-- }}}

-- {{{ M.quantise(values, count, format)
-- A whole run of plain numbers into the bytes the format stores, as a string.
function M.quantise(values, count, format)
  local block = format.block_of("q40")
  local layout = format.BLOCK_LAYOUT.q40
  if count % block ~= 0 then
    error("123-reference-quantised: " .. count .. " numbers is not a whole "
          .. "number of " .. block .. "-weight blocks")
  end

  local out = {}
  for at = 0, count - 1, block do
    local scale_bits, weights = M.quantise_block(values, at, block)
    local bytes = M.pack_block(scale_bits, weights, layout)
    for _, byte in ipairs(bytes) do out[#out + 1] = string.char(byte) end
  end
  return table.concat(out)
end
-- }}}

-- {{{ M.read_weight(bytes, at, index, format)
-- One weight out of a packed run, as the number it stands for.
--
-- `at` is where the run begins in the byte string, counted from zero;
-- `index` is which weight, also from zero. Written as a lookup rather than
-- as part of a loop so that the assembly has something exact to reproduce
-- for a single weight before it has to reproduce a whole product.
function M.read_weight(bytes, at, index, format)
  local block = format.block_of("q40")
  local layout = format.BLOCK_LAYOUT.q40
  local block_bytes = format.block_bytes("q40")

  local which_block = math.floor(index / block)
  local within = index % block
  local base = at + which_block * block_bytes

  local low = bytes:byte(base + 1)
  local high = bytes:byte(base + 2)
  local scale = M.from_f16_bits(low + high * 256)

  local byte = bytes:byte(base + layout.scale_bytes
                          + math.floor(within / layout.weights_per_byte) + 1)
  local nibble
  if (within % 2 == 0) == layout.low_nibble_first then
    nibble = byte % 16
  else
    nibble = math.floor(byte / 16)
  end

  return single((nibble - layout.zero_point) * scale)
end
-- }}}

-- {{{ M.matrix_vector_quantised(out, matrix_bytes, input, rows, columns, format)
--
-- The same shape of operation as the plain product, reading a packed matrix.
--
-- THE ORDER OF ADDITION IS THE SPECIFICATION, exactly as everywhere else:
-- one running total per row, single precision, ascending index order.
--
-- WHAT IS DIFFERENT, and it is the whole of the difference: each weight
-- arrives as a small whole number and a scale shared with thirty-one others.
-- The value multiplied into the total is `(weight - 8) * scale`, computed in
-- single precision, and THEN multiplied by the input. Folding the scale into
-- the running total once per block instead would be fewer multiplications
-- and a different answer -- the products would each be rounded before the
-- scale rather than after it.
--
-- That is not a small difference and it is not an optimisation left on the
-- table. It is a different specification, and if a faster arrangement is
-- ever wanted it gets its own name and its own recorded answers.
function M.matrix_vector_quantised(out, matrix_bytes, input, rows, columns,
                                   format)
  local block = format.block_of("q40")
  local block_bytes = format.block_bytes("q40")
  local layout = format.BLOCK_LAYOUT.q40

  if columns % block ~= 0 then
    error("123-reference-quantised: a row of " .. columns .. " does not "
          .. "divide into " .. block .. "-weight blocks, so a row would "
          .. "begin partway through one")
  end

  local blocks_per_row = columns / block

  for row = 0, rows - 1 do
    local total = 0
    local row_base = row * blocks_per_row * block_bytes

    for block_index = 0, blocks_per_row - 1 do
      local base = row_base + block_index * block_bytes
      local low = matrix_bytes:byte(base + 1)
      local high = matrix_bytes:byte(base + 2)
      local scale = M.from_f16_bits(low + high * 256)

      for within = 0, block - 1 do
        local byte = matrix_bytes:byte(
          base + layout.scale_bytes
          + math.floor(within / layout.weights_per_byte) + 1)
        local nibble
        if (within % 2 == 0) == layout.low_nibble_first then
          nibble = byte % 16
        else
          nibble = math.floor(byte / 16)
        end

        local weight = single((nibble - layout.zero_point) * scale)
        local column = block_index * block + within
        total = single(total + single(weight * input[column]))
      end
    end

    out[row] = total
  end
end
-- }}}

return M
