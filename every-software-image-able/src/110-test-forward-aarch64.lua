#!/usr/bin/env luajit
-- 110-test-forward-aarch64.lua
--
-- A whole forward pass, conducted in the second tongue, on a real emulated
-- ARM machine, compared against the first tongue's scores bit for bit.
-- Issue 401's remaining gap, closed for the second architecture.
--
-- For a general: the ten pieces of arithmetic were already shown to agree
-- one at a time. This runs them in the order a thought requires, over a
-- whole small model, and asks whether the same scores come out. That is a
-- different claim: a piece can be right alone and be handed the wrong thing
-- by the piece before it, and the first architecture found exactly such a
-- defect the moment its pieces were first composed.
--
-- WHAT MAKES THE COMPARISON WORTH ANYTHING. The expected scores are not
-- recomputed on the ARM side. They are produced HERE, by the first
-- architecture's own conducting over the same weights, carried into the
-- payload as the exact bit patterns that came out, and compared on the other
-- machine as integers. Nothing rounds, and "close" cannot happen.
--
-- AND THE REFERENCE VOUCHES FOR ITSELF FIRST. Before its answer is used as
-- the standard, it is checked against the recorded fixture. A first
-- architecture that had quietly regressed would otherwise become the thing
-- the second one is measured against, and a matching pair of wrong answers
-- reads exactly like a working port.
--
-- usage:
--   luajit 110-test-forward-aarch64.lua [--dir ROOT] [--seconds N]

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
-- The machine halts rather than powering itself off, so the emulator is
-- stopped by its clock and this is spent in full every run. The work inside
-- is milliseconds -- three passes over a model of a few thousand weights --
-- so nearly all of it is firmware getting to the payload at all. Ninety
-- leaves a wide margin over the sixty the kernel check uses, because a
-- timeout that fires early truncates the log and reads exactly like a
-- machine that stopped.
local seconds = 90
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 90
  end
  index = index + 1
end

say("")
say("  a whole thought, in the second tongue")
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

-- The reference has to come from the FIRST architecture. Producing it on an
-- ARM host and then checking it on an ARM guest would be an implementation
-- agreeing with itself, which passes whatever it does.
local host = host_architecture()
if host ~= "x86_64" then
  say("  this host is " .. host .. ", and the answer the second tongue is")
  say("  measured against has to come from the first one. Nothing was")
  say("  tested, which is not the same as nothing being wrong.")
  os.exit(1)
end

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local arm = dofile(DIR .. "/src/099-kernels-aarch64.lua")
local conduct = dofile(DIR .. "/src/056-emit-conductor.lua")
local arm_conduct = dofile(DIR .. "/src/108-conductor-aarch64.lua")
local payload = dofile(DIR .. "/src/109-emit-forward-check.lua")
local specification = dofile(DIR .. "/src/047-reference-exp.lua")
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
local function conducted(wide)
  local cache = assembly.new_cache(shape)
  local holder = conduct.new_plan(kernels, model, cache, wide)
  local rows = {}
  for step, token in ipairs(fixture.prompt) do
    local row = ffi.new("float[?]", shape.vocabulary)
    kernels.forward_conduct(holder.plan, token, step - 1, row)
    rows[step] = row
  end
  return rows, holder
end

local reference_rows, holder = conducted(false)

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
--
-- Read as words straight out of the packed model and out of the buffer the
-- kernels wrote. No number is turned into text and back anywhere in this
-- path, so there is no conversion in it to be wrong -- which is the defect
-- 107 exists because of, avoided by not doing the thing.
local recorded = {}
for step = 1, steps do
  local words = ffi.cast("const uint32_t *", reference_rows[step])
  local row = {}
  for place = 0, shape.vocabulary - 1 do row[place + 1] = words[place] end
  recorded[step] = row
end

local tensor_list = shapes.tensors(shape)
local weights_carried = 0
local function words_of(name)
  local pointer = model.tensors[name]
  if pointer == nil then
    error("110: the packed model has no tensor called '" .. name .. "'")
  end
  local count = nil
  for _, entry in ipairs(tensor_list) do
    if entry.name == name then
      count = 1
      for _, extent in ipairs(entry.shape) do count = count * extent end
    end
  end
  local words = ffi.cast("const uint32_t *", pointer)
  local out = {}
  for place = 0, count - 1 do out[place + 1] = words[place] end
  weights_carried = weights_carried + count
  return out
end

-- The two floating constants are taken out of the plan the first
-- architecture actually ran with, rather than recomputed here. A square root
-- taken twice is a thing that can differ, and the point of the comparison is
-- that nothing is allowed to.
local plan_bytes = ffi.cast("const uint32_t *", holder.plan)
local slot_at = conduct.offsets()
local scale_bits = plan_bytes[slot_at.scale / 4]
local epsilon_bits = plan_bytes[slot_at.epsilon / 4]
check("the constants the first tongue ran with were read, not remade",
      scale_bits ~= 0 and epsilon_bits ~= 0,
      string.format("scale %08x, epsilon %08x", scale_bits, epsilon_bits))
-- }}}

-- {{{ the payload that runs the same pass on the other machine
local text = payload.aarch64({
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
  kernels = arm.source(nil, specification,
                       dofile(DIR .. "/src/107-float-bits.lua")),
  conductor = arm_conduct.source(conduct),
  -- and one built wrong on purpose, so the machine has something it is
  -- required to disagree with
  conductor_miswired = arm_conduct.source(conduct, {
    name = "forward_conduct_miswired", miswire = true,
  }),
  plan = conduct,
})

local base = DIR .. "/tmp/shared-memory/payloads/forward-check-aarch64"
handle = io.open(base .. ".s", "w")
handle:write(text)
handle:close()

check("every weight the model holds was carried",
      weights_carried == shapes.weight_count(shape),
      weights_carried .. " of " .. shapes.weight_count(shape))

if not run_one("clang --target=aarch64-unknown-none -c " .. base .. ".s -o "
               .. base .. ".o") then
  check("the second tongue's whole engine assembles", false,
        "see " .. base .. ".s")
  say("")
  say("  " .. passed .. " of " .. (passed + failed + 1) .. " as expected")
  os.exit(1)
end
check("the second tongue's whole engine assembles", true)

run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw")

-- A truncated payload has cost this project a day once already: an unrelated
-- program had filled the RAM disk, the extraction wrote exactly four
-- thousand and ninety-six bytes of an eight thousand byte program, and the
-- machine booted half an engine and ran off the end of it. A round number is
-- the signature of a write cut off midway, so the size is looked at rather
-- than assumed.
local raw = read_file(base .. ".raw")
local raw_size = raw and #raw or 0
check("the extracted engine is whole", raw_size > 0 and raw_size % 4096 ~= 0,
      raw_size .. " bytes, and a multiple of four thousand and ninety-six is "
      .. "what a write cut off midway looks like")

run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. base
        .. ".raw --to " .. base .. ".efi --arch aarch64 > /dev/null")
-- }}}

-- {{{ boot it and read what it said
local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-arm64-serial.log"
run_one("rm -f " .. serial)
run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-arm64"
  .. " --payload " .. base .. ".efi --seconds " .. seconds
  .. " --dir " .. DIR .. " > /dev/null 2>&1")

local spoken = read_file(serial) or ""

check("the other machine conducted a pass and reported",
      spoken:find("pass conducted", 1, true) ~= nil,
      "nothing recognisable came back; see " .. serial)

-- Only what the payload said, and only where a mark begins a line. The
-- firmware narrates too, at length and first: on the RISC-V board it prints
-- "device is of 3 speed" while enumerating USB, eleven hundred lines before
-- the payload speaks, and a loose search for "of" found that instead. This
-- board does not happen to say it -- which is exactly why the guard belongs
-- here rather than only where the trap was sprung.
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

-- THE DIRECTION THAT PROVES THE OTHERS MEAN ANYTHING. The same payload also
-- ran a conducting that is wrong on purpose -- the feedforward's two
-- projections handed to each other's kernels, which keeps every shape and
-- every kernel correct and changes only who is given what. If the machine
-- reports that answer as identical to the right one, then nothing above
-- this line is measuring what it claims to, and a passing run would mean a
-- payload comparing something against itself.
check("and a conducting bent on purpose is caught",
      bent ~= nil and bent > 0,
      bent == nil and "the machine did not report it"
      or (bent .. " of " .. tostring(total) .. " scores moved, and a "
          .. "conducting known to be wrong must move at least one"))
-- }}}

-- {{{ how far apart, when they are apart at all
--
-- A count says how many differ. It does not say whether the port rounds
-- differently somewhere -- which is a specification question -- or is
-- plainly wrong, which is a defect the wide kernel would inherit. So the
-- first disagreeing pair comes home whole and the distance is worked out
-- here, where there is a language for saying it.
if got and want and got ~= want and matched ~= total then
  local as_float = ffi.new("uint32_t[2]")
  as_float[0], as_float[1] = got, want
  local viewed = ffi.cast("float *", as_float)
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
say("  what this adds to what 100 already proved:")
say("    the ten routines agreed one at a time. Now they agree in the order")
say("    a thought requires -- every tensor, every layer, every head, and")
say("    the conducting itself written in the same tongue. A piece being")
say("    right alone and being handed the wrong thing by the piece before")
say("    it is the failure this rules out, and it is the one the first")
say("    architecture actually met.")
say("")
say("    still not covered: the third architecture, and the hands. The")
say("    catalogue of hands is not identical across machines -- x86 reaches")
say("    devices through a separate address space and this one does not.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("a whole thought in the second tongue: " .. passed .. " of "
                .. (passed + failed) .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
