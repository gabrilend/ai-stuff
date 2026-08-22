#!/usr/bin/env luajit
-- 140-test-the-driver.lua
--
-- A machine that reads what it was told, thinks about it, and says what it
-- thought -- with nothing underneath it -- held word for word to what the
-- readable loop says from the same starting text. Issue 107a.
--
-- For a general: everything below this has been provable alone for a while.
-- This is where the pieces are one machine. It runs twice: once on the
-- development machine, where a failure can be pointed at, and once on an
-- emulated computer with no operating system, which is the claim that matters.
--
-- WHY THE COMPARISON IS TOKEN FOR TOKEN AND NOT "CLOSE". A drawn word is
-- discrete. One different choice at one boundary and the two machines are
-- having different conversations from that word onwards -- so a machine that
-- agrees for five words and differs on the sixth has not nearly agreed, it has
-- diverged, and the only useful threshold is all of them.
--
-- usage:
--   luajit 140-test-the-driver.lua [--dir ROOT] [--seconds N] [--quick]

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

-- {{{ local function ask(command)
local function ask(command)
  local pipe = io.popen(command)
  if not pipe then return "" end
  local text = pipe:read("*a")
  pipe:close()
  return text
end
-- }}}

-- {{{ main
local seconds, quick = 120, false
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 120
  elseif arg[index] == "--quick" then
    quick = true
  end
  index = index + 1
end

say("")
say("  a machine that reads, thinks, and speaks")
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

local driver = dofile(DIR .. "/src/139-the-driver.lua")
local preparer = dofile(DIR .. "/src/137-prepare-the-tokenizer.lua")
local filler = dofile(DIR .. "/src/135-fill-the-plan.lua")
local finder = dofile(DIR .. "/src/131-find-tensors.lua")
local layout = dofile(DIR .. "/src/133-lay-out-memory.lua")
local conductor = dofile(DIR .. "/src/056-emit-conductor.lua")
local sampler = dofile(DIR .. "/src/057-emit-sampler.lua")
local tokenizer = dofile(DIR .. "/src/059-emit-tokenizer.lua")
local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local format = dofile(DIR .. "/src/024-blob-format.lua")
local float_bits = dofile(DIR .. "/src/107-float-bits.lua")
local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local reference = dofile(DIR .. "/src/035-reference-forward.lua")
local reference_sampler = dofile(DIR .. "/src/040-reference-sampler.lua")
local loop_module = dofile(DIR .. "/src/061-thinking-loop.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/logs")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

-- {{{ the model, and the two tables it carries
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

local header_at = preparer.header_offsets(format)
local function u32(text, at)
  local a, b, c, d = text:byte(at + 1, at + 4)
  return a + b * 256 + c * 65536 + d * 16777216
end
local function u64(text, at)
  return u32(text, at) + u32(text, at + 4) * 4294967296
end

local shape = {
  layers = u32(blob, header_at.layers), hidden = u32(blob, header_at.hidden),
  heads = u32(blob, header_at.heads),
  head_width = u32(blob, header_at.head_width),
  kv_heads = u32(blob, header_at.kv_heads),
  feedforward = u32(blob, header_at.feedforward),
  vocabulary = u32(blob, header_at.vocabulary),
  context = u32(blob, header_at.context),
}
local tensor_count = u32(blob, header_at.tensor_count)
local token_count = u32(blob, header_at.token_count)
local merge_count = u32(blob, header_at.merge_count)

local tokens_table, walker = {}, u64(blob, header_at.token_table)
for slot = 1, token_count do
  local length = blob:byte(walker + 1)
  tokens_table[slot] = blob:sub(walker + 2, walker + 1 + length)
  walker = walker + 1 + length
end
local merges_table = {}
for rule = 1, merge_count do
  local at = u64(blob, header_at.merge_table)
            + (rule - 1) * format.MERGE_ENTRY_BYTES
  merges_table[rule] = { u32(blob, at), u32(blob, at + 4) }
end

local text_bytes_total = 0
for _, one in ipairs(tokens_table) do
  text_bytes_total = text_bytes_total + #one
end
-- }}}

-- {{{ what the machine is told, and what it thinks with
--
-- The starting text is written in the bytes this model's vocabulary can say,
-- and it deliberately contains both pairs the merge rules bite on -- so a
-- machine whose preparation quietly resolved no rules would tokenise it into
-- more tokens than the readable loop does and diverge on the first word.
local BOOT_TEXT = string.char(1, 2, 5, 3, 4, 7)
local MAX_TOKENS = 6
local SEED, CARRIED_COUNT = 20260807, 64
local SETTINGS = { temperature = 1.0 }
local carried = reference_sampler.generate_file(SEED, CARRIED_COUNT)
-- }}}

-- {{{ everything, in one library
local source = DIR .. "/tmp/shared-memory/payloads/driver-x86_64.s"
local library = DIR .. "/tmp/kernels/driver-x86_64.so"

-- BACK INTO EXECUTABLE MEMORY BETWEEN EACH PIECE, for the reason `136`
-- records: the kernel emitter ends by switching to the section that marks the
-- stack non-executable, and anything appended after it lands there rather than
-- in the code -- a library that builds without a murmur and faults when called.
local function whole_engine()
  local parts = { emit.source("x86_64", specification) }
  local function add(text) parts[#parts + 1] = "  .text\n" .. text end
  add(conductor.x86_64())
  add(sampler.x86_64())
  add(tokenizer.x86_64())
  add(finder.x86_64(format))
  add(layout.x86_64(format))
  add(filler.x86_64(format, conductor, float_bits))
  add(preparer.x86_64(format, tokenizer))
  add(driver.sampler_x86_64(sampler))
  add(driver.x86_64())
  return table.concat(parts, "\n")
end

local handle = io.open(source, "w")
handle:write(whole_engine())
handle:write('\n  .section .note.GNU-stack,"",@progbits\n')
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source) then
  say("  the whole engine would not build; see " .. source)
  os.exit(1)
end

conductor.declare()
sampler.declare()
tokenizer.declare()
driver.declare_wishes()
driver.declare()
dofile(DIR .. "/src/049-assembly-forward.lua").declare()
ffi.cdef[[
  int64_t find_tensors(const uint8_t *blob, const void **out, int64_t wanted);
  int64_t lay_out(const uint8_t *blob, void *room, int64_t bytes, void **out);
  int64_t fill_plan(void *plan, const uint8_t *blob, const void **tensors,
                    void **regions, const void **kernels, void **layer_table);
  int64_t tokenizer_prepare(const uint8_t *blob, void *room, int64_t bytes,
                            TokenizerPlan *plan, int64_t *detail);
]]
local built = ffi.load(library)
-- }}}

-- {{{ the readable loop's answer, which is the standard
--
-- Its own plan, its own cache, its own prepared tables -- built the hosted way
-- from the same model. If it shared any of them with the assembly below, the
-- comparison would be a program agreeing with itself.
local model = reference.load(blob, format)
local readable = loop_module.new({
  model = model,
  kernels = built,
  conduct = conductor,
  sampler = sampler,
  tokenizer = tokenizer,
  tables = { tokens = tokens_table, merges = merges_table },
  carried = carried,
  settings = SETTINGS,
})
local expected, why = loop_module.think(readable, BOOT_TEXT,
                                        { max_tokens = MAX_TOKENS })
check("the readable loop still speaks from this model",
      expected ~= nil and #expected.tokens > 0,
      why or (expected and ("it said " .. #expected.tokens .. " tokens")))
if not expected then os.exit(1) end
-- }}}

-- {{{ the same thing, set up and driven entirely by the machine's own routines
local blob_bytes = ffi.new("uint8_t[?]", #blob)
ffi.copy(blob_bytes, blob, #blob)

-- one: the weights
local tensors = ffi.new("const void *[?]", tensor_count)
check("the machine finds its own weights",
      tonumber(built.find_tensors(blob_bytes, tensors, tensor_count))
      == tensor_count)

-- two: the memory a thought needs
local _, engine_needed = layout.expected(shape)
local engine_room = ffi.new("uint8_t[?]", engine_needed)
local regions = ffi.new("void *[?]", #layout.REGIONS)
check("and divides its own memory",
      tonumber(built.lay_out(blob_bytes, engine_room, engine_needed, regions))
      == engine_needed)

-- three: the plan the conducting reads
local kernel_names = { "matrix_vector_plain", "rms_normalise", "rotate",
                       "attention_scores", "softmax", "attention_mix",
                       "swiglu", "add_into" }
local kernels = ffi.new("const void *[8]")
for place, name in ipairs(kernel_names) do
  kernels[place - 1] = ffi.cast("const void *", built[name])
end
local forward_plan = ffi.new("ForwardPlan")
local layer_table = ffi.new("void *[?]", shape.layers * #conductor.LAYER_ORDER)
check("and writes down where all of it is",
      tonumber(built.fill_plan(forward_plan, blob_bytes, tensors, regions,
                               kernels, layer_table)) == 0)

-- four: the tokenizer's tables, from the model's own word-lists
local _, tokenizer_needed = preparer.expected(token_count, merge_count,
                                              text_bytes_total)
local tokenizer_room = ffi.new("uint8_t[?]", tokenizer_needed + 16)
local tokenizer_at = ffi.cast("uint8_t *", tokenizer_room)
local drift = tonumber(ffi.cast("uintptr_t", tokenizer_at)) % 16
if drift ~= 0 then tokenizer_at = tokenizer_at + (16 - drift) end
local tokenizer_plan = ffi.new("TokenizerPlan")
local detail = ffi.new("int64_t[1]")
check("and builds the tables that turn text into numbers",
      tonumber(built.tokenizer_prepare(blob_bytes, tokenizer_at,
                                       tokenizer_needed, tokenizer_plan,
                                       detail)) == tokenizer_needed)

-- five: the sampler, and the randomness the image carries
local carried_numbers = ffi.new("uint32_t[?]", #carried)
for slot = 1, #carried do carried_numbers[slot - 1] = carried[slot] end
local wishes = ffi.new("SamplerWishes")
wishes.numbers = carried_numbers
wishes.count = #carried
wishes.k_exp_one = built.exp_one
wishes.vocabulary = shape.vocabulary
wishes.temperature = SETTINGS.temperature
wishes.top_p = 1.0
wishes.top_k = shape.vocabulary
local _, sampler_needed = driver.sampler_room(shape.vocabulary)
local sampler_room = ffi.new("uint8_t[?]", sampler_needed)
local sampler_plan = ffi.new("SamplerPlan")
local sampler_stream = ffi.new("SamplerStream")
check("and readies the randomness it was built with",
      tonumber(built.sampler_setup(sampler_plan, sampler_stream, sampler_room,
                                   sampler_needed, wishes)) == sampler_needed)

-- and the wiring, which is the whole of the driver's plan
local text_room = ffi.new("uint8_t[?]", #BOOT_TEXT)
ffi.copy(text_room, BOOT_TEXT, #BOOT_TEXT)
local token_room = ffi.new("int32_t[?]", shape.context)
local spoken_room = ffi.new("int32_t[?]", MAX_TOKENS)
local scores = ffi.new("float[?]", shape.vocabulary)
local chance = ffi.new("float[1]")
local say_room = ffi.new("uint8_t[?]", 256)

-- what the machine says is gathered rather than printed, so the comparison can
-- be made on bytes. On the board below this is the console; here it is a
-- function, which is the only difference between the two runs.
local heard = {}
local say_hook = ffi.cast("void (*)(const uint8_t *, int64_t, void *)",
  function(bytes, count, _)
    heard[#heard + 1] = ffi.string(bytes, count)
  end)

local plan = ffi.new("DriverPlan")
plan.k_encode = ffi.cast("int64_t (*)(const void *, const uint8_t *, int64_t, int32_t *)",
                         built.tokenizer_encode)
plan.k_decode = ffi.cast("int64_t (*)(const void *, const int32_t *, int64_t, uint8_t *)",
                         built.tokenizer_decode)
plan.k_forward = ffi.cast("void (*)(const void *, int64_t, int64_t, float *)",
                          built.forward_conduct)
plan.k_choose = ffi.cast("int64_t (*)(const void *, const float *, int64_t, float *)",
                         built.sampler_choose)
plan.k_say = say_hook
plan.conductor = forward_plan
plan.tokenizer = tokenizer_plan
plan.sampler = sampler_plan
plan.say_context = nil
plan.text = text_room
plan.text_bytes = #BOOT_TEXT
plan.tokens = token_room
plan.spoken = spoken_room
plan.scores = scores
plan.chance = chance
plan.say_room = say_room
plan.vocabulary = shape.vocabulary
plan.context = shape.context
plan.finish_token = -1
plan.max_tokens = MAX_TOKENS

local stopped = tonumber(built.drive(plan))
check("and then it thinks, and stops for a reason it can name",
      stopped == driver.REASONS.length,
      "it stopped for reason " .. stopped)
-- }}}

-- {{{ and what it said is what the readable loop said
local mine = {}
for slot = 0, tonumber(plan.said) - 1 do
  mine[slot + 1] = spoken_room[slot]
end

local same_count = #mine == #expected.tokens
local diverged = nil
if same_count then
  for slot = 1, #mine do
    if mine[slot] ~= expected.tokens[slot] then
      diverged = diverged or string.format(
        "word %d is %d and should be %d", slot, mine[slot],
        expected.tokens[slot])
    end
  end
end
check("it says as many words as the readable loop says",
      same_count, #mine .. " against " .. #expected.tokens)
check("and they are the same words, in the same order",
      same_count and diverged == nil, diverged)

check("and the cache reaches where the readable loop's reaches",
      tonumber(plan.position) == expected.position,
      tonumber(plan.position) .. " against " .. expected.position)

check("and the text it spoke aloud is the text those words say",
      table.concat(heard) == expected.text,
      string.format("%q against %q", table.concat(heard), expected.text))
-- }}}

-- {{{ the refusals, which are the half nobody exercises
--
-- Each is a real condition a card can meet at first light and each is silent
-- if unhandled: a machine that read text it cannot say, one told more than it
-- can hold, and one told nothing at all.
-- THE RANDOMNESS IS PUT BACK TO ITS START BEFORE EACH ONE, which is not
-- tidiness either. The stream advances by one number per word drawn and every
-- turn below is meant to begin where the turn above began -- a run that
-- inherited a stream six words along would draw six different words and the
-- check that follows would be testing nothing it claims to.
local function drive_with(changes)
  built.sampler_setup(sampler_plan, sampler_stream, sampler_room,
                      sampler_needed, wishes)
  local other = ffi.new("DriverPlan")
  ffi.copy(other, plan, driver.plan_bytes())
  for name, value in pairs(changes) do other[name] = value end
  return tonumber(built.drive(other)), other
end

local unsayable_text = ffi.new("uint8_t[?]", 3)
unsayable_text[0] = 1 ; unsayable_text[1] = 200 ; unsayable_text[2] = 2
local unsayable, unsayable_plan = drive_with({ text = unsayable_text,
                                               text_bytes = 3 })
check("a machine told something it cannot read refuses",
      unsayable == driver.REASONS.unsayable, "returned " .. unsayable)
check("and says which byte of it stopped the reading",
      tonumber(unsayable_plan.detail) == -2,
      "said " .. tonumber(unsayable_plan.detail) .. " rather than -2")

local long_text = ffi.new("uint8_t[?]", shape.context + 4)
for slot = 0, shape.context + 3 do long_text[slot] = 7 end
local too_long, too_long_plan = drive_with({ text = long_text,
                                             text_bytes = shape.context + 4 })
check("a machine told more than it can hold refuses",
      too_long == driver.REASONS.too_long, "returned " .. too_long)
check("and says how many words it was asked to hold",
      tonumber(too_long_plan.detail) == shape.context + 4,
      "said " .. tonumber(too_long_plan.detail))

local nothing = drive_with({ text_bytes = 0 })
check("and a machine told nothing at all says so",
      nothing == driver.REASONS.nothing, "returned " .. nothing)
-- }}}

-- {{{ the finish token, which is a mark rather than a word
--
-- Whatever the machine was going to say first is made the finish token, so
-- the turn must stop before saying anything -- which is the only way to check
-- that the token is swallowed rather than spoken.
local finishing, finishing_plan = drive_with({
  finish_token = expected.tokens[1] })
check("a machine that draws the finish token stops there",
      finishing == driver.REASONS.finished, "returned " .. finishing)
check("and does not say it",
      tonumber(finishing_plan.said) == 0,
      "said " .. tonumber(finishing_plan.said) .. " words")
-- }}}
-- }}}

-- {{{ and now with nothing underneath it
--
-- The same model, the same starting text, the same carried randomness, and
-- the same six words -- on a computer that has no operating system, reached
-- through no interface, driven by nothing but the instructions in the image.
--
-- THE MODEL, THE TEXT AND THE RANDOMNESS RIDE INSIDE THE PAYLOAD, sixty-four
-- kilobytes past its first instruction, and every one of them is reached by
-- measuring from where the code is standing (`029`, and step one of `107`).
-- That is not how a shipped card will carry them -- see the open question in
-- `107a` -- but it is how a payload can carry them today, and it exercises
-- exactly the address arithmetic a shipped one would.
if not quick then
  local geometry = {}
  local pipe = io.popen("luajit " .. DIR .. "/src/029-wrap-uefi.lua --blob-offset")
  geometry.blob_offset = tonumber(pipe:read("*l"))
  pipe:close()

  -- {{{ the machine, built by the thing that builds machines
  -- MOVED OUT 2026-08-22. Everything between here and the boot used to be
  -- written out in this file: the work area divided, the engine emitted, the
  -- tokenizer and sampler set up, the driver's loop entered. Which meant the
  -- only way to obtain a whole machine was to run this test, and the image
  -- builder -- whose entire purpose is producing one -- could not reach it.
  --
  -- A test that builds its own version of the thing is testing its own version.
  -- It is in `144` now, and this checks what comes back.
  local machine = dofile(DIR .. "/src/144-assemble-a-machine.lua")
  local made, why_not = machine.assemble({
    dir = DIR,
    blob = blob,
    text = BOOT_TEXT,
    max_tokens = MAX_TOKENS,
    settings = SETTINGS,
    randomness = carried,
  })
  check("the machine is assembled by the thing that assembles machines",
        made ~= nil, why_not)
  if not made then os.exit(1) end

  -- And it worked the same things out. Every number below was derived twice --
  -- once here, from the model, through the host's own reading of it, and once
  -- inside the machine builder. Two readings of one model agreeing is the check
  -- that the builder is reading the model rather than being told about it.
  check("and read the same model this test read",
        made.shape.layers == shape.layers
        and made.shape.vocabulary == shape.vocabulary
        and made.tensor_count == tensor_count,
        made.tensor_count .. " tensors against " .. tensor_count)
  check("and divided the memory to the same byte",
        made.engine_needed == engine_needed
        and made.tokenizer_needed == tokenizer_needed
        and made.sampler_needed == sampler_needed,
        made.engine_needed .. " against " .. engine_needed)

  local riding = made.riding
  local body = { made.assembly }
  -- }}}

  local base = DIR .. "/tmp/shared-memory/payloads/first-light-x86_64"
  handle = io.open(base .. ".s", "w")
  handle:write(table.concat(body, "\n"))
  handle:close()

  handle = io.open(base .. ".riding", "wb")
  handle:write(riding)
  handle:close()
  -- }}}

  -- {{{ built, wrapped, booted, and read back
  local assembled = run_one("clang --target=x86_64-unknown-none -c "
                            .. base .. ".s -o " .. base .. ".o")
  check("the whole machine assembles into one payload", assembled,
        "see " .. base .. ".s")

  if assembled then
    run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw")
    local raw = read_file(base .. ".raw") or ""
    -- The appended data begins a fixed distance past the code, so a payload
    -- that outgrew that distance would have its own instructions read as
    -- weights. The wrapper refuses it; this says so in numbers first.
    check("and fits in front of what it carries",
          #raw < geometry.blob_offset,
          #raw .. " bytes of code against a boundary at "
          .. geometry.blob_offset)

    local wrapped = run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from "
      .. base .. ".raw --to " .. base .. ".efi --arch x86_64 --append "
      .. base .. ".riding > /dev/null")
    check("and is wrapped in the envelope firmware opens", wrapped)

    -- {{{ onto a medium, and in through the door a real card comes in by
    -- CHANGED 2026-08-22. This used to hand the emulator the payload FILE and
    -- let it synthesise a filesystem around it, which is a road no card has.
    -- The machine now goes onto a medium this project built -- partition
    -- table, filesystem, and the file at the path the board names -- so what
    -- boots here is what would boot off a card, and the two roads stopped
    -- being different ones.
    local medium = dofile(DIR .. "/src/141-a-bootable-medium.lua")
    local carried = read_file(base .. ".efi") or ""
    local made, why_not = medium.medium({
      bytes = carried,
      path = "EFI/BOOT/BOOTX64.EFI",
      identity = "first-light-x86_64",
      label = "SEED",
    })
    check("and goes onto a medium a firmware can open", made ~= nil, why_not)
    if made then
      local where = DIR .. "/tmp/shared-memory/payloads/first-light-x86_64.img"
      local out = io.open(where, "wb")
      out:write(made.image)
      out:close()

      local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-x86-64-serial.log"
      run_one("rm -f " .. serial)
      run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-x86-64"
        .. " --medium " .. where .. " --memory plenty --seconds " .. seconds
        .. " --dir " .. DIR .. " > /dev/null 2>&1")
    end
    -- }}}
    local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-x86-64-serial.log"
    local spoken_aloud = read_file(serial) or ""

    check("a computer with nothing on it reaches first light",
          spoken_aloud:find("first light", 1, true) ~= nil,
          "the board said nothing this program wrote; see " .. serial)

    local function number_after(what)
      return tonumber(spoken_aloud:match(what .. "%s+(%x+)") or "", 16)
    end

    check("and finds every one of its own weights",
          number_after("weights") == tensor_count,
          tostring(number_after("weights")) .. " of " .. tensor_count)
    check("and divides its memory to the byte the host expects",
          number_after("memory") == engine_needed,
          tostring(number_after("memory")) .. " against " .. engine_needed)
    check("and fills the plan the conducting reads",
          number_after("plan") == 0, tostring(number_after("plan")))
    check("and builds its word tables from the model it carries",
          number_after("words%s+") == tokenizer_needed,
          tostring(number_after("words%s+")) .. " against " .. tokenizer_needed)
    check("and readies the randomness baked into it",
          number_after("chance") == sampler_needed,
          tostring(number_after("chance")) .. " against " .. sampler_needed)

    check("and then it thinks, and says why it stopped",
          number_after("reason") == driver.REASONS.length,
          tostring(number_after("reason")))
    check("and its cache reaches where the readable loop's reaches",
          number_after("position") == expected.position,
          tostring(number_after("position")) .. " against " .. expected.position)

    -- {{{ the words, which is the whole claim
    local aloud = {}
    for one in spoken_aloud:gmatch("word%s+(%x+)") do
      aloud[#aloud + 1] = tonumber(one, 16)
    end
    local matched = #aloud == #expected.tokens
    local wrong = nil
    if matched then
      for slot = 1, #aloud do
        if aloud[slot] ~= expected.tokens[slot] then
          wrong = wrong or string.format("word %d is %d and should be %d",
                                         slot, aloud[slot],
                                         expected.tokens[slot])
        end
      end
    end
    check("it says as many words as the readable loop says",
          matched, #aloud .. " against " .. #expected.tokens)
    check("and they are the same words, in the same order",
          matched and wrong == nil, wrong)

    -- and the bytes it put on the wire, which came through the decoder rather
    -- than out of the token numbers
    local between = spoken_aloud:match("<<(.-)>>") or ""
    local as_bytes = {}
    for pair in between:gmatch("%x%x") do
      as_bytes[#as_bytes + 1] = string.char(tonumber(pair, 16))
    end
    check("and the text it spoke aloud is the text those words say",
          table.concat(as_bytes) == expected.text,
          string.format("%q against %q", table.concat(as_bytes),
                        expected.text))

    check("and it says so and stops rather than falling off the end",
          spoken_aloud:find("finished", 1, true) ~= nil,
          "see " .. serial)
    -- }}}
  end
  -- }}}
else
  say("  (--quick: the board was not booted)")
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this completes:")
say("    the loop. A machine with no operating system reads what it was")
say("    told, turns it into numbers, runs the engine, draws a word, says")
say("    it and thinks about it again -- and says the same words the")
say("    readable loop says from the same text and the same randomness.")
say("")
say("  what remains of the driver:")
say("    noticing that what it said was a request, and carrying it out.")
say("")

os.exit(failed == 0 and 0 or 1)
