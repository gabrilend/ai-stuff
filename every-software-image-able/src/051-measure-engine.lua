#!/usr/bin/env luajit
-- 051-measure-engine.lua
--
-- How fast the arithmetic actually is, and what that implies for a model large
-- enough to be worth carrying. Issue 106.
--
-- For a general: the project's feasibility has two halves. One is whether a
-- model fits in memory, which is arithmetic and was answered (046). The other
-- is whether it thinks fast enough to be useful, which cannot be argued and has
-- to be timed. This times it.
--
-- WHAT IS BEING MEASURED. The real kernels, running natively on this
-- processor, over a real model, doing every operation a forward pass does.
-- Not an estimate and not an emulation. The instructions timed here are the
-- same instructions that would run on a bare machine.
--
-- WHAT IS NOT. Anything about a bare machine's memory system, which has no
-- operating system caching behind it and may behave differently. And nothing
-- at all about the other two architectures.
--
-- usage:
--   luajit 051-measure-engine.lua [--dir ROOT] [--seconds N]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

ffi.cdef[[
  typedef long time_t;
  struct timespec { time_t tv_sec; long tv_nsec; };
  int clock_gettime(int clock, struct timespec *spec);
]]

-- {{{ local function now()
local spec = ffi.new("struct timespec[1]")
local function now()
  ffi.C.clock_gettime(1, spec)      -- the clock that only moves forward
  return tonumber(spec[0].tv_sec) + tonumber(spec[0].tv_nsec) / 1e9
end
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

-- {{{ local function host_architecture()
local function host_architecture()
  local pipe = io.popen("uname -m")
  local name = pipe and pipe:read("*l") or "unknown"
  if pipe then pipe:close() end
  return name
end
-- }}}

-- {{{ main
local budget = 2.0
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; budget = tonumber(arg[index]) or 2.0
  end
  index = index + 1
end

local arch = host_architecture()
local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
if not emit[arch] then
  say("  no kernels for " .. arch .. "; nothing to time")
  os.exit(1)
end

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local source = DIR .. "/tmp/shared-memory/kernels/kernels-" .. arch .. ".s"
local library = DIR .. "/tmp/kernels/kernels-" .. arch .. ".so"
local handle = io.open(source, "w")
handle:write(emit.source(arch, specification))
handle:close()
run_one("clang -shared -O2 -o " .. library .. " " .. source)

local assembly = dofile(DIR .. "/src/049-assembly-forward.lua")
assembly.declare()
local kernels = ffi.load(library)

local format = dofile(DIR .. "/src/024-blob-format.lua")
local reference = dofile(DIR .. "/src/035-reference-forward.lua")
local shapes = dofile(DIR .. "/src/034-model-shapes.lua")
local budgeter = dofile(DIR .. "/src/045-memory-budget.lua")

local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local blob_file = io.open(blob_path, "rb")
if not blob_file then
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR .. " > /dev/null")
  blob_file = io.open(blob_path, "rb")
end
local blob = blob_file:read("*a")
blob_file:close()

local model = reference.load(blob, format)
local shape = model.shape

say("")
say("  how fast it thinks")
say("  " .. string.rep("-", 66))
say("")
say(string.format("  on %s, natively -- the same instructions a bare machine runs", arch))
say(string.format("  model: %d layers of %d, %d heads of %d, vocabulary %d",
                  shape.layers, shape.hidden, shape.heads, shape.head_width,
                  shape.vocabulary))
say(string.format("  %d weights, %d multiply-and-adds per token",
                  shapes.weight_count(shape), shapes.weight_count(shape)))
say("")

-- {{{ local function time_it(name, step)
-- Runs until the budget is spent, then reports the rate. A fixed count would
-- take an unpredictable time on an unknown machine; a fixed time gives however
-- many samples this processor can afford.
local function time_it(name, step)
  -- one pass first, so nothing is being timed cold
  step(0)

  local started = now()
  local count = 0
  repeat
    step(count % shape.context)
    count = count + 1
  until now() - started >= budget
  local elapsed = now() - started

  local per_second = count / elapsed
  say(string.format("  %-34s %9.1f tokens per second   (%.3f ms each)",
                    name, per_second, 1000 / per_second))
  return per_second
end
-- }}}

local reference_cache = reference.new_cache(shape)
local assembly_cache = assembly.new_cache(shape)

local slow = time_it("the readable version", function(position)
  reference.forward(model, reference_cache, 1, position)
end)

local plain = time_it("the assembly, one at a time", function(position)
  assembly.forward(kernels, model, assembly_cache, 1, position, false)
end)

local wide = time_it("the assembly, four at a time", function(position)
  assembly.forward(kernels, model, assembly_cache, 1, position, true)
end)

say("")
say(string.format("  the assembly is %.0f times the readable version", plain / slow))
say(string.format("  reading four at a time is %.2f times one at a time", wide / plain))
say("")

-- {{{ what this implies for a model worth carrying
--
-- The work in a forward pass is very nearly one multiply-and-add per weight,
-- so a rate measured on a small model carries to a large one far better than
-- most extrapolations do. It is still an extrapolation and is marked as one.
local per_second_operations = wide * shapes.weight_count(shape)

say(string.format("  that is %.1f million multiply-and-adds per second",
                  per_second_operations / 1e6))
say("")
say("  EXTRAPOLATED -- measured on a small model, scaled by weight count.")
say("  The real figure will be lower: a large model does not fit in the")
say("  processor's own memory and spends time waiting for the rest.")
say("")

local candidates = {
  { name = "very small", layers = 12, hidden = 768, heads = 12, head_width = 64,
    kv_heads = 12, feedforward = 2048, vocabulary = 32000, context = 2048 },
  { name = "small", layers = 22, hidden = 2048, heads = 32, head_width = 64,
    kv_heads = 4, feedforward = 5632, vocabulary = 32000, context = 2048 },
  { name = "medium", layers = 32, hidden = 4096, heads = 32, head_width = 128,
    kv_heads = 8, feedforward = 14336, vocabulary = 128256, context = 8192 },
}

for _, candidate in ipairs(candidates) do
  local weights = shapes.weight_count(candidate)
  local tokens = per_second_operations / weights
  local words_per_minute = tokens * 60 * 0.75   -- roughly a word to a token and a third

  say(string.format("  %-12s %14s weights   %8.2f tokens/s   about %.0f words a minute",
                    candidate.name, string.format("%.1f M", weights / 1e6),
                    tokens, words_per_minute))
end
say("")

-- {{{ and what that means for the thing the project actually wants
-- A machine writing its own allocator is producing assembly, and the question
-- is not whether it can but whether it finishes. A page of assembly is a few
-- thousand tokens.
say("  a page of assembly is perhaps three thousand tokens, so:")
for _, candidate in ipairs(candidates) do
  local weights = shapes.weight_count(candidate)
  local tokens = per_second_operations / weights
  local minutes = (3000 / tokens) / 60
  say(string.format("  %-12s about %6.1f minutes to write one", candidate.name, minutes))
end
say("")
-- }}}
-- }}}

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write(string.format("engine: %.1f tokens per second on the test model\ngoodbye\n", wide))
  goodbye:close()
end
-- }}}
