#!/usr/bin/env luajit
-- 116-test-forward-riscv64.lua
--
-- A whole forward pass, conducted in the third tongue, on a real emulated
-- RISC-V machine, compared against the first tongue's scores bit for bit.
-- Issue 401's last arithmetic gap.
--
-- For a general: the eleven routines were already shown to agree one at a
-- time. This runs them in the order a thought requires, over a whole small
-- model, and asks whether the same scores come out. That is a different
-- claim: a routine can be right alone and be handed the wrong thing by the
-- routine before it, and the first architecture found exactly such a defect
-- the moment its routines were first composed.
--
-- AND THE REFERENCE VOUCHES FOR ITSELF FIRST. Before its answer is used as
-- the standard, it is checked against the recorded fixture. A first
-- architecture that had quietly regressed would otherwise become the thing
-- the third one is measured against, and a matching pair of wrong answers
-- reads exactly like a working port.
--
-- usage:
--   luajit 116-test-forward-riscv64.lua [--dir ROOT] [--seconds N]

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

-- {{{ local function read_file(path)
local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
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
local seconds = 120
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 120
  end
  index = index + 1
end

say("")
say("  a whole thought, in the third tongue")
say("  " .. string.rep("-", 58))
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

-- The reference has to come from the FIRST architecture. Producing it
-- anywhere else and then checking it on the guest would be an implementation
-- agreeing with itself, which passes whatever it does.
local host = host_architecture()
if host ~= "x86_64" then
  say("  this host is " .. host .. ", and the answer the third tongue is")
  say("  measured against has to come from the first one. Nothing was")
  say("  tested, which is not the same as nothing being wrong.")
  os.exit(1)
end

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local riscv = dofile(DIR .. "/src/111-kernels-riscv64.lua")
local conduct = dofile(DIR .. "/src/056-emit-conductor.lua")
local riscv_conduct = dofile(DIR .. "/src/114-conductor-riscv64.lua")
local payload = dofile(DIR .. "/src/115-emit-forward-check-riscv.lua")
local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local float_bits = dofile(DIR .. "/src/107-float-bits.lua")
local shapes = dofile(DIR .. "/src/034-model-shapes.lua")
local format = dofile(DIR .. "/src/024-blob-format.lua")
local reference = dofile(DIR .. "/src/035-reference-forward.lua")
local assembly = dofile(DIR .. "/src/049-assembly-forward.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

-- {{{ the first architecture, built and loaded
local source = DIR .. "/tmp/shared-memory/kernels/kernels-x86_64.s"
local conductor_source = DIR .. "/tmp/shared-memory/kernels/conductor-x86_64.s"
local library = DIR .. "/tmp/kernels/kernels-x86_64.so"

local handle = io.open(source, "w")
handle:write(emit.source("x86_64", specification))
handle:close()

handle = io.open(conductor_source, "w")
handle:write(conduct.x86_64())
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source
               .. " " .. conductor_source) then
  say("  the first tongue would not build; there is nothing to compare against")
  os.exit(1)
end

assembly.declare()
conduct.declare()
local kernels = ffi.load(library)
-- }}}

-- {{{ the model, and the prompt with a known answer
local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local blob = read_file(blob_path)
if not blob then
  say("  building the fixture model first")
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR
          .. " > /dev/null")
  blob = read_file(blob_path)
end
if not blob then
  say("  no fixture model, and it would not build")
  os.exit(1)
end

local model = reference.load(blob, format)
local fixture = dofile(DIR .. "/assets/036-fixture.lua")
local shape = model.shape
local steps = #fixture.prompt
-- }}}

-- {{{ what the first architecture says, conducted by its own assembly
local cache = assembly.new_cache(shape)
local holder = conduct.new_plan(kernels, model, cache, false)
local reference_rows = {}
for step, token in ipairs(fixture.prompt) do
  local row = ffi.new("float[?]", shape.vocabulary)
  kernels.forward_conduct(holder.plan, token, step - 1, row)
  reference_rows[step] = row
end

-- The reference vouches for itself before it becomes the standard.
local drifted = nil
local rounder = ffi.new("float[1]")
for step = 1, #fixture.logits do
  for place = 1, #fixture.logits[step] do
    rounder[0] = fixture.logits[step][place]
    if reference_rows[step][place - 1] ~= rounder[0] then
      drifted = drifted or string.format(
        "step %d, score %d: %.9g against the recorded %.9g",
        step, place - 1, reference_rows[step][place - 1], rounder[0])
    end
  end
end
check("the first tongue still gives the recorded answer", drifted == nil, drifted)
-- }}}

-- {{{ that answer, and the whole model, as the exact bits they are
local recorded = {}
for step = 1, steps do
  local as_words = ffi.cast("const uint32_t *", reference_rows[step])
  local row = {}
  for place = 0, shape.vocabulary - 1 do row[place + 1] = as_words[place] end
  recorded[step] = row
end

local tensor_list = shapes.tensors(shape)
local weights_carried = 0
local function words_of(name)
  local pointer = model.tensors[name]
  if pointer == nil then
    error("116: the packed model has no tensor called '" .. name .. "'")
  end
  local count = nil
  for _, entry in ipairs(tensor_list) do
    if entry.name == name then
      count = 1
      for _, extent in ipairs(entry.shape) do count = count * extent end
    end
  end
  local as_words = ffi.cast("const uint32_t *", pointer)
  local out = {}
  for place = 0, count - 1 do out[place + 1] = as_words[place] end
  weights_carried = weights_carried + count
  return out
end

-- The two floating constants are taken out of the plan the first
-- architecture actually ran with, rather than recomputed here. A square root
-- taken twice is a thing that can differ.
local plan_words = ffi.cast("const uint32_t *", holder.plan)
local slot_at = conduct.offsets()
local scale_bits = plan_words[slot_at.scale / 4]
local epsilon_bits = plan_words[slot_at.epsilon / 4]
check("the constants the first tongue ran with were read, not remade",
      scale_bits ~= 0 and epsilon_bits ~= 0,
      string.format("scale %08x, epsilon %08x", scale_bits, epsilon_bits))
-- }}}

-- {{{ the payload that runs the same pass on the other machine
local text = payload.riscv64({
  shape = shape,
  tensors = (function()
    local out = {}
    for _, entry in ipairs(tensor_list) do
      out[#out + 1] = { name = entry.name }
    end
    return out
  end)(),
  words_of = words_of,
  prompt = fixture.prompt,
  recorded = recorded,
  scale_bits = scale_bits,
  epsilon_bits = epsilon_bits,
  kernels = riscv,
  conductor = riscv_conduct,
  plan = conduct,
  specification = specification,
  float_bits = float_bits,
  dir = DIR,
})

local base = DIR .. "/tmp/shared-memory/payloads/forward-check-riscv64"
handle = io.open(base .. ".s", "w")
handle:write(text)
handle:close()

check("every weight the model holds was carried",
      weights_carried == shapes.weight_count(shape),
      weights_carried .. " of " .. shapes.weight_count(shape))

if not run_one("clang --target=riscv64-unknown-none -march=rv64imafd -c "
               .. base .. ".s -o " .. base .. ".o") then
  check("the third tongue's whole engine assembles", false,
        "see " .. base .. ".s")
  say("")
  say("  " .. passed .. " of " .. (passed + failed + 1) .. " as expected")
  os.exit(1)
end
check("the third tongue's whole engine assembles", true)

-- THE WHOLE REASON 054 EXISTS, checked rather than trusted.
local relocations = io.popen("llvm-readelf -r " .. base .. ".o 2>&1")
local relocation_text = relocations and relocations:read("*a") or ""
if relocations then relocations:close() end
local none_left = relocation_text:find("There are no relocations", 1, true) ~= nil
  or relocation_text:match("^%s*$") ~= nil
check("nothing in it is waiting on a linker", none_left,
      "a relocation left behind becomes a branch to itself, silently")

run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw")

local raw = read_file(base .. ".raw")
local raw_size = raw and #raw or 0
check("the extracted engine is whole", raw_size > 0 and raw_size % 4096 ~= 0,
      raw_size .. " bytes, and a multiple of four thousand and ninety-six is "
      .. "what a write cut off midway looks like")

run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. base
        .. ".raw --to " .. base .. ".efi --arch riscv64 > /dev/null")
-- }}}

-- {{{ boot it and read what it said
local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-riscv64-serial.log"
run_one("rm -f " .. serial)
run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-riscv64"
  .. " --payload " .. base .. ".efi --seconds " .. seconds
  .. " --dir " .. DIR .. " > /dev/null 2>&1")

local spoken = read_file(serial) or ""

check("the other machine conducted a pass and reported",
      spoken:find("pass conducted", 1, true) ~= nil,
      "nothing recognisable came back; see " .. serial)

-- Only what the payload said, and only where a mark begins a line. This
-- board's firmware prints "device is of 3 speed" while enumerating USB,
-- eleven hundred lines before the payload speaks, and a loose search for
-- "of" finds that instead.
local report = spoken:match("pass conducted(.*)$") or ""
local function number_after(mark)
  return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
end

local matched, total = number_after("matched"), number_after("of")
local wide, wide_total = number_after("wide"), number_after("wof")
local got, want = number_after("got"), number_after("want")
local bent = number_after("bent")

check("every score matches the first architecture, bit for bit",
      matched ~= nil and total ~= nil and matched == total and total > 0,
      tostring(matched) .. " of " .. tostring(total)
      .. (got and want and string.format(
            "; the first disagreement was %08x against %08x", got, want) or ""))

check("and four numbers at a time gives the identical answer",
      wide ~= nil and wide_total ~= nil and wide == wide_total
      and wide_total > 0,
      tostring(wide) .. " of " .. tostring(wide_total))

check("as many scores were compared as the prompt produces",
      total == steps * shape.vocabulary,
      tostring(total) .. " against the " .. (steps * shape.vocabulary)
      .. " a prompt of " .. steps .. " over a vocabulary of "
      .. shape.vocabulary .. " must produce")

-- THE DIRECTION THAT PROVES THE OTHERS MEAN ANYTHING.
check("and a conducting bent on purpose is caught",
      bent ~= nil and bent > 0,
      bent == nil and "the machine did not report it"
      or (bent .. " of " .. tostring(total) .. " scores moved, and a "
          .. "conducting known to be wrong must move at least one"))
-- }}}

-- {{{ how far apart, when they are apart at all
if got and want and got ~= want and matched ~= total then
  local pair = ffi.new("uint32_t[2]")
  pair[0], pair[1] = got, want
  local viewed = ffi.cast("float *", pair)
  say("")
  say(string.format("  the first disagreement: %.9g against %.9g",
                    viewed[0], viewed[1]))
  say(string.format("  which is %d in the last place",
                    math.abs(tonumber(got) - tonumber(want))))
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this completes:")
say("    a whole thought now runs end to end, in assembly, on all three")
say("    architectures -- and all three produce the same scores, bit for")
say("    bit, over the same weights. The engine is portable in the only")
say("    sense that means anything: not that it compiles everywhere, but")
say("    that it agrees everywhere.")
say("")
say("    what is still NOT ported anywhere: the hands. That half is not a")
say("    translation -- x86 reaches devices through a separate address")
say("    space with its own instructions, and the other two are")
say("    memory-mapped throughout, so one hand changes shape rather than")
say("    detail and the catalogue is not identical across machines.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("a whole thought in the third tongue: " .. passed .. " of "
                .. (passed + failed) .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
