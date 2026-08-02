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
-- A single token is a weighted random choice. A paragraph is not random at all.

local M = {}

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
    stream.state = (stream.state * 1103515245 + 12345) % 2147483648
    stream.drawn = stream.drawn + 1
    return stream.state / 2147483648
  end
  -- }}}

  return stream
end
-- }}}

-- {{{ M.softmax_with_temperature(scores, count, temperature)
-- Scores into probabilities. Temperature divides every score first: below one
-- sharpens the difference between them, above one flattens it, and at zero the
-- highest score would win outright -- which is handled separately, because
-- dividing by zero is not a way to say that.
function M.softmax_with_temperature(scores, count, temperature)
  local probabilities = {}
  local largest = scores[1]
  for index = 2, count do
    if scores[index] > largest then largest = scores[index] end
  end

  local total = 0
  for index = 1, count do
    -- the largest is subtracted first: it changes nothing about the answer
    -- and stops the exponentials from running away.
    local value = math.exp((scores[index] - largest) / temperature)
    probabilities[index] = value
    total = total + value
  end
  for index = 1, count do probabilities[index] = probabilities[index] / total end
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
  local top_p = settings.top_p or 1.0

  -- {{{ temperature of zero means take the highest, said plainly
  if temperature <= 0 then
    local best, best_at = scores[1], 1
    for index = 2, count do
      if scores[index] > best then best, best_at = scores[index], index end
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
  -- An unstable sort here would make two identical images disagree.
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
    running = running + ordered[index].chance
    if running >= top_p then
      keep = index
      break
    end
  end
  -- }}}

  -- {{{ draw from what is left
  local remaining = 0
  for index = 1, keep do remaining = remaining + ordered[index].chance end

  local target = stream.next() * remaining
  local walked = 0
  for index = 1, keep do
    walked = walked + ordered[index].chance
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
    state = (state * 1103515245 + 12345) % 2147483648
    numbers[index] = state
  end
  return numbers
end
-- }}}

return M
