#!/usr/bin/env luajit
-- 048-test-exp.lua
--
-- Measures both polynomials for the exponential across the range a model
-- actually produces, and says which one the specification should use.
--
-- For a general: there are two candidate ways of computing this, one shorter
-- and one longer. Rather than argue about which is better, both are run over
-- the numbers a model really generates and the worse-case error of each is
-- reported. The specification then follows the measurement.
--
-- usage:
--   luajit 048-test-exp.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

-- {{{ local function run_one(command)
local function run_one(command)
  local ok, _, code = os.execute(command)
  return (ok == true or ok == 0), code
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local exponential = dofile(DIR .. "/src/047-reference-exp.lua")

say("")
say("  raising e to a power, two ways")
say("  " .. string.rep("-", 62))
say("")

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

-- {{{ where the exponential is actually used
--
-- Two places, with quite different ranges, which is why one measurement across
-- a made-up interval would be misleading.
--
--   Turning scores into probabilities subtracts the largest first, so every
--   argument is zero or negative and mostly close to zero. This is by far the
--   commoner case.
--
--   The gate in the feedforward passes its raw value, which spans whatever the
--   model produces -- a few tens either way in practice.
local ranges = {
  { name = "softmax, after the largest is removed", from = -30, to = 0 },
  { name = "softmax, the common part of that range", from = -6, to = 0 },
  { name = "the feedforward gate", from = -20, to = 20 },
  { name = "everything representable", from = -87, to = 87 },
}

local candidates = {
  { name = "five terms", run = exponential.exp_five },
  { name = "seven terms", run = exponential.exp_seven },
}

for _, range in ipairs(ranges) do
  say("  " .. range.name .. "   [" .. range.from .. ", " .. range.to .. "]")
  for _, candidate in ipairs(candidates) do
    local worst, worst_at = 0, nil
    local samples = 20000
    for step = 0, samples do
      local x = range.from + (range.to - range.from) * step / samples
      local got = candidate.run(x)
      local want = math.exp(x)
      if want ~= 0 then
        local relative = math.abs(got - want) / want
        if relative > worst then worst, worst_at = relative, x end
      end
    end
    say(string.format("    %-14s worst relative error %.3e  at %+.3f",
                      candidate.name, worst, worst_at or 0))
  end
  say("")
end
-- }}}

-- {{{ what must be true of either
for _, candidate in ipairs(candidates) do
  local name = candidate.name
  local run = candidate.run

  check(name .. ": e to the nothing is exactly one", run(0) == 1.0,
        string.format("got %.17g", run(0)))

  -- Nothing may exceed what a single-precision number holds, because the
  -- result always feeds a division and an infinity there poisons a whole row
  -- of probabilities rather than failing.
  local finite = true
  for x = -90, 90, 0.25 do
    local value = run(x)
    if value ~= value or value == math.huge or value == -math.huge then finite = false end
  end
  check(name .. ": nothing escapes to infinity or nonsense", finite)

  -- Larger arguments must give larger answers, everywhere. A polynomial that
  -- dips would make a token's probability fall as its score rose, which is not
  -- an error anything downstream could detect.
  local rising = true
  local previous = run(-87)
  for x = -87, 87, 0.05 do
    local value = run(x)
    if value < previous then rising = false end
    previous = value
  end
  check(name .. ": a larger power never gives a smaller answer", rising)

  -- Below the limit the answer is zero rather than something very small but
  -- wrong, and above it the largest there is rather than an infinity.
  check(name .. ": clamps at both ends",
        run(-200) == 0 and run(200) < math.huge and run(200) > 1e38)
end
-- }}}

say("")
say("  " .. string.rep("-", 62))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  the specification currently uses: " .. exponential.CHOSEN)
say("")
say("  Changing that changes every recorded answer downstream, which is")
say("  correct -- it is a change to the specification and not to an")
say("  implementation. Regenerate the fixture when it moves.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("exp: " .. passed .. " of " .. (passed + failed)
                .. " as expected, using " .. exponential.CHOSEN .. "\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
