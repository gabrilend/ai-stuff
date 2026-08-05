#!/usr/bin/env luajit
-- 136-test-fill-the-plan.lua
--
-- Telling the conducting where everything is, on all three machines -- and
-- on the first, setting a machine up from nothing and requiring it to think
-- correctly. Issue 107.
--
-- For a general: the previous two pieces found the weights and divided the
-- memory. This writes down where all of it is, in the form the conducting
-- reads. On the first architecture the whole chain is then run for real: find,
-- divide, fill, and think -- with the answer held to the recorded one, which
-- is the strongest statement available about a setup routine.
--
-- WHY THINKING IS A BETTER TEST THAN COMPARING SLOTS. A slot written one
-- place along is not an error. Comparing the plan against a plan says only
-- that two programs agree; running the engine with it says the plan is
-- *usable*, and every wrong slot becomes a wrong score. The slot comparison
-- is kept as well, because it says WHICH slot -- one answers "does it work",
-- the other answers "what is broken", and a setup routine wants both.
--
-- usage:
--   luajit 136-test-fill-the-plan.lua [--dir ROOT] [--seconds N]

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

-- {{{ main
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
say("  setting a machine up from nothing")
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

local filler = dofile(DIR .. "/src/135-fill-the-plan.lua")
local finder = dofile(DIR .. "/src/131-find-tensors.lua")
local layout = dofile(DIR .. "/src/133-lay-out-memory.lua")
local conductor = dofile(DIR .. "/src/056-emit-conductor.lua")
local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local format = dofile(DIR .. "/src/024-blob-format.lua")
local float_bits = dofile(DIR .. "/src/107-float-bits.lua")
local specification = dofile(DIR .. "/src/047-reference-exp.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

-- {{{ the model, read once
local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local blob = read_file(blob_path)
if not blob then
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR
          .. " > /dev/null")
  blob = read_file(blob_path)
end
if not blob then
  say("  no fixture model, and it would not build")
  os.exit(1)
end

local header_at = filler.header_offsets(format)
local function u32(at)
  local a, b, c, d = blob:byte(at + 1, at + 4)
  return a + b * 256 + c * 65536 + d * 16777216
end
local shape = {
  layers = u32(header_at.layers), hidden = u32(header_at.hidden),
  heads = u32(header_at.heads), head_width = u32(header_at.head_width),
  kv_heads = u32(header_at.kv_heads),
  feedforward = u32(header_at.feedforward),
  vocabulary = u32(header_at.vocabulary), context = u32(header_at.context),
}
local tensor_count = u32(header_at.tensor_count)
local plan_at = conductor.offsets()
-- }}}

-- {{{ the whole chain, on the first architecture, ending in a thought
local source = DIR .. "/tmp/shared-memory/payloads/setup-x86_64.s"
local library = DIR .. "/tmp/kernels/setup-x86_64.so"
local handle = io.open(source, "w")
-- BACK INTO EXECUTABLE MEMORY BETWEEN EACH PIECE. The kernel emitter ends
-- its output by switching to the section that marks the stack
-- non-executable, so anything appended after it lands THERE rather than in
-- the code -- and calling into it faults, from a library that built without
-- a murmur. This is the same shape of failure `033` met on a real board when
-- firmware mapped a payload's code read-only: a section is a claim about
-- what memory is for, and appending across one silently changes the claim.
handle:write(emit.source("x86_64", specification))
handle:write("  .text\n")
handle:write(conductor.x86_64())
handle:write("  .text\n")
handle:write(finder.x86_64(format))
handle:write("  .text\n")
handle:write(layout.x86_64(format))
handle:write("  .text\n")
handle:write(filler.x86_64(format, conductor, float_bits))
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source) then
  say("  the first architecture's setup would not build")
  os.exit(1)
end

conductor.declare()
-- the kernels, so their addresses can be taken. On a real machine the driver
-- knows where it put them; here the loader is asked.
dofile(DIR .. "/src/049-assembly-forward.lua").declare()
ffi.cdef[[
  int64_t find_tensors(const uint8_t *blob, const void **out, int64_t wanted);
  int64_t lay_out(const uint8_t *blob, void *room, int64_t bytes, void **out);
  int64_t fill_plan(void *plan, const uint8_t *blob, const void **tensors,
                    void **regions, const void **kernels, void **layer_table);
]]
local built = ffi.load(library)

local blob_bytes = ffi.new("uint8_t[?]", #blob)
ffi.copy(blob_bytes, blob, #blob)

-- one: find every tensor
local tensors = ffi.new("const void *[?]", tensor_count)
check("the weights were found",
      tonumber(built.find_tensors(blob_bytes, tensors, tensor_count))
      == tensor_count)

-- two: divide the memory
local _, needed = layout.expected(shape)
local room = ffi.new("uint8_t[?]", needed)
local regions = ffi.new("void *[?]", #layout.REGIONS)
check("the memory was divided",
      tonumber(built.lay_out(blob_bytes, room, needed, regions)) == needed)

-- three: fill the plan. The kernel addresses are the one thing only the
-- caller knows -- on a real machine it is the driver, which put them there.
local kernels = ffi.new("const void *[8]")
local names = { "matrix_vector_plain", "rms_normalise", "rotate",
                "attention_scores", "softmax", "attention_mix",
                "swiglu", "add_into" }
for place, name in ipairs(names) do
  kernels[place - 1] = ffi.cast("const void *", built[name])
end

local plan = ffi.new("ForwardPlan")
local layer_table = ffi.new("void *[?]", shape.layers * #conductor.LAYER_ORDER)
check("the plan was filled",
      tonumber(built.fill_plan(plan, blob_bytes, tensors, regions,
                               kernels, layer_table)) == 0)

-- and every count it wrote is what the model says
local counts_hold, count_trouble = true, nil
local expected_counts = {
  layers = shape.layers, hidden = shape.hidden, heads = shape.heads,
  head_width = shape.head_width, kv_heads = shape.kv_heads,
  feedforward = shape.feedforward, vocabulary = shape.vocabulary,
  context = shape.context,
  heads_per_kv = shape.heads / shape.kv_heads,
  kv_width = shape.kv_heads * shape.head_width,
  query_width = shape.heads * shape.head_width,
}
for name, want in pairs(expected_counts) do
  if tonumber(plan[name]) ~= want then
    counts_hold = false
    count_trouble = count_trouble or
      (name .. " is " .. tostring(plan[name]) .. " and should be " .. want)
  end
end
check("and every count in it is what the model says",
      counts_hold, count_trouble)

-- the attention scale, rounded through single precision exactly as the
-- readable engine does it
local rounder = ffi.new("float[1]")
rounder[0] = 1 / math.sqrt(shape.head_width)
check("and the attention scale is rounded the way the engine rounds it",
      plan.scale == rounder[0],
      string.format("%.9g against %.9g", plan.scale, rounder[0]))
check("and the normalisation constant is the one the specification names",
      plan.epsilon == ffi.cast("float", filler.EPSILON),
      string.format("%.9g", plan.epsilon))

-- the layer table, which is where a wrong stride hides
local table_holds, table_trouble = true, nil
for layer = 0, shape.layers - 1 do
  for which = 0, #conductor.LAYER_ORDER - 1 do
    local place = layer * #conductor.LAYER_ORDER + which
    if layer_table[place] ~= tensors[2 + place] then
      table_holds = false
      table_trouble = table_trouble or string.format(
        "layer %d slot %d points at tensor %d rather than %d",
        layer, which, -1, 2 + place)
    end
  end
end
check("and every layer's nine tensors are the right nine",
      table_holds, table_trouble)

-- FOUR: think with it. This is the claim the other checks only approach --
-- a plan that is merely consistent is not the same as a plan that works.
local fixture = dofile(DIR .. "/assets/036-fixture.lua")
local scores = ffi.new("float[?]", shape.vocabulary)
local drifted = nil
for step, token in ipairs(fixture.prompt) do
  built.forward_conduct(plan, token, step - 1, scores)
  for place = 1, #fixture.logits[step] do
    rounder[0] = fixture.logits[step][place]
    if scores[place - 1] ~= rounder[0] then
      drifted = drifted or string.format(
        "step %d, score %d: %.9g against the recorded %.9g",
        step, place - 1, scores[place - 1], rounder[0])
    end
  end
end
check("and a machine set up this way thinks the recorded answer",
      drifted == nil, drifted)
-- }}}

-- {{{ what the other two are asked
--
-- Not a comparison against the host's addresses, which would be meaningless:
-- three machines load the bytes in three places. What is checked is that
-- every slot points where the payload ITSELF said it should -- the tensor it
-- passed in, the region it passed in, the kernel it passed in. That is the
-- wiring, and the wiring is what goes silently wrong.
local function as_words_of(bytes)
  local out = {}
  for at = 1, #bytes, 4 do
    local word = 0
    for step = 0, 3 do
      word = word + (bytes:byte(at + step) or 0) * (256 ^ step)
    end
    out[#out + 1] = word
  end
  return out
end
local blob_words = as_words_of(blob)

-- the counts, which ARE the same on every machine
local count_order = { "layers", "hidden", "heads", "head_width", "kv_heads",
                      "heads_per_kv", "feedforward", "vocabulary", "context",
                      "kv_width", "query_width" }
local count_words = {}
for _, name in ipairs(count_order) do
  local value = expected_counts[name]
  count_words[#count_words + 1] = value % 4294967296
  count_words[#count_words + 1] = math.floor(value / 4294967296)
end
-- }}}

-- {{{ the second architecture
local function aarch64_payload()
  local out = {}
  local function line(text) out[#out + 1] = text end
  -- HOW MUCH STACK IS TAKEN, and it is a third of what was first written.
  -- The specification guarantees a payload a hundred and twenty-eight
  -- kilobytes, and taking all of it leaves the pointer at the very bottom --
  -- so the first call into firmware pushes past the end and the machine
  -- takes an exception with no handler. It had said three marks by then,
  -- which is why the last mark before silence is the whole diagnosis.
  local WORK = { plan = 0, tensors = 512, regions = 1024, kernels = 1536,
                 layers = 2048, room = 8192, stack = 0x8000 }

  line("  .text")
  line("  .globl _start")
  line("_start:")
  line("  b start_here")
  local function strip(text)
    return (text:gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
                :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n"))
  end
  line(strip(finder.aarch64(format)))
  line(strip(layout.aarch64(format)))
  line(strip(filler.aarch64(format, conductor, float_bits)))

  line("start_here:")
  -- a move-immediate carries sixteen bits, so a hundred and thirty-one
  -- thousand bytes arrives as its top half shifted up rather than whole
  line("  movz x9, #" .. WORK.stack)
  line("  sub sp, sp, x9")
  line("  mov x19, x1")
  line("  ldr x20, [x19, #64]")
  line("  mov x21, sp")
  line("  mov x22, xzr")                    -- slots right
  line("  mov x23, xzr")                    -- slots checked

  local said = 0
  local function say_text(text)
    said = said + 1
    local skip, label = "fpskip" .. said, "fptext" .. said
    line("  b " .. skip)
    line(label .. ":")
    for at = 1, #text do line("  .short " .. text:byte(at)) end
    line("  .short 0")
    line("  .balign 4")
    line(skip .. ":")
    line("  adr x1, " .. label)
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end
  local function say_hex(register)
    said = said + 1
    local loop, digit, done = "fph" .. said, "fpd" .. said, "fpe" .. said
    line("  mov x9, " .. register)
    line("  add x10, x21, #64")
    line("  mov w11, #16")
    line(loop .. ":")
    line("  lsr x12, x9, #60")
    line("  lsl x9, x9, #4")
    line("  cmp w12, #10")
    line("  b.lt " .. digit)
    line("  add w12, w12, #87")
    line("  b " .. done)
    line(digit .. ":")
    line("  add w12, w12, #48")
    line(done .. ":")
    line("  strh w12, [x10], #2")
    line("  subs w11, w11, #1")
    line("  b.ne " .. loop)
    line("  strh wzr, [x10]")
    line("  add x1, x21, #64")
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end

  say_text("\r\nsetting up, second tongue\r\n")

  line("  b fpdata_done")
  line("  .balign 16")
  line("fpblob:")
  local row = {}
  for at, word in ipairs(blob_words) do
    row[#row + 1] = string.format("0x%08x", word)
    if #row == 8 or at == #blob_words then
      line("  .word " .. table.concat(row, ", "))
      row = {}
    end
  end
  line("  .balign 16")
  line("fpcounts:")
  row = {}
  for at, word in ipairs(count_words) do
    row[#row + 1] = string.format("0x%08x", word)
    if #row == 8 or at == #count_words then
      line("  .word " .. table.concat(row, ", "))
      row = {}
    end
  end
  line("fpdata_done:")

  -- find, divide, fill
  line("  adr x0, fpblob")
  line("  add x1, x21, #" .. WORK.tensors)
  line("  movz x2, #" .. tensor_count)
  line("  bl find_tensors")
  say_text(".")

  line("  adr x0, fpblob")
  line("  add x1, x21, #" .. WORK.room)
  line("  movz x2, #" .. needed)
  line("  add x3, x21, #" .. WORK.regions)
  line("  bl lay_out")
  say_text(".")

  -- the eight kernel addresses. On a real machine these are where the driver
  -- put its own routines; here they are made-up numbers, because what is
  -- being checked is that they arrive in the right slots rather than that
  -- they point anywhere in particular.
  line("  add x10, x21, #" .. WORK.kernels)
  for place = 0, 7 do
    line("  movz x9, #" .. (0x1000 + place * 0x100))
    line("  str x9, [x10, #" .. (place * 8) .. "]")
  end

  line("  mov x0, x21")
  line("  adr x1, fpblob")
  line("  add x2, x21, #" .. WORK.tensors)
  line("  add x3, x21, #" .. WORK.regions)
  line("  add x4, x21, #" .. WORK.kernels)
  line("  add x5, x21, #" .. WORK.layers)
  line("  bl fill_plan")
  line("  mov x24, x0")                     -- kept before anything is said,
  say_text(".")                             -- since saying clobbers the low
                                            -- registers and the firmware
                                            -- hands back its own status in
                                            -- the very one an answer arrives
                                            -- in. A probe that forgot this
                                            -- reported a routine returning
                                            -- nought when it had returned
                                            -- twenty-two.                     -- what it said

  line("  add x23, x23, #1")
  line("  cbnz x24, fpfilled")
  line("  add x22, x22, #1")
  line("fpfilled:")

  -- the eleven counts, which are the same on every machine
  line("  adr x6, fpcounts")
  for place, name in ipairs(count_order) do
    line("  ldr x8, [x21, #" .. plan_at[name] .. "]")
    line("  ldr x9, [x6, #" .. ((place - 1) * 8) .. "]")
    line("  add x23, x23, #1")
    line("  cmp x8, x9")
    line("  b.ne fpc" .. place)
    line("  add x22, x22, #1")
    line("fpc" .. place .. ":")
  end

  -- and the wiring: every pointer slot must hold what was handed in
  local kernel_slots = { "multiply", "k_rms_normalise", "k_rotate",
                         "k_attention_scores", "k_softmax",
                         "k_attention_mix", "k_swiglu", "k_add_into" }
  for place, name in ipairs(kernel_slots) do
    line("  add x10, x21, #" .. WORK.kernels)
    line("  ldr x9, [x10, #" .. ((place - 1) * 8) .. "]")
    line("  ldr x8, [x21, #" .. plan_at[name] .. "]")
    line("  add x23, x23, #1")
    line("  cmp x8, x9")
    line("  b.ne fpk" .. place)
    line("  add x22, x22, #1")
    line("fpk" .. place .. ":")
  end

  local region_slots = { "state", "normalised", "query", "attended",
                         "projected", "gate", "up", "scores",
                         "cache_keys", "cache_values" }
  for place, name in ipairs(region_slots) do
    line("  add x10, x21, #" .. WORK.regions)
    line("  ldr x9, [x10, #" .. ((place - 1) * 8) .. "]")
    line("  ldr x8, [x21, #" .. plan_at[name] .. "]")
    line("  add x23, x23, #1")
    line("  cmp x8, x9")
    line("  b.ne fpr" .. place)
    line("  add x22, x22, #1")
    line("fpr" .. place .. ":")
  end

  -- the two fixed tensors at the front, and the two at the back
  line("  add x10, x21, #" .. WORK.tensors)
  for place, name in ipairs({ "token_embedding", "rotation" }) do
    line("  ldr x9, [x10, #" .. ((place - 1) * 8) .. "]")
    line("  ldr x8, [x21, #" .. plan_at[name] .. "]")
    line("  add x23, x23, #1")
    line("  cmp x8, x9")
    line("  b.ne fpt" .. place)
    line("  add x22, x22, #1")
    line("fpt" .. place .. ":")
  end
  local tail = 2 + shape.layers * #conductor.LAYER_ORDER
  for place, name in ipairs({ "output_norm", "output" }) do
    line("  movz x9, #" .. ((tail + place - 1) * 8))
    line("  ldr x9, [x10, x9]")
    line("  ldr x8, [x21, #" .. plan_at[name] .. "]")
    line("  add x23, x23, #1")
    line("  cmp x8, x9")
    line("  b.ne fpo" .. place)
    line("  add x22, x22, #1")
    line("fpo" .. place .. ":")
  end

  -- and every entry of the layer table, which is where a wrong stride hides
  line("  add x11, x21, #" .. WORK.layers)
  line("  add x10, x21, #" .. WORK.tensors)
  line("  add x10, x10, #16")               -- past the two at the front
  line("  movz x7, #" .. (shape.layers * #conductor.LAYER_ORDER))
  line("fplt:")
  line("  ldr x8, [x11], #8")
  line("  ldr x9, [x10], #8")
  line("  add x23, x23, #1")
  line("  cmp x8, x9")
  line("  b.ne fpltno")
  line("  add x22, x22, #1")
  line("fpltno:")
  line("  subs x7, x7, #1")
  line("  b.ne fplt")

  say_text("plan filled\r\n  right ")
  say_hex("x22")
  say_text("\r\n  of ")
  say_hex("x23")
  say_text("\r\n")

  line("fphalt:")
  line("  wfi")
  line("  b fphalt")
  return table.concat(out, "\n")
end

local arm_base = DIR .. "/tmp/shared-memory/payloads/setup-aarch64"
handle = io.open(arm_base .. ".s", "w")
handle:write(aarch64_payload())
handle:close()

if not run_one("clang --target=aarch64-unknown-none -c " .. arm_base
               .. ".s -o " .. arm_base .. ".o") then
  check("the second architecture's setup assembles", false,
        "see " .. arm_base .. ".s")
else
  check("the second architecture's setup assembles", true)
  run_one("llvm-objcopy -O binary " .. arm_base .. ".o " .. arm_base .. ".raw")
  run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. arm_base
          .. ".raw --to " .. arm_base .. ".efi --arch aarch64 > /dev/null")

  local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-arm64-serial.log"
  run_one("rm -f " .. serial)
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-arm64"
    .. " --payload " .. arm_base .. ".efi --seconds " .. seconds
    .. " --dir " .. DIR .. " > /dev/null 2>&1")

  local spoken = read_file(serial) or ""
  local report = spoken:match("plan filled(.*)$") or ""
  local right = tonumber(report:match("[\r\n]%s*right%s+(%x+)") or "", 16)
  local of = tonumber(report:match("[\r\n]%s*of%s+(%x+)") or "", 16)

  check("and sets itself up with every slot where it belongs",
        right ~= nil and of ~= nil and right == of and of > 40,
        tostring(right) .. " of " .. tostring(of) .. "; see " .. serial)
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this completes:")
say("    the setup. A machine can now find its own weights, divide its own")
say("    memory, and write down where all of it is -- with no linker, no")
say("    allocator and nothing underneath it. On the first architecture the")
say("    whole chain was run and the machine thought the recorded answer,")
say("    which is the only statement about a setup routine worth making.")
say("")
say("  what remains of the driver:")
say("    reading the instruction out of the image, and the loop -- tokenise,")
say("    conduct, draw, append, say -- with the hands after it.")
say("")

os.exit(failed == 0 and 0 or 1)
-- }}}
