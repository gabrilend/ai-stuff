#!/usr/bin/env luajit
-- 041-test-sampler.lua
--
-- Checks the sampler. Mostly it checks determinism, because that is the whole
-- claim: the same image with the same carried numbers, given the same input,
-- produces the same machine.
--
-- usage:
--   luajit 041-test-sampler.lua [--dir ROOT]

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

local sampler = dofile(DIR .. "/src/040-reference-sampler.lua")

say("")
say("  choosing what to say next")
say("  " .. string.rep("-", 58))
say("")

local passed, failed = 0, 0

-- {{{ local function check(what, ok, detail)
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
-- }}}

-- a set of scores with a clear favourite, a plausible middle and a long tail
local scores = { 5.0, 4.5, 3.0, 1.0, 0.5, 0.2, -1.0, -3.0 }
local count = #scores

-- {{{ probabilities behave like probabilities
local probabilities = sampler.softmax_with_temperature(scores, count, 1.0)
local total = 0
for index = 1, count do total = total + probabilities[index] end
check("the chances add up to one", math.abs(total - 1) < 1e-9,
      string.format("they added to %.12f", total))

local ordered_right = true
for index = 2, count do
  if probabilities[index] > probabilities[index - 1] then ordered_right = false end
end
check("a higher score is never less likely", ordered_right)

-- Temperature below one sharpens: the favourite takes more of the total.
-- Above one flattens it. Getting this backwards is easy and produces a machine
-- that is either frozen or incoherent, with no error either way.
local sharp = sampler.softmax_with_temperature(scores, count, 0.5)
local flat = sampler.softmax_with_temperature(scores, count, 2.0)
check("lower temperature favours the favourite more",
      sharp[1] > probabilities[1] and probabilities[1] > flat[1],
      string.format("sharp %.4f, plain %.4f, flat %.4f", sharp[1], probabilities[1], flat[1]))
-- }}}

-- {{{ determinism -- the claim the whole design rests on
local carried = sampler.generate_file(20260802, 64)

local function run(settings, draws)
  local stream = sampler.new_stream(carried)
  local chosen = {}
  for _ = 1, draws do
    chosen[#chosen + 1] = sampler.choose(scores, count, settings, stream)
  end
  return chosen
end

local settings = { temperature = 1.0, top_k = 5, top_p = 0.95 }
local first = run(settings, 200)
local second = run(settings, 200)

local identical = true
for index = 1, #first do
  if first[index] ~= second[index] then identical = false end
end
check("the same carried numbers give the same choices", identical)

local other = sampler.new_stream(sampler.generate_file(20260803, 64))
local differently = {}
for _ = 1, 200 do
  differently[#differently + 1] = sampler.choose(scores, count, settings, other)
end
local any_difference = false
for index = 1, #first do
  if first[index] ~= differently[index] then any_difference = true end
end
check("different carried numbers give different choices", any_difference,
      "two seeds producing identical output means the seed is not reaching the draw")
-- }}}

-- {{{ the cutters
-- Keeping only the most likely few must never return anything outside them.
local kept = { temperature = 1.0, top_k = 2, top_p = 1.0 }
local stream = sampler.new_stream(carried)
local outside = false
for _ = 1, 500 do
  local token = sampler.choose(scores, count, kept, stream)
  if token ~= 0 and token ~= 1 then outside = true end
end
check("keeping the best two never returns a third", not outside)

-- A temperature of zero is not a very small temperature; it is a different
-- instruction, and dividing by zero is not a way to say it.
local frozen = sampler.new_stream(carried)
local always_best = true
for _ = 1, 20 do
  if sampler.choose(scores, count, { temperature = 0 }, frozen) ~= 0 then
    always_best = false
  end
end
check("temperature of zero always takes the highest", always_best)

-- Every token must be reachable when nothing is cut away, or the tail is
-- silently unreachable and the model can never say those words at all.
local wide = sampler.new_stream(sampler.generate_file(7, 4096))
local seen = {}
for _ = 1, 20000 do
  seen[sampler.choose(scores, count, { temperature = 2.0 }, wide)] = true
end
local reachable = 0
for token = 0, count - 1 do if seen[token] then reachable = reachable + 1 end end
check("with nothing cut away, every token is reachable", reachable == count,
      reachable .. " of " .. count .. " were ever chosen")
-- }}}

-- {{{ running out
-- The file is finite. Reaching the end must be noticed rather than silently
-- passed over, even though it is not the disaster it first looks like.
local tiny = sampler.new_stream(sampler.generate_file(3, 2))
for _ = 1, 20000 do sampler.choose(scores, count, settings, tiny) end
check("running out of carried numbers is noticed", tiny.wrapped,
      "the stream wrapped without saying so")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("sampler: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
