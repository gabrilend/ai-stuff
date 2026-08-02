-- 045-memory-budget.lua
--
-- How much memory a machine needs to think, broken down, and whether that fits
-- somewhere. One calculation, used by everything that has to know: the engine
-- deciding which memory strategy it can afford (issue 102), the image builder
-- refusing a model too large for the board it is being built for (502), and
-- the measurement that reports what a machine actually cost (106).
--
-- For a general: a model does not only need room for itself. It needs room for
-- what it is currently thinking about, and that second amount grows with the
-- length of the thought. This works out both, and says which of them is the
-- one that will run out first.
--
-- WHY THIS IS THE MOST IMPORTANT ARITHMETIC IN THE PROJECT. The whitepaper
-- names the fitting constraint as the risk most likely to be fatal: the weights
-- must fit the medium, then fit in memory alongside working space and a
-- growing cache, then leave enough speed to be useful, and the model must
-- still be capable enough to write correct assembly unaided. Nothing here
-- answers whether such a model exists. What it does is make the question
-- arithmetic rather than argument.

local M = {}

-- {{{ M.PRECISION_BYTES -- how much one number costs, per storage format
--
-- The block-quantised format shares one scale across thirty-two weights, so a
-- weight costs half a byte plus a share of the scale. It is not a whole number
-- of bytes per weight and is written as a fraction rather than rounded, so a
-- budget for a large model does not drift.
M.PRECISION_BYTES = {
  f32 = 4,
  f16 = 2,
  i8 = 1,
  q40 = (16 + 2) / 32,
}
-- }}}

-- {{{ M.weights(shape, precision, shapes_module)
-- What the model itself costs, at a given storage format.
function M.weights(shape, precision, shapes_module)
  local per_number = M.PRECISION_BYTES[precision]
    or error("045-memory-budget: unknown precision '" .. tostring(precision) .. "'")
  return math.floor(shapes_module.weight_count(shape) * per_number)
end
-- }}}

-- {{{ M.cache(shape, context, bytes_per_number)
-- What remembering costs.
--
-- Two of these -- keys and values -- for every layer, for every key head, for
-- every position the thought is allowed to reach. This is the term that grows
-- with the length of a thought, and on a long context it is the term that
-- decides everything.
--
-- `context` is separate from the shape's own so a caller can ask what a
-- shorter or longer thought would cost without inventing a different model.
function M.cache(shape, context, bytes_per_number)
  local kv_heads = shape.kv_heads or shape.heads
  return 2 * shape.layers * kv_heads * shape.head_width
         * (context or shape.context) * (bytes_per_number or 4)
end
-- }}}

-- {{{ M.working(shape, bytes_per_number)
-- The vectors a single step needs while it is happening: the state being
-- carried, a normalised copy, the queries, what attention produced, a
-- projection, the two feedforward halves, and the scores at the end.
--
-- Small beside the other two, and included because a budget that omits it is a
-- budget that is wrong by exactly the amount that makes a tight fit fail.
function M.working(shape, bytes_per_number)
  local width = bytes_per_number or 4
  local query_width = shape.heads * shape.head_width
  local numbers = shape.hidden * 3         -- state, normalised, projected
                + query_width * 2          -- queries, attended
                + shape.feedforward * 2    -- gate, up
                + shape.vocabulary         -- the scores
                + shape.context            -- attention weights over the past
  return numbers * width
end
-- }}}

-- {{{ M.total(options)
-- The whole picture, itemised.
--
-- options: shape, shapes_module, precision, context, engine_bytes, cache_bytes_per_number
function M.total(options)
  local shape = options.shape
  local precision = options.precision or "f32"
  local context = options.context or shape.context
  local cache_width = options.cache_bytes_per_number or 4

  local parts = {
    engine = options.engine_bytes or 0,
    weights = M.weights(shape, precision, options.shapes_module),
    cache = M.cache(shape, context, cache_width),
    working = M.working(shape, 4),
  }
  parts.total = parts.engine + parts.weights + parts.cache + parts.working

  -- Which term will run out first is more useful than the sum. On a short
  -- context the weights dominate and a smaller model is the only answer; on a
  -- long one the cache dominates and a shorter thought is also an answer.
  local largest, largest_name = 0, nil
  for name, bytes in pairs(parts) do
    if name ~= "total" and bytes > largest then largest, largest_name = bytes, name end
  end
  parts.largest = largest_name

  return parts
end
-- }}}

-- {{{ M.longest_thought(options, available_bytes)
-- Given a board's memory, how long a thought fits.
--
-- This is the question a machine actually has to answer about itself, and it
-- is the inverse of the one above: not "does this fit" but "how much of this
-- fits". A machine that cannot hold its full context can still think, in
-- shorter breaths, and knowing that is better than refusing to start.
-- `resident_weight_bytes` is how much of the model is actually being held in
-- memory, which depends on which strategy was chosen. Omitting it assumes all
-- of it, which is the fastest arrangement and the one that fits least often.
--
-- The two functions must be told the same thing or they disagree: asking this
-- one while the machine has chosen to read most of its weights in place gives
-- an answer for a machine that is not running.
function M.longest_thought(options, available_bytes, resident_weight_bytes)
  local shape = options.shape
  local weights = resident_weight_bytes
    or M.weights(shape, options.precision or "f32", options.shapes_module)
  local fixed = (options.engine_bytes or 0) + weights + M.working(shape, 4)

  if fixed >= available_bytes then return 0 end

  local per_position = M.cache(shape, 1, options.cache_bytes_per_number or 4)
  if per_position <= 0 then return shape.context end

  local fits = math.floor((available_bytes - fixed) / per_position)
  if fits > shape.context then return shape.context end
  return fits
end
-- }}}

-- {{{ M.strategy(options, available_bytes)
-- Which of the memory strategies in issue 102 this machine can afford.
--
-- The ratchet: take the fastest that fits, and refuse rather than limp. A
-- machine that cannot hold its own weights should say which number was too
-- large, not run unusably and let somebody guess.
function M.strategy(options, available_bytes)
  local shape = options.shape
  local weights = M.weights(shape, options.precision or "f32", options.shapes_module)
  local cache = M.cache(shape, options.context or shape.context,
                        options.cache_bytes_per_number or 4)
  local working = M.working(shape, 4)
  local engine = options.engine_bytes or 0

  local needed_without_weights = engine + cache + working

  -- Each rung returns what it needs AND how much of the model it keeps
  -- resident, because the second is what anyone asking about thought length
  -- afterwards has to be told (see longest_thought above).
  if needed_without_weights + weights <= available_bytes then
    return "everything in memory", needed_without_weights + weights, weights
  end

  -- The hot parts are the ones touched every single step regardless of which
  -- layer is running: the embedding table and the final projection.
  local hot = math.floor(weights * 0.25)
  if needed_without_weights + hot <= available_bytes then
    return "the hot parts in memory, the rest read in place",
           needed_without_weights + hot, hot
  end

  if needed_without_weights <= available_bytes then
    return "everything read in place", needed_without_weights, 0
  end

  return nil, needed_without_weights, nil
end
-- }}}

return M
