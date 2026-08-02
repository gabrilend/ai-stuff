-- 040-reference-sampler.lua
--
-- Turning a score for every possible next token into one chosen token. Written
-- plainly on the host, so the assembly version has something to agree with.
--
-- For a general: the model produces a number for every word it might say next.
-- This decides which one it actually says -- not by taking the highest, which
-- would make it repeat itself forever, but by weighted chance among the
-- plausible ones.
--
-- WHERE THE CHANCE COMES FROM. A file of random numbers made when the image
-- was built and carried on it (issue 104). Each number from the file seeds a
-- generator that yields many thousands of draws before the next is taken, so a
-- hundred kilobytes lasts a very long life. The property that matters: the same
-- image with the same file, given the same input, produces the same machine.
--
-- PRECISION IS PART OF THE SPECIFICATION, here as everywhere (043). A chosen
-- token is discrete: a hair of floating-point difference at a boundary flips
-- a choice, the flipped choice joins the context, and two implementations
-- diverge wholesale from that moment. So every floating step here is single
-- precision, rounded where the machine would round, and the exponential is
-- the specified one (047) rather than whatever the host's library offers.
--
-- THE GENERATOR IS EXACT INTEGERS, in sixty-four bit arithmetic. The first
-- version multiplied in the host language's ordinary numbers, which hold
-- integers exactly only to fifty-three bits -- and the product here reaches
-- sixty-one. It looked like an integer generator and quietly was not, which
-- is precisely the kind of specification no assembly could ever match.
--
-- A single token is a weighted random choice. A paragraph is not random at all.

local ffi = require("ffi")

local M = {}

-- {{{ single -- one value, rounded the way the machine rounds
local box = ffi.new("float[1]")
local function single(value)
  box[0] = value
  return box[0]
end
-- }}}

-- {{{ step_generator -- the recurrence, in exact integers
--
-- Sixty-four bit unsigned arithmetic, so the product of a thirty-one bit
-- state and a thirty-bit multiplier is held whole before the remainder is
-- taken. The state going in and coming out fits comfortably in an ordinary
-- number; only the middle needs the width.
local A = ffi.new("uint64_t", 1103515245)
local C = ffi.new("uint64_t", 12345)
local MODULUS = ffi.new("uint64_t", 2147483648)

local function step_generator(state)
  return tonumber((ffi.new("uint64_t", state) * A + C) % MODULUS)
end
-- }}}

-- {{{ M.new_stream(numbers, position)
-- The machine's supply of chance. Reads from the carried file, and stretches
-- each number across many draws.
--
-- `numbers` is an array of integers -- what the file holds. `position` is how
-- far into it the machine has already got, so a stream can be resumed rather
-- than restarted.
function M.new_stream(numbers, position)
  if #numbers == 0 then error("the carried file of random numbers is empty") end

  local stream = {
    numbers = numbers,
    position = position or 1,
    state = nil,
    drawn = 0,
    -- how many draws one carried number is stretched across. Large enough
    -- that the file lasts, small enough that it is genuinely re-seeded.
    per_number = 4096,
    wrapped = false,
  }

  -- {{{ function stream.next()
  -- One draw: a single-precision value in [0, 1). The state is converted to
  -- single -- which rounds it to twenty-four bits, deliberately, because that
  -- is the conversion the machine performs -- and divided by two to the
  -- thirty-first, which moves the exponent and rounds nothing.
  function stream.next()
    if stream.state == nil or stream.drawn >= stream.per_number then
      stream.state = stream.numbers[stream.position]
      stream.drawn = 0
      stream.position = stream.position + 1
      if stream.position > #stream.numbers then
        -- Reaching the end is worth knowing about, and is not the disaster it
        -- looks like: a drawn number meets a different set of probabilities
        -- every time, so reusing the stream only repeats old choices if the
        -- same questions are being asked -- and a machine asking the same
        -- questions has a problem randomness was never going to solve.
        stream.position = 1
        stream.wrapped = true
      end
    end
    stream.state = step_generator(stream.state)
    stream.drawn = stream.drawn + 1
    return single(stream.state) / 2147483648
  end
  -- }}}

  return stream
end
-- }}}

-- {{{ M.softmax_with_temperature(scores, count, temperature)
-- Scores into probabilities, every step at single precision. Temperature
-- divides every score first: below one sharpens the difference between them,
-- above one flattens it, and at zero the highest score would win outright --
-- which is handled separately, because dividing by zero is not a way to say
-- that.
local exponential = dofile(
  (os.getenv("ESIA_DIR") or "/mnt/mtwo/programming/ai-stuff/every-software-image-able")
  .. "/src/047-reference-exp.lua")

function M.softmax_with_temperature(scores, count, temperature)
  temperature = single(temperature)
  local probabilities = {}
  local largest = single(scores[1])
  for index = 2, count do
    local value = single(scores[index])
    if value > largest then largest = value end
  end

  local total = 0
  for index = 1, count do
    -- the largest is subtracted first: it changes nothing about the answer
    -- and stops the exponentials from running away. Subtract, divide, and
    -- accumulate each round once, in ascending order, as the machine does.
    local value = exponential.exp(single(single(single(scores[index]) - largest) / temperature))
    probabilities[index] = value
    total = single(total + value)
  end
  for index = 1, count do
    probabilities[index] = single(probabilities[index] / total)
  end
  return probabilities
end
-- }}}

-- {{{ M.choose(scores, count, settings, stream)
-- One token, chosen.
--
-- `settings` carries `temperature`, `top_k` and `top_p`. They are read rather
-- than baked in, because the machine may later want to change them and a
-- constant is a decision somebody else already made.
function M.choose(scores, count, settings, stream)
  local temperature = settings.temperature or 1.0
  local top_k = settings.top_k or count
  local top_p = single(settings.top_p or 1.0)

  -- {{{ temperature of zero means take the highest, said plainly
  if temperature <= 0 then
    local best, best_at = single(scores[1]), 1
    for index = 2, count do
      local value = single(scores[index])
      if value > best then best, best_at = value, index end
    end
    return best_at - 1, 1.0
  end
  -- }}}

  local probabilities = M.softmax_with_temperature(scores, count, temperature)

  -- {{{ order by likelihood, keeping track of which token each was
  local ordered = {}
  for index = 1, count do
    ordered[index] = { token = index - 1, chance = probabilities[index] }
  end
  -- ties broken by token number so the ordering is the same on any machine.
  -- An unstable sort here would make two identical images disagree. The
  -- assembly reaches the same order without sorting at all -- repeatedly
  -- taking the first strict maximum -- and the tie rule is what makes the
  -- two walks identical.
  table.sort(ordered, function(a, b)
    if a.chance == b.chance then return a.token < b.token end
    return a.chance > b.chance
  end)
  -- }}}

  -- {{{ discard the unlikely tail
  -- Two cutters, and the tighter one wins. Keeping at most so many, and
  -- keeping only enough to cover so much of the total chance.
  local keep = math.min(top_k, count)
  local running = 0
  for index = 1, keep do
    running = single(running + ordered[index].chance)
    if running >= top_p then
      keep = index
      break
    end
  end
  -- }}}

  -- {{{ draw from what is left
  -- The total of the kept chances is the same accumulation the cut just
  -- made, in the same order from the same zero, so it is the same number to
  -- the bit -- recomputed here for the reader rather than for the machine.
  local remaining = 0
  for index = 1, keep do
    remaining = single(remaining + ordered[index].chance)
  end

  local target = single(stream.next() * remaining)
  local walked = 0
  for index = 1, keep do
    walked = single(walked + ordered[index].chance)
    if target <= walked then
      return ordered[index].token, ordered[index].chance
    end
  end
  -- rounding can leave the target a hair past the end; the last candidate is
  -- the right answer there, and returning it is not a fallback but arithmetic.
  return ordered[keep].token, ordered[keep].chance
  -- }}}
end
-- }}}

-- {{{ M.generate_file(seed, count)
-- What the image builder bakes in (issue 502). Made from a seed so the same
-- recipe and the same seed give the same machine, exactly -- which turns a
-- strange failure into something reproducible by handing somebody an image.
function M.generate_file(seed, count)
  local numbers, state = {}, seed
  for index = 1, count do
    state = step_generator(state)
    numbers[index] = state
  end
  return numbers
end
-- }}}

return M
