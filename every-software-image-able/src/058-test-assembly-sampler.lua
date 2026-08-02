#!/usr/bin/env luajit
-- 058-test-assembly-sampler.lua
--
-- Runs the readable sampler (040) and the assembly sampler (057) side by
-- side, on the same scores with the same carried numbers, and requires them
-- to agree choice for choice and bit for bit.
--
-- For a general: choosing a word is the one place where a tiny arithmetic
-- difference does not stay tiny -- a flipped choice joins the conversation
-- and everything after it differs. So the two implementations are not
-- compared "closely"; they are compared exactly, over thousands of draws,
-- across every setting the sampler has.
--
-- usage:
--   luajit 058-test-assembly-sampler.lua [--dir ROOT]

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
say("  choosing the same word, twice over")
say("  " .. string.rep("-", 58))
say("")

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local emit_sampler = dofile(DIR .. "/src/057-emit-sampler.lua")
if not emit[arch] or not emit_sampler[arch] then
  say("  no sampler assembly for " .. arch .. ". Nothing was tested, which is")
  say("  not the same as nothing being wrong.")
  os.exit(1)
end

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local kernel_source = DIR .. "/tmp/shared-memory/kernels/kernels-" .. arch .. ".s"
local sampler_source = DIR .. "/tmp/shared-memory/kernels/sampler-" .. arch .. ".s"
local library = DIR .. "/tmp/kernels/sampler-" .. arch .. ".so"

local handle = io.open(kernel_source, "w")
handle:write(emit.source(arch, specification))
handle:close()
handle = io.open(sampler_source, "w")
handle:write(emit_sampler[arch]())
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()
if not run_one("clang -shared -o " .. library .. " " .. kernel_source
               .. " " .. sampler_source) then
  say("  the sampler would not assemble")
  os.exit(1)
end

emit_sampler.declare()
local kernels = ffi.load(library)
local reference = dofile(DIR .. "/src/040-reference-sampler.lua")

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

-- {{{ scores, shared exactly
-- Both sides must see the identical single-precision values, so the floats
-- are made once and the reference reads the same numbers back out of them.
local single_box = ffi.new("float[1]")
local function single(value)
  single_box[0] = value
  return single_box[0]
end

local base = { 5.0, 4.5, 3.0, 1.0, 0.5, 0.2, -1.0, -3.0 }
local count = #base

local function scores_for(round)
  local floats = ffi.new("float[?]", count)
  local view = {}
  for position = 1, count do
    -- varied per round, deterministically, so boundaries get exercised
    floats[position - 1] =
      single(base[position] + ((round * 7 + position * 13) % 41) * 0.05 - 1.0)
    view[position] = floats[position - 1]
  end
  return floats, view
end
-- }}}

-- {{{ local function agree(name, settings, draws, vary)
-- The heart of the test: N draws through both implementations, one carried
-- file, and any disagreement in token or chance ends the claim.
local function agree(name, settings, draws, vary, carried_length)
  local carried = reference.generate_file(20260802, carried_length or 64)

  local ref_stream = reference.new_stream(carried)
  local asm_stream = emit_sampler.new_stream(carried)
  local holder = emit_sampler.new_plan(kernels, count, settings, asm_stream)
  local chance_out = ffi.new("float[1]")

  local tokens_agree, chances_agree = true, true
  local where = nil
  local fixed_floats, fixed_view = scores_for(0)

  for round = 1, draws do
    local floats, view = fixed_floats, fixed_view
    if vary then floats, view = scores_for(round) end

    local ref_token, ref_chance = reference.choose(view, count, settings, ref_stream)
    local asm_token = tonumber(kernels.sampler_choose(holder.plan, floats, count, chance_out))

    if ref_token ~= asm_token then
      tokens_agree = false
      where = where or string.format("draw %d: %d against %d", round, ref_token, asm_token)
    end
    if single(ref_chance) ~= chance_out[0] then
      chances_agree = false
      where = where or string.format("draw %d: chance %.9g against %.9g",
                                     round, ref_chance, chance_out[0])
    end
  end

  check(name, tokens_agree and chances_agree, where)
  return ref_stream, asm_stream.stream
end
-- }}}

local ref_stream, asm_stream =
  agree("two thousand ordinary choices agree exactly",
        { temperature = 1.0, top_k = 5, top_p = 0.95 }, 2000, false)

-- {{{ the two streams walk in step
-- Same state, same distance into the file, same number of draws from the
-- current seed. The positions count from different ends of one -- the
-- readable one is one-based -- and that is the only difference allowed.
check("and the two streams stay in step",
      ref_stream.state == tonumber(asm_stream.state)
      and ref_stream.position - 1 == tonumber(asm_stream.position)
      and ref_stream.drawn == tonumber(asm_stream.drawn),
      string.format("state %s/%s, position %s/%s, drawn %s/%s",
                    tostring(ref_stream.state), tostring(asm_stream.state),
                    tostring(ref_stream.position), tostring(asm_stream.position),
                    tostring(ref_stream.drawn), tostring(asm_stream.drawn)))
-- }}}

agree("sharpened choices agree, on moving scores",
      { temperature = 0.5 }, 500, true)
agree("flattened and tail-cut choices agree",
      { temperature = 2.0, top_p = 0.6 }, 500, true)
agree("frozen choices agree",
      { temperature = 0 }, 50, true)
agree("keeping only the best two agrees",
      { temperature = 1.0, top_k = 2 }, 500, true)

-- {{{ wrapping is noticed identically
local ref_tiny, asm_tiny =
  agree("choices agree straight through a wrap",
        { temperature = 1.0, top_k = 5, top_p = 0.95 }, 12000, false, 2)
check("and both sides noticed the wrap",
      ref_tiny.wrapped == true and tonumber(asm_tiny.wrapped) == 1,
      string.format("readable %s, assembly %s",
                    tostring(ref_tiny.wrapped), tostring(asm_tiny.wrapped)))
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not prove:")
say("    - the other two architectures; the readable half is the reference")
say("      they will be held against (401).")
say("    - that the carried file is on any image. Baking it in belongs to")
say("      the image builder (502).")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("assembly sampler: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
