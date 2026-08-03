-- 107-float-bits.lua
--
-- Turning a number into the exact bits a processor holds it as, and back.
-- One implementation, because the obvious way to write it is wrong in a way
-- that does not show up until it matters.
--
-- For a general: assembly cannot say "one seven-hundred-and-twentieth". A
-- constant has to arrive as the exact pattern of bits a single-precision
-- number is made of, so something has to convert. This is that something.
--
-- THE OBVIOUS WAY IS BROKEN, AND SILENTLY. Writing a number into a
-- float-shaped box and reading it back through a pointer of a different
-- shape is the standard trick for this, and it works perfectly -- for the
-- first few dozen calls. Then the loop it sits in gets hot, the compiler
-- traces it, and the read through the second pointer is treated as though
-- it could not have changed, because nothing tells the compiler the two
-- pointers touch the same memory. From then on every call returns the same
-- answer.
--
-- MEASURED: two thousand different numbers through the aliased version give
-- sixty-eight distinct results. Through the union below, two thousand.
--
-- WHAT IT COST. A payload was built carrying two hundred and fifty-six
-- numbers of test data, of which three were distinct. The machine that ran
-- it computed the right answer over the wrong numbers, disagreed with the
-- first architecture by eighty-nine percent, and was very nearly recorded as
-- a broken port. It was the tool that was broken.
--
-- WHY A UNION FIXES IT. A union is one object with two ways of being read,
-- so the compiler knows the two views are the same storage and cannot treat
-- either as unchanged while the other is written. The aliased-pointer
-- version hides that relationship, which is exactly what makes it fast and
-- exactly what makes it wrong.
--
-- THE SHAPE OF THIS DEFECT is the project's oldest one wearing new clothes:
-- no error, no crash, a plausible answer. The first few values were right,
-- which is worse than all of them being wrong -- a spot check passes.

local ffi = require("ffi")

local M = {}

-- {{{ the union, declared once
--
-- Named with a prefix because a type declared to the FFI is declared for the
-- whole process, and a bare name like `float_bits` would collide with
-- anything else that had the same idea.
ffi.cdef[[
  typedef union { float f; uint32_t u; } esia_float_bits;
  typedef union { double d; uint64_t u; } esia_double_bits;
]]

local single_box = ffi.new("esia_float_bits")
local double_box = ffi.new("esia_double_bits")
-- }}}

-- {{{ M.of(value)
-- The bits of `value` held as a single-precision number, as a plain Lua
-- number so it can be formatted, compared and written out without further
-- conversion.
function M.of(value)
  single_box.f = value
  return tonumber(single_box.u)
end
-- }}}

-- {{{ M.hex(value)
-- The same, spelled the way an assembler wants to read it. Provided here
-- rather than left to each caller, because every caller was writing the same
-- format string and one of them writing it differently is a difference
-- nobody would notice.
function M.hex(value)
  return string.format("0x%08x", M.of(value))
end
-- }}}

-- {{{ M.from(bits)
-- The other direction: what number a pattern of bits means. Used when
-- reading back what a machine reported, where the value arrives as an
-- integer and has to become a number again.
function M.from(bits)
  single_box.u = bits
  return single_box.f
end
-- }}}

-- {{{ M.round(value)
-- One value, rounded the way the machine rounds it, and handed back as an
-- ordinary number.
--
-- SAFE WHERE THE OTHER WAS NOT, and it is worth knowing why: this writes and
-- reads the SAME field, so there is no second view for the compiler to
-- mistake for something unrelated. The rounding idiom scattered through the
-- reference implementations is this shape and was never at risk.
function M.round(value)
  single_box.f = value
  return single_box.f
end
-- }}}

-- {{{ M.self_check()
-- Proves the conversion still works after the loop it is in has gone hot.
--
-- Called by the tests rather than trusted, because the failure this file
-- exists to prevent CANNOT be caught by a small check -- the broken version
-- passes the first few dozen calls perfectly. Only a hot loop reveals it, so
-- the check is a hot loop.
function M.self_check(iterations)
  iterations = iterations or 2000
  local seen, count = {}, 0
  for step = 1, iterations do
    local pattern = M.of(step * 0.7 - 300)
    if not seen[pattern] then
      seen[pattern] = true
      count = count + 1
    end
  end
  -- Different inputs must give different patterns. A handful of collisions
  -- would be arithmetic; a few dozen distinct answers out of thousands is
  -- the compiler having decided the value cannot change.
  if count < iterations * 0.9 then
    return nil, string.format(
      "%d different numbers converted to %d distinct bit patterns. The "
      .. "conversion has been optimised into a constant, which is the "
      .. "defect this file exists to prevent.", iterations, count)
  end
  return true
end
-- }}}

return M
