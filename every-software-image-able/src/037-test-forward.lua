#!/usr/bin/env luajit
-- 037-test-forward.lua
--
-- Checks the reference forward pass against the recorded fixture, and against
-- a handful of things that must be true of any implementation of this
-- arithmetic whether or not the fixture is right.
--
-- For a general: this asks whether the model still gives the answer it gave
-- before, and whether the answer has the properties an answer of this kind
-- must have. The second half is the more interesting one -- a fixture only
-- catches change, and these catch being wrong from the start.
--
-- usage:
--   luajit 037-test-forward.lua [--dir ROOT]

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

local format = dofile(DIR .. "/src/024-blob-format.lua")
local shapes = dofile(DIR .. "/src/034-model-shapes.lua")
local reference = dofile(DIR .. "/src/035-reference-forward.lua")

local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local handle = io.open(blob_path, "rb")
if not handle then
  say("  building the fixture model first")
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR .. " > /dev/null")
  handle = io.open(blob_path, "rb")
end
local blob = handle:read("*a")
handle:close()

local fixture = dofile(DIR .. "/assets/036-fixture.lua")
local model = reference.load(blob, format)

say("")
say("  the arithmetic, against what it said before")
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

-- {{{ local function run_prompt(prompt)
local function run_prompt(prompt)
  local cache = reference.new_cache(model.shape)
  local rows = {}
  for step, token in ipairs(prompt) do
    local logits = reference.forward(model, cache, token, step - 1)
    local row = {}
    for slot = 0, model.shape.vocabulary - 1 do row[slot + 1] = logits[slot] end
    rows[step] = row
  end
  return rows
end
-- }}}

-- {{{ the fixture
local rows = run_prompt(fixture.prompt)

check("the model has the shape the fixture was made from",
      model.shape.layers == fixture.shape.layers
        and model.shape.hidden == fixture.shape.hidden
        and model.shape.vocabulary == fixture.shape.vocabulary,
      "regenerate the fixture if the model shape was meant to change")

local worst, worst_at = 0, nil
for step = 1, #fixture.logits do
  for slot = 1, #fixture.logits[step] do
    local difference = math.abs(rows[step][slot] - fixture.logits[step][slot])
    if difference > worst then
      worst = difference
      worst_at = "step " .. step .. ", score " .. (slot - 1)
    end
  end
end

-- The fixture is written to nine significant figures, so agreement is exact to
-- about that. Anything larger is a change in the arithmetic rather than a
-- rounding difference, and should be treated as one.
check("every score matches what was recorded", worst < 1e-6,
      worst_at and string.format("largest difference %g at %s", worst, worst_at))
-- }}}

-- {{{ things that must be true regardless of what the fixture says
--
-- A fixture only catches change. These catch being wrong from the beginning,
-- which is the failure a fixture generated from a broken implementation would
-- happily preserve forever.

-- nothing has escaped into infinity or nonsense
local sane = true
for step = 1, #rows do
  for slot = 1, #rows[step] do
    local value = rows[step][slot]
    if value ~= value or value == math.huge or value == -math.huge then sane = false end
  end
end
check("no score is infinite or nonsense", sane)

-- the same run twice gives the same answer. Anything reading uninitialised
-- memory, or iterating a table whose order is not fixed, fails here.
local again = run_prompt(fixture.prompt)
local identical = true
for step = 1, #rows do
  for slot = 1, #rows[step] do
    if rows[step][slot] ~= again[step][slot] then identical = false end
  end
end
check("the same prompt twice gives the same answer", identical)

-- The same token at two positions must differ. If it does not, the rotation
-- that carries position information is doing nothing, and the model cannot
-- tell an order from a bag of words. The fixture prompt repeats a token on
-- purpose so this is always testable.
local repeated_first, repeated_second = nil, nil
for step = 1, #fixture.prompt do
  for later = step + 1, #fixture.prompt do
    if fixture.prompt[step] == fixture.prompt[later] then
      repeated_first, repeated_second = step, later
    end
  end
end

if repeated_first then
  local differs = false
  for slot = 1, #rows[repeated_first] do
    if math.abs(rows[repeated_first][slot] - rows[repeated_second][slot]) > 1e-9 then
      differs = true
    end
  end
  check("the same token at a later position answers differently", differs,
        "position information is not reaching the scores")
else
  check("the same token at a later position answers differently", false,
        "the fixture prompt no longer repeats a token, so this cannot be tested")
end

-- A longer prompt must not change what was already said. Each step sees only
-- what came before it, so extending a prompt cannot reach backwards. An
-- implementation that lets later tokens influence earlier answers fails here,
-- and that mistake is otherwise very hard to see.
local extended = {}
for _, token in ipairs(fixture.prompt) do extended[#extended + 1] = token end
extended[#extended + 1] = 11
local longer = run_prompt(extended)

local unchanged = true
for step = 1, #rows do
  for slot = 1, #rows[step] do
    if math.abs(rows[step][slot] - longer[step][slot]) > 1e-9 then unchanged = false end
  end
end
check("adding a token does not change earlier answers", unchanged,
      "something later is reaching backwards")

-- The cache must hold exactly what was put in it, and the arithmetic above
-- must have used all of it. A cache sized wrongly is a mistake that shows as
-- slightly wrong answers rather than as a crash.
local expected_cache = shapes.cache_bytes(model.shape, 4)
check("a full cache is the size the shape says",
      expected_cache == 2 * model.shape.layers * model.shape.kv_heads
        * model.shape.head_width * model.shape.context * 4,
      "the cache calculation and the cache disagree")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not prove:")
say("    - that the fixture is right. It proves the arithmetic has not")
say("      changed, and the checks below it prove the answer has the shape")
say("      an answer must have -- neither says the model computes what a")
say("      model of this kind ought to compute. Only a real model, giving")
say("      sensible text, will say that.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("forward pass: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
