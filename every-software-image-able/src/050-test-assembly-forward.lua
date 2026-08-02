#!/usr/bin/env luajit
-- 050-test-assembly-forward.lua
--
-- Runs a whole forward pass on the assembly arithmetic and compares it against
-- the recorded answer, bit for bit.
--
-- For a general: the small pieces were each shown correct on their own. This
-- shows they are correct together, which is a different claim -- a piece can be
-- right in isolation and be handed the wrong thing by the piece before it, and
-- nothing about testing them separately would notice.
--
-- usage:
--   luajit 050-test-assembly-forward.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

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

-- {{{ local function host_architecture()
local function host_architecture()
  local pipe = io.popen("uname -m")
  local name = pipe and pipe:read("*l") or "unknown"
  if pipe then pipe:close() end
  return name
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local arch = host_architecture()

say("")
say("  a whole thought, on the real arithmetic")
say("  " .. string.rep("-", 58))
say("")

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
if not emit[arch] then
  say("  no kernels for " .. arch .. ". Nothing was tested, which is not the")
  say("  same as nothing being wrong.")
  os.exit(1)
end

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local source = DIR .. "/tmp/shared-memory/kernels/kernels-" .. arch .. ".s"
local conductor_source = DIR .. "/tmp/shared-memory/kernels/conductor-" .. arch .. ".s"
local library = DIR .. "/tmp/kernels/kernels-" .. arch .. ".so"

local handle = io.open(source, "w")
handle:write(emit.source(arch, specification))
handle:close()

-- the conducting rides in the same library as the arithmetic it directs.
local conduct = dofile(DIR .. "/src/056-emit-conductor.lua")
handle = io.open(conductor_source, "w")
handle:write(conduct[arch]())
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source
               .. " " .. conductor_source) then
  say("  the kernels would not assemble")
  os.exit(1)
end

local assembly = dofile(DIR .. "/src/049-assembly-forward.lua")
assembly.declare()
conduct.declare()
local kernels = ffi.load(library)

local format = dofile(DIR .. "/src/024-blob-format.lua")
local reference = dofile(DIR .. "/src/035-reference-forward.lua")

local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local blob_file = io.open(blob_path, "rb")
if not blob_file then
  say("  building the fixture model first")
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR .. " > /dev/null")
  blob_file = io.open(blob_path, "rb")
end
local blob = blob_file:read("*a")
blob_file:close()

local fixture = dofile(DIR .. "/assets/036-fixture.lua")
local model = reference.load(blob, format)

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

-- {{{ local function run(wide)
local function run(wide)
  local cache = assembly.new_cache(model.shape)
  local rows = {}
  for step, token in ipairs(fixture.prompt) do
    local logits = assembly.forward(kernels, model, cache, token, step - 1, wide)
    local row = ffi.new("float[?]", model.shape.vocabulary)
    ffi.copy(row, logits, model.shape.vocabulary * 4)
    rows[step] = row
  end
  return rows
end
-- }}}

-- {{{ local function compare_to_fixture(rows, label)
local function compare_to_fixture(rows, label)
  local recorded = ffi.new("float[1]")
  local worst, worst_at = 0, nil
  local exact = true

  for step = 1, #fixture.logits do
    for slot = 1, #fixture.logits[step] do
      recorded[0] = fixture.logits[step][slot]
      local got = rows[step][slot - 1]
      if got ~= recorded[0] then
        exact = false
        local difference = math.abs(got - recorded[0])
        if difference > worst then
          worst = difference
          worst_at = string.format("step %d, score %d: %.9g against %.9g",
                                   step, slot - 1, got, recorded[0])
        end
      end
    end
  end

  check(label, exact, worst_at
    and (worst_at .. string.format("  (largest difference %g)", worst)))
end
-- }}}

local plain_rows = run(false)
compare_to_fixture(plain_rows, "every score matches the recorded answer exactly")

-- {{{ the wide kernel, over a whole pass
-- Reading four numbers at a time must give the identical answer, because it
-- keeps one running total and folds each group in the same order. Running a
-- whole pass each way is a far harder test of that than any single call:
-- a difference in the last bit anywhere compounds through twenty-two tensors
-- and two layers before it reaches a score.
local wide_rows = run(true)
local same = true
local where = nil
for step = 1, #plain_rows do
  for slot = 0, model.shape.vocabulary - 1 do
    if plain_rows[step][slot] ~= wide_rows[step][slot] then
      same = false
      where = where or string.format("step %d, score %d: %.9g against %.9g",
                                     step, slot, plain_rows[step][slot], wide_rows[step][slot])
    end
  end
end
check("four numbers at a time gives the identical answer", same, where)
-- }}}

-- {{{ the same invariants the reference had to satisfy
-- A whole pass can match a recorded answer and still be wrong in ways the
-- recording cannot see, so the properties checked of the reference are checked
-- of this too.
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
  for slot = 0, model.shape.vocabulary - 1 do
    if plain_rows[repeated_first][slot] ~= plain_rows[repeated_second][slot] then
      differs = true
    end
  end
  check("the same token at a later position answers differently", differs,
        "the carried turns are not reaching the scores")
end

local extended = {}
for _, token in ipairs(fixture.prompt) do extended[#extended + 1] = token end
extended[#extended + 1] = 11

local longer_cache = assembly.new_cache(model.shape)
local longer = {}
for step, token in ipairs(extended) do
  local logits = assembly.forward(kernels, model, longer_cache, token, step - 1, false)
  local row = ffi.new("float[?]", model.shape.vocabulary)
  ffi.copy(row, logits, model.shape.vocabulary * 4)
  longer[step] = row
end

local unchanged = true
for step = 1, #plain_rows do
  for slot = 0, model.shape.vocabulary - 1 do
    if plain_rows[step][slot] ~= longer[step][slot] then unchanged = false end
  end
end
check("adding a token does not change earlier answers", unchanged,
      "something later is reaching backwards through the attention")
-- }}}

-- {{{ the conducting, in assembly
-- The same pass again with nothing readable left in the loop: the layer
-- walk, the head walk and every pointer handed to a kernel are now assembly
-- too (056). If this matches the recorded answer, the whole thought is
-- assembly end to end -- and any later disagreement must be in a port,
-- because on this architecture there is nothing else left to move.
local function run_conducted(wide)
  local cache = assembly.new_cache(model.shape)
  local holder = conduct.new_plan(kernels, model, cache, wide)
  local rows = {}
  for step, token in ipairs(fixture.prompt) do
    local row = ffi.new("float[?]", model.shape.vocabulary)
    kernels.forward_conduct(holder.plan, token, step - 1, row)
    rows[step] = row
  end
  return rows
end

local conducted = run_conducted(false)
compare_to_fixture(conducted, "the assembly conducting matches the record exactly")

local conducted_wide = run_conducted(true)
local conducted_same = true
local conducted_where = nil
for step = 1, #conducted do
  for slot = 0, model.shape.vocabulary - 1 do
    if conducted[step][slot] ~= conducted_wide[step][slot] then
      conducted_same = false
      conducted_where = conducted_where
        or string.format("step %d, score %d: %.9g against %.9g", step, slot,
                         conducted[step][slot], conducted_wide[step][slot])
    end
  end
end
check("and conducts the wide kernel to the identical answer",
      conducted_same, conducted_where)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this leaves:")
say("    - the other two architectures. The readable conductor (049) stays")
say("      as the reference the ports are held against.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("assembly forward: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
