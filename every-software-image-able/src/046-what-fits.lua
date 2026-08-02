#!/usr/bin/env luajit
-- 046-what-fits.lua
--
-- Says what a machine of a given shape would need, on boards of given sizes,
-- and which term runs out first. Also checks the arithmetic against itself.
--
-- For a general: this is the feasibility question the whole project rests on,
-- asked as arithmetic rather than as an argument. It does not say whether a
-- model good enough to write assembly exists at these sizes. It says what such
-- a model would cost if it did, so that the question can be answered by
-- measurement instead of hope.
--
-- usage:
--   luajit 046-what-fits.lua [--dir ROOT] [--context N] [--precision NAME]

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

-- {{{ local function readable_bytes(count)
local function readable_bytes(count)
  if count >= 1073741824 then return string.format("%.2f GB", count / 1073741824) end
  if count >= 1048576 then return string.format("%.1f MB", count / 1048576) end
  if count >= 1024 then return string.format("%.1f KB", count / 1024) end
  return count .. " B"
end
-- }}}

-- {{{ main
local context_override, precision = nil, "q40"
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--context" then
    index = index + 1 ; context_override = tonumber(arg[index])
  elseif arg[index] == "--precision" then
    index = index + 1 ; precision = arg[index]
  end
  index = index + 1
end

local shapes = dofile(DIR .. "/src/034-model-shapes.lua")
local budget = dofile(DIR .. "/src/045-memory-budget.lua")

-- Model shapes spanning the range that might plausibly be carried. None of
-- these is chosen; they are reference points so the shape of the constraint is
-- visible. Which model an image carries is decided by whoever builds one.
local candidates = {
  { name = "the test model", layers = 2, hidden = 32, heads = 4, head_width = 8,
    kv_heads = 2, feedforward = 64, vocabulary = 48, context = 16 },
  { name = "very small", layers = 12, hidden = 768, heads = 12, head_width = 64,
    kv_heads = 12, feedforward = 2048, vocabulary = 32000, context = 2048 },
  { name = "small", layers = 22, hidden = 2048, heads = 32, head_width = 64,
    kv_heads = 4, feedforward = 5632, vocabulary = 32000, context = 2048 },
  { name = "medium", layers = 32, hidden = 4096, heads = 32, head_width = 128,
    kv_heads = 8, feedforward = 14336, vocabulary = 128256, context = 8192 },
}

-- Boards a seed might plausibly land on. The smallest is the interesting one:
-- the design's whole appeal is a machine somebody can leave in a room.
local boards = {
  { name = "a small single-board computer", memory = 512 * 1048576 },
  { name = "a larger single-board computer", memory = 4 * 1073741824 },
  { name = "a retired desktop", memory = 16 * 1073741824 },
}

say("")
say("  what a thinking machine costs")
say("  " .. string.rep("-", 66))
say("")
say("  weights stored as " .. precision
    .. " (" .. budget.PRECISION_BYTES[precision] .. " bytes per number)")
say("  the cache always in f32, because it is written and read every step")
say("")

for _, shape in ipairs(candidates) do
  local context = context_override or shape.context
  local parts = budget.total({
    shape = shape, shapes_module = shapes, precision = precision,
    context = context, engine_bytes = 2 * 1048576,
  })

  say(string.format("  %s -- %d layers of %d, context %d",
                    shape.name, shape.layers, shape.hidden, context))
  say(string.format("    weights   %12s", readable_bytes(parts.weights)))
  say(string.format("    cache     %12s   (grows with the length of a thought)",
                    readable_bytes(parts.cache)))
  say(string.format("    working   %12s", readable_bytes(parts.working)))
  say(string.format("    engine    %12s", readable_bytes(parts.engine)))
  say(string.format("    total     %12s   largest term: %s",
                    readable_bytes(parts.total), parts.largest))

  for _, board in ipairs(boards) do
    local strategy, needed, resident = budget.strategy({
      shape = shape, shapes_module = shapes, precision = precision,
      context = context, engine_bytes = 2 * 1048576,
    }, board.memory)

    if strategy then
      -- asked with the same strategy the machine would actually be running,
      -- or the two disagree and the answer describes a different machine.
      local thought = budget.longest_thought({
        shape = shape, shapes_module = shapes, precision = precision,
        engine_bytes = 2 * 1048576,
      }, board.memory, resident)
      say(string.format("      on %-30s %s", board.name, strategy))
      if thought < context then
        say(string.format("      %-33s a thought of %d rather than %d",
                          "", thought, context))
      end
    else
      say(string.format("      on %-30s does not fit -- needs %s with no weights at all",
                        board.name, readable_bytes(needed)))
    end
  end
  say("")
end

-- {{{ checking the arithmetic against itself
say("  " .. string.rep("-", 66))
say("")

local passed, failed = 0, 0
local function check(what, ok, detail)
  if ok then
    passed = passed + 1
    say(string.format("  %-52s ok", what))
  else
    failed = failed + 1
    say(string.format("  %-52s WRONG", what))
    if detail then say("      " .. detail) end
  end
end

local shape = candidates[3]
local options = { shape = shape, shapes_module = shapes, precision = "f16",
                  engine_bytes = 0 }

-- The cache is linear in the length of a thought. If it is not, something is
-- being counted per layer that should be counted once, or the reverse.
local one = budget.cache(shape, 1, 4)
local hundred = budget.cache(shape, 100, 4)
check("the cache grows in step with the thought", hundred == one * 100,
      hundred .. " against " .. (one * 100))

-- The longest thought that fits must actually fit, and one longer must not.
-- An off-by-one here is a machine that starts and then fails partway into its
-- first long thought, which is the worst moment to find out.
local available = 3 * 1073741824
local longest = budget.longest_thought(options, available)
local at_limit = budget.total({ shape = shape, shapes_module = shapes,
                                precision = "f16", context = longest,
                                engine_bytes = 0 }).total
local past_limit = budget.total({ shape = shape, shapes_module = shapes,
                                  precision = "f16", context = longest + 1,
                                  engine_bytes = 0 }).total
check("the longest thought that fits, fits", at_limit <= available,
      readable_bytes(at_limit) .. " against " .. readable_bytes(available))
check("one position longer does not", past_limit > available or longest == shape.context,
      "the limit is not where it says it is")

-- A board that cannot hold the weights at all must be refused rather than
-- given a strategy it cannot run.
local refused = budget.strategy(options, 1024)
check("a board far too small is refused", refused == nil)

-- Each rung of the ratchet must need less than the one above it, or the
-- ratchet is not a ratchet.
local small_board = 2 * 1073741824
local strategy_small = budget.strategy(options, small_board)
local strategy_large = budget.strategy(options, 64 * 1073741824)
check("more memory never chooses a slower strategy",
      strategy_large == "everything in memory" and strategy_small ~= nil,
      tostring(strategy_small) .. " / " .. tostring(strategy_large))

-- The block-quantised format must actually be smaller than the plain one, or
-- there is no reason to carry the complication into the inner loop.
local plain = budget.weights(shape, "f32", shapes)
local packed = budget.weights(shape, "q40", shapes)
check("the compact format is smaller than the plain one", packed < plain / 4,
      readable_bytes(packed) .. " against " .. readable_bytes(plain))
-- }}}

say("")
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not say:")
say("    - whether a model that fits is also good enough to write correct")
say("      assembly unaided. That is the question the project rests on and")
say("      no arithmetic answers it.")
say("    - anything about speed. A model that fits and thinks too slowly to")
say("      finish is a model that does not fit -- and 051 times that half.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("what fits: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
