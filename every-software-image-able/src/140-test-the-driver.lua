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

  -- {{{ what rides along, and where
  -- MOVED OUT OF HERE 2026-08-22. This arrangement -- model, then text, then
  -- randomness, each on sixteen bytes -- used to be worked out in this test and
  -- nowhere else, which meant the layout the machine actually boots with lived
  -- somewhere nothing but this test could reach. Meanwhile the image builder
  -- laid down a different arrangement that nothing has ever read. It is in 143
  -- now, and both read it from there.
  local rides = dofile(DIR .. "/src/143-what-rides-inside.lua")

  local carried_bytes = {}
  for _, number in ipairs(carried) do
    carried_bytes[#carried_bytes + 1] = string.char(
      number % 256, math.floor(number / 256) % 256,
      math.floor(number / 65536) % 256, math.floor(number / 16777216) % 256)
  end

  local riding_plan = rides.plan({
    model = blob,
    text = BOOT_TEXT,
    randomness = table.concat(carried_bytes),
  })
  local APPEND = riding_plan.at
  local riding = riding_plan.bytes
  -- }}}

  -- {{{ the work area, divided before a single instruction is emitted
  --
  -- Every address the payload uses is an offset from one register, and the
  -- offsets are worked out here where they can be read rather than in the
  -- assembly where they cannot. The whole area is taken from the stack, above
  -- where calls will push, because a payload has nothing else to take memory
  -- from -- there is no allocator and the firmware's map has not been asked
  -- for. It is a hundred times smaller than the stack the specification
  -- guarantees, which is the lesson `136` paid for.
  local WORK, work_at = {}, 0
  local function reserve(name, bytes)
    WORK[name] = work_at
    work_at = work_at + bytes
    if work_at % 16 ~= 0 then work_at = work_at + (16 - work_at % 16) end
  end
  reserve("forward_plan", #conductor.SLOTS * 8)
  reserve("tensors", tensor_count * 8)
  reserve("regions", #layout.REGIONS * 8)
  reserve("kernels", 8 * 8)
  reserve("layer_table", shape.layers * #conductor.LAYER_ORDER * 8)
  reserve("tokenizer_plan", #tokenizer.PLAN_SLOTS * 8)
  reserve("sampler_plan", #sampler.PLAN_SLOTS * 8)
  reserve("sampler_stream", #sampler.STREAM_SLOTS * 8)
  reserve("wishes", driver.wish_bytes())
  reserve("driver_plan", driver.plan_bytes())
  reserve("tokens", shape.context * 4)
  reserve("spoken", MAX_TOKENS * 4)
  reserve("scores", shape.vocabulary * 4)
  reserve("chance", 16)
  reserve("say_room", 256)
  reserve("detail", 16)
  reserve("engine_room", engine_needed)
  reserve("tokenizer_room", tokenizer_needed)
  reserve("sampler_room", sampler_needed)
  local WORK_BYTES = work_at + 256
  if WORK_BYTES % 16 ~= 0 then
    WORK_BYTES = WORK_BYTES + (16 - WORK_BYTES % 16)
  end
  -- }}}

  local plan_at = driver.plan_offsets()
  local wish_at = driver.wish_offsets()

  -- {{{ the payload
  local body = {}
  local function line(text) body[#body + 1] = text end
  local said = 0

  -- Saying something is inlined rather than called, following `086`: the
  -- firmware's console wants sixteen-bit characters and a payload has no
  -- string library, so each mark is laid down as data beside the instruction
  -- that points at it. The jump comes first, because a string in the
  -- instruction stream is perfectly good data and perfectly terrible code.
  local function mark(text)
    said = said + 1
    local skip, label = "flskip" .. said, "fltext" .. said
    line("  jmp " .. skip)
    line(label .. ":")
    for at = 1, #text do line("  .short " .. text:byte(at)) end
    line("  .short 0")
    line(skip .. ":")
    line("  leaq " .. label .. "(%rip), %rdx")
    line("  movq %r15, %rcx")
    line("  movq 8(%r15), %rax")
    line("  callq *%rax")
  end

  local function say_hex(register)
    said = said + 1
    local loop, digit, done = "flh" .. said, "fld" .. said, "fle" .. said
    line("  movq " .. register .. ", %rax")
    line("  leaq 0x40(%rsp), %r11")
    line("  movq $16, %rcx")
    line(loop .. ":")
    line("  rolq $4, %rax")
    line("  movl %eax, %edx")
    line("  andl $15, %edx")
    line("  cmpl $10, %edx")
    line("  jl " .. digit)
    line("  addl $87, %edx")
    line("  jmp " .. done)
    line(digit .. ":")
    line("  addl $48, %edx")
    line(done .. ":")
    line("  movw %dx, (%r11)")
    line("  addq $2, %r11")
    line("  decq %rcx")
    line("  jnz " .. loop)
    line("  movw $0, (%r11)")
    line("  leaq 0x40(%rsp), %rdx")
    line("  movq %r15, %rcx")
    line("  movq 8(%r15), %rax")
    line("  callq *%rax")
  end

  local function stamp(what, register)
    mark(what)
    say_hex(register)
    mark("\r\n")
  end

  line("  .code64")
  line("  .globl _start")
  line("_start:")
  -- A LOCAL label beside the global one, and everything measures from this.
  -- A reference to a global symbol is a note for a linker, and with no linker
  -- the note is dropped and a zero left behind -- which is two of the four
  -- silences in `107`'s table and cost `033` a payload that printed plausible
  -- nonsense.
  line("here:")
  line("  jmp fl_start")

  -- {{{ everything the machine is made of, with its names made local
  --
  -- The `.globl` markers are stripped for the same reason. Within one
  -- assembly unit a local name is resolved by the assembler and becomes a real
  -- offset; a global one becomes a relocation nobody will ever apply.
  local function strip(text)
    return (text:gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
                :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n"))
  end
  line(strip(whole_engine()))
  line("  .text")
  -- }}}

  -- {{{ the console, as the driver reaches it
  --
  -- BYTES ARE SPELLED IN HEXADECIMAL RATHER THAN PRINTED AS CHARACTERS, and
  -- that is a decision about what can be checked rather than about what looks
  -- nice. This model's vocabulary says low bytes, including nought -- and a
  -- nought handed to a console that wants a terminated string ends the line
  -- there, so a machine that said the right thing would look like a machine
  -- that said half of it. In hexadecimal every byte survives the trip and the
  -- comparison afterwards is exact.
  line("say_bytes:")
  line("  pushq %rbx")
  line("  pushq %r12")
  line("  pushq %r13")
  line("  pushq %r14")
  line("  subq $0x268, %rsp")
  line("  movq %rdx, %rbx")
  line("  leaq 0x40(%rsp), %r12")
  line("  cmpq $128, %rsi")
  line("  jle sb_within")
  line("  movq $128, %rsi")
  line("sb_within:")
  line("  testq %rsi, %rsi")
  line("  jz sb_end")
  line("sb_next:")
  line("  movzbl (%rdi), %eax")
  for _, half in ipairs({ "high", "low" }) do
    line("  movl %eax, %ecx")
    if half == "high" then
      line("  shrl $4, %ecx")
    else
      line("  andl $15, %ecx")
    end
    line("  cmpl $10, %ecx")
    line("  jl sb_digit_" .. half)
    line("  addl $87, %ecx")
    line("  jmp sb_put_" .. half)
    line("sb_digit_" .. half .. ":")
    line("  addl $48, %ecx")
    line("sb_put_" .. half .. ":")
    line("  movw %cx, (%r12)")
    line("  addq $2, %r12")
  end
  line("  incq %rdi")
  line("  decq %rsi")
  line("  jnz sb_next")
  line("sb_end:")
  line("  movw $0, (%r12)")
  line("  movq %rbx, %rcx")
  line("  leaq 0x40(%rsp), %rdx")
  line("  movq 8(%rbx), %rax")
  line("  callq *%rax")
  line("  addq $0x268, %rsp")
  line("  popq %r14")
  line("  popq %r13")
  line("  popq %r12")
  line("  popq %rbx")
  line("  retq")
  -- }}}

  line("fl_start:")
  line("  movq %rdx, %r14")                   -- the firmware's table
  line("  movq 64(%r14), %r15")               -- and its console
  line("  leaq here(%rip), %r13")             -- where we are standing
  -- the work area, above where calls will push, and scratch below it for the
  -- thirty-two bytes every call into firmware is owed plus room to spell a
  -- number out in
  line("  subq $" .. WORK_BYTES .. ", %rsp")
  line("  andq $-16, %rsp")
  line("  movq %rsp, %rbp")
  line("  subq $0x100, %rsp")

  local function work(name) return WORK[name] .. "(%rbp)" end
  local function riding_at(name)
    return string.format("0x%x", geometry.blob_offset + APPEND[name]) .. "(%r13)"
  end

  mark("\r\nfirst light\r\n")

  -- {{{ the setup, narrated a step at a time
  --
  -- Verbose by default and quietened later, never before. Every one of the
  -- four silences this project has met was diagnosed by the last mark printed,
  -- and a setup routine that says nothing until it succeeds says nothing at
  -- all when it does not.
  line("  leaq " .. riding_at("model") .. ", %rdi")
  line("  leaq " .. work("tensors") .. ", %rsi")
  line("  movq $" .. tensor_count .. ", %rdx")
  line("  callq find_tensors")
  line("  movq %rax, %rbx")                   -- kept before anything is said
  stamp("  weights  ", "%rbx")

  line("  leaq " .. riding_at("model") .. ", %rdi")
  line("  leaq " .. work("engine_room") .. ", %rsi")
  line("  movq $" .. engine_needed .. ", %rdx")
  line("  leaq " .. work("regions") .. ", %rcx")
  line("  callq lay_out")
  line("  movq %rax, %rbx")
  stamp("  memory   ", "%rbx")

  line("  leaq " .. work("kernels") .. ", %r10")
  for place, name in ipairs(kernel_names) do
    line("  leaq " .. name .. "(%rip), %rax")
    line("  movq %rax, " .. ((place - 1) * 8) .. "(%r10)")
  end

  line("  leaq " .. work("forward_plan") .. ", %rdi")
  line("  leaq " .. riding_at("model") .. ", %rsi")
  line("  leaq " .. work("tensors") .. ", %rdx")
  line("  leaq " .. work("regions") .. ", %rcx")
  line("  leaq " .. work("kernels") .. ", %r8")
  line("  leaq " .. work("layer_table") .. ", %r9")
  line("  callq fill_plan")
  line("  movq %rax, %rbx")
  stamp("  plan     ", "%rbx")

  line("  leaq " .. riding_at("model") .. ", %rdi")
  line("  leaq " .. work("tokenizer_room") .. ", %rsi")
  line("  movq $" .. tokenizer_needed .. ", %rdx")
  line("  leaq " .. work("tokenizer_plan") .. ", %rcx")
  line("  leaq " .. work("detail") .. ", %r8")
  line("  callq tokenizer_prepare")
  line("  movq %rax, %rbx")
  stamp("  words    ", "%rbx")

  line("  leaq " .. work("wishes") .. ", %r10")
  line("  leaq " .. riding_at("randomness") .. ", %rax")
  line("  movq %rax, " .. wish_at.numbers .. "(%r10)")
  line("  movq $" .. #carried .. ", " .. wish_at.count .. "(%r10)")
  line("  leaq exp_one(%rip), %rax")
  line("  movq %rax, " .. wish_at.k_exp_one .. "(%r10)")
  line("  movq $" .. shape.vocabulary .. ", " .. wish_at.vocabulary .. "(%r10)")
  -- the two settings that are floats, carried as the patterns they are: there
  -- is no way to say "one" to a processor that is expecting a float, and a
  -- decimal parsed back would be a rounding this is meant to be free of
  line(string.format("  movq $0x%08x, %%rax", float_bits.of(SETTINGS.temperature)))
  line("  movq %rax, " .. wish_at.temperature .. "(%r10)")
  line(string.format("  movq $0x%08x, %%rax", float_bits.of(1.0)))
  line("  movq %rax, " .. wish_at.top_p .. "(%r10)")
  line("  movq $" .. shape.vocabulary .. ", " .. wish_at.top_k .. "(%r10)")

  line("  leaq " .. work("sampler_plan") .. ", %rdi")
  line("  leaq " .. work("sampler_stream") .. ", %rsi")
  line("  leaq " .. work("sampler_room") .. ", %rdx")
  line("  movq $" .. sampler_needed .. ", %rcx")
  line("  leaq " .. work("wishes") .. ", %r8")
  line("  callq sampler_setup")
  line("  movq %rax, %rbx")
  stamp("  chance   ", "%rbx")
  -- }}}

  -- {{{ the driver's plan, and then the thinking
  line("  leaq " .. work("driver_plan") .. ", %r10")
  local function point_at(slot, instruction)
    line("  " .. instruction)
    line("  movq %rax, " .. plan_at[slot] .. "(%r10)")
  end
  point_at("k_encode", "leaq tokenizer_encode(%rip), %rax")
  point_at("k_decode", "leaq tokenizer_decode(%rip), %rax")
  point_at("k_forward", "leaq forward_conduct(%rip), %rax")
  point_at("k_choose", "leaq sampler_choose(%rip), %rax")
  point_at("k_say", "leaq say_bytes(%rip), %rax")
  point_at("conductor", "leaq " .. work("forward_plan") .. ", %rax")
  point_at("tokenizer", "leaq " .. work("tokenizer_plan") .. ", %rax")
  point_at("sampler", "leaq " .. work("sampler_plan") .. ", %rax")
  line("  movq %r15, " .. plan_at.say_context .. "(%r10)")
  point_at("text", "leaq " .. riding_at("text") .. ", %rax")
  line("  movq $" .. #BOOT_TEXT .. ", " .. plan_at.text_bytes .. "(%r10)")
  point_at("tokens", "leaq " .. work("tokens") .. ", %rax")
  point_at("spoken", "leaq " .. work("spoken") .. ", %rax")
  point_at("scores", "leaq " .. work("scores") .. ", %rax")
  point_at("chance", "leaq " .. work("chance") .. ", %rax")
  point_at("say_room", "leaq " .. work("say_room") .. ", %rax")
  line("  movq $" .. shape.vocabulary .. ", " .. plan_at.vocabulary .. "(%r10)")
  line("  movq $" .. shape.context .. ", " .. plan_at.context .. "(%r10)")
  line("  movq $-1, " .. plan_at.finish_token .. "(%r10)")
  line("  movq $" .. MAX_TOKENS .. ", " .. plan_at.max_tokens .. "(%r10)")

  -- the marks bracket the thinking, so a silence inside it is a silence with
  -- a known beginning
  mark("  spoke    <<")
  line("  leaq " .. work("driver_plan") .. ", %rdi")
  line("  callq drive")
  line("  movq %rax, %rbx")
  mark(">>\r\n")
  stamp("  reason   ", "%rbx")

  line("  leaq " .. work("driver_plan") .. ", %r10")
  line("  movq " .. plan_at.said .. "(%r10), %rbx")
  stamp("  words    ", "%rbx")
  line("  leaq " .. work("driver_plan") .. ", %r10")
  line("  movq " .. plan_at.position .. "(%r10), %rbx")
  stamp("  position ", "%rbx")

  line("  xorl %r12d, %r12d")
  line("fl_word:")
  line("  leaq " .. work("driver_plan") .. ", %r10")
  line("  movq " .. plan_at.said .. "(%r10), %rax")
  line("  cmpq %rax, %r12")
  line("  jge fl_words_done")
  line("  leaq " .. work("spoken") .. ", %rax")
  line("  movslq (%rax,%r12,4), %rbx")
  stamp("  word     ", "%rbx")
  line("  incq %r12")
  line("  jmp fl_word")
  line("fl_words_done:")

  mark("  finished\r\n")
  line("fl_halt:")
  line("  hlt")
  line("  jmp fl_halt")
  -- }}}

  local base = DIR .. "/tmp/shared-memory/payloads/first-light-x86_64"
  handle = io.open(base .. ".s", "w")
  handle:write(table.concat(body, "\n"), "\n")
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
