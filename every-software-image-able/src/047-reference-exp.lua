-- 047-reference-exp.lua
--
-- The exponential, specified rather than borrowed.
--
-- For a general: raising e to a power is needed in two places in a model's
-- arithmetic. Every language and every library computes it slightly
-- differently in the last bits, so if the readable version and the assembly
-- version each ask their own library, they will disagree and neither will be
-- wrong. This defines one particular way of computing it, so both can do
-- exactly that and agree completely.
--
-- WHY THIS IS WORTH A FILE. It is the last function standing between this
-- project and a forward pass that can be compared exactly. Multiplication,
-- addition and square root are pinned by the standard. Sine and cosine were
-- removed from the engine by carrying a table of turns (034). That leaves the
-- exponential, and rather than accept a tolerance for its sake, it is written
-- down as a specification both sides implement.
--
-- HOW IT WORKS. Raising e to a power is turned into raising two to a power,
-- because two is the base the hardware already stores numbers in. Split that
-- power into a whole part and a fraction: the whole part becomes an adjustment
-- to the number's exponent field, which is exact and free, and the fraction --
-- always between minus a half and a half -- is approximated by a short
-- polynomial. Every step is single precision, in the stated order.
--
-- The polynomial is the ordinary Taylor series to five terms. It is not the
-- most accurate choice available for the effort; a minimax fit would be closer
-- for the same number of multiplications. It is chosen because it can be read
-- and re-derived by anyone, and because being *identical* on both sides
-- matters more here than being closest to the true value. A better polynomial
-- is a change to this specification, made in one place, and both sides follow.

local ffi = require("ffi")

local M = {}

-- {{{ single-precision rounding, as everywhere else in this project
local round = ffi.new("float[1]")
local function f(value)
  round[0] = value
  return round[0]
end
-- }}}

-- {{{ M.LOG2E and M.LN2 -- the two constants, at single precision
--
-- Written as the exact bit patterns rather than as decimal text, so that
-- nothing depends on how a particular parser rounds a written number. The
-- assembly loads the same bits.
M.LOG2E_BITS = 0x3fb8aa3b   -- 1 / ln 2
M.LN2_BITS   = 0x3f317218   -- ln 2

local bits = ffi.new("uint32_t[1]")
local as_float = ffi.cast("float *", bits)

local function from_bits(pattern)
  bits[0] = pattern
  return as_float[0]
end

M.LOG2E = from_bits(M.LOG2E_BITS)
M.LN2 = from_bits(M.LN2_BITS)
-- }}}

-- {{{ M.LIMIT -- where the answer stops being representable
--
-- Above this the result overflows what a single-precision number can hold;
-- below the negative of it the result is zero for all practical purposes.
-- Clamping rather than returning infinity keeps everything downstream finite,
-- which matters because the exponential here always feeds a division.
M.LIMIT = 88.0
-- }}}

-- {{{ M.SERIES -- the polynomials on offer, shortest first
--
-- Two options, kept rather than one chosen in advance, because which is right
-- depends on measurement rather than on argument. Each is the ordinary series
-- for e to a power, cut at a different length; the coefficients are one over a
-- factorial and can be re-derived by anyone rather than being cited.
--
-- The last coefficient comes first, because the polynomial is evaluated by
-- nesting -- multiply by the leftover, add the next coefficient, repeat -- which
-- is one multiply and one add per term and is exactly what the assembly does,
-- in exactly this order. The order is part of the answer.
M.SERIES = {
  five  = { 1/120, 1/24, 1/6, 1/2, 1, 1 },
  seven = { 1/5040, 1/720, 1/120, 1/24, 1/6, 1/2, 1, 1 },
}
-- }}}

-- {{{ M.exp_with(series, x)
-- e raised to x, using a named polynomial. Both options run through here, so
-- they cannot drift apart in anything but the coefficients.
function M.exp_with(series, x)
  x = f(x)
  if x > M.LIMIT then return f(3.4028234663852886e38) end
  if x < -M.LIMIT then return f(0) end

  local scaled = f(x * M.LOG2E)
  local whole = math.floor(scaled + 0.5)
  local fraction = f(x - f(whole * M.LN2))

  local total = f(series[1])
  for index = 2, #series do
    total = f(f(total * fraction) + f(series[index]))
  end

  local exponent = whole + 127
  if exponent < 1 then return f(0) end
  if exponent > 254 then return f(3.4028234663852886e38) end
  bits[0] = exponent * 8388608
  local power = as_float[0]

  return f(total * power)
end
-- }}}

-- {{{ M.CHOSEN -- which polynomial the specification uses
--
-- Set from measurement, not from preference. See 048, which compares both
-- across the range a model actually produces and reports the worst error each
-- allows. Changing this changes every recorded answer downstream, which is
-- correct: it is a change to the specification.
M.CHOSEN = "seven"
-- }}}

-- {{{ M.exp(x)
-- e raised to x, computed the specified way.
function M.exp(x)
  return M.exp_with(M.SERIES[M.CHOSEN], x)
end
-- }}}

-- {{{ M.exp_five(x) and M.exp_seven(x) -- both options, callable by name
-- So the comparison in 048 can run each without either being reconstructed
-- from a description of itself.
function M.exp_five(x) return M.exp_with(M.SERIES.five, x) end
function M.exp_seven(x) return M.exp_with(M.SERIES.seven, x) end
-- }}}

-- {{{ M.exp_table(count)
-- The same values as a table, for anything that wants to check a whole range
-- at once rather than one at a time.
function M.exp_table(from, to, count)
  local out = {}
  for index = 0, count - 1 do
    local x = from + (to - from) * index / (count - 1)
    out[index + 1] = M.exp(x)
  end
  return out
end
-- }}}

return M
