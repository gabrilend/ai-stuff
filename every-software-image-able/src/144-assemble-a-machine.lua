#!/usr/bin/env luajit
-- 144-assemble-a-machine.lua
--
-- Everything a bare computer needs, emitted as one program: the work area
-- divided, the engine set up, the tokenizer prepared, the sampler readied, and
-- the driver's loop entered. Issue `502`, and it is what `107` built.
--
-- For a general: this writes out the actual instructions a machine runs when it
-- is switched on with nothing else on the computer. Hand it a model and what
-- the machine should be told, and it hands back the program, and the data that
-- program carries.
--
-- WHY IT IS A FILE OF ITS OWN, AS OF 2026-08-22. It lived inside `140`, which
-- is a test. So the only way to obtain a whole machine was to run a test, and
-- the image builder -- whose entire purpose is producing one -- could not reach
-- it. The builder invented its own arrangement instead, and that arrangement
-- was correct, carefully commented, checked by its own test, and described a
-- machine nobody built.
--
-- A test that builds its own version of the thing is testing its own version.
-- `140` calls this and checks what comes back; the builder calls the same
-- thing. One dataflow, and the machine on it is the machine that ships.
--
-- WHAT IT DELIBERATELY DOES NOT DO. It does not assemble, wrap or write
-- anything. It returns text and bytes. Turning text into instructions is
-- clang's business, the executable envelope is `029`'s, the medium is `141`'s --
-- and keeping them apart is what lets a test read the assembly while a builder
-- takes the image.

local M = {}

-- {{{ M.KERNELS -- the arithmetic the conducting calls, in the order it expects
-- Named here rather than where they are emitted, because the plan the
-- conducting reads is a table of addresses and the order IS the meaning.
M.KERNELS = { "matrix_vector_plain", "rms_normalise", "rotate",
              "attention_scores", "softmax", "attention_mix",
              "swiglu", "add_into" }
-- }}}

-- {{{ M.assemble(options)
--
-- options: dir         the project root
--          blob        the packed model, as bytes
--          text        what the machine wakes holding, as token numbers
--          max_tokens  how many words it may say before stopping
--          settings    { temperature = n }
--          randomness  the carried numbers, as an array of integers
--
-- Returns { assembly, riding, work_bytes, riding_at, shape } or nil and why.
function M.assemble(options)
  local DIR = options.dir
  local blob = options.blob
  local BOOT_TEXT = options.text
  local MAX_TOKENS = options.max_tokens
  local SETTINGS = options.settings
  local carried = options.randomness

  local format     = dofile(DIR .. "/src/024-blob-format.lua")
  local conductor  = dofile(DIR .. "/src/056-emit-conductor.lua")
  local tokenizer  = dofile(DIR .. "/src/059-emit-tokenizer.lua")
  local sampler    = dofile(DIR .. "/src/057-emit-sampler.lua")
  local layout     = dofile(DIR .. "/src/133-lay-out-memory.lua")
  local preparer   = dofile(DIR .. "/src/137-prepare-the-tokenizer.lua")
  local driver     = dofile(DIR .. "/src/139-the-driver.lua")
  local float_bits = dofile(DIR .. "/src/107-float-bits.lua")
  local rides      = dofile(DIR .. "/src/143-what-rides-inside.lua")
  local envelope   = dofile(DIR .. "/src/029-wrap-uefi.lua")
  local emit       = dofile(DIR .. "/src/043-emit-kernels.lua")
  local finder     = dofile(DIR .. "/src/131-find-tensors.lua")
  local filler     = dofile(DIR .. "/src/135-fill-the-plan.lua")
  local specification = dofile(DIR .. "/src/047-reference-exp.lua")

  -- {{{ local function whole_engine()
  -- Every piece of the machine's arithmetic and machinery, as one run of
  -- assembly, in the order the pieces call each other.
  --
  -- BACK INTO EXECUTABLE MEMORY BETWEEN EACH PIECE, for the reason `136`
  -- records: the kernel emitter ends by switching to the section that marks the
  -- stack non-executable, and anything appended after it lands there rather
  -- than in the code -- a library that builds without a murmur and faults when
  -- called.
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
  M.whole_engine = whole_engine
  -- }}}

  -- {{{ what the model says about itself
  local function u32(bytes, at)
    local a, b, c, d = bytes:byte(at + 1, at + 4)
    return a + b * 256 + c * 65536 + d * 16777216
  end
  local function u64(bytes, at)
    return u32(bytes, at) + u32(bytes, at + 4) * 4294967296
  end

  local header_at = preparer.header_offsets(format)
  local shape = {
    layers = u32(blob, header_at.layers),
    hidden = u32(blob, header_at.hidden),
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

  -- How much room the tokenizer's prepared tables need depends on how long the
  -- words are, so the word list is walked to add them up. Read out of the model
  -- rather than passed in, because a caller that had to know this would have to
  -- open the model itself, and then there would be two readers of one format.
  local text_bytes_total, walker = 0, u64(blob, header_at.token_table)
  for _ = 1, token_count do
    local length = blob:byte(walker + 1)
    text_bytes_total = text_bytes_total + length
    walker = walker + 1 + length
  end
  -- }}}

  -- {{{ how much room each part of the machine needs
  local _, engine_needed = layout.expected(shape)
  local _, tokenizer_needed = preparer.expected(token_count, merge_count,
                                                text_bytes_total)
  local _, sampler_needed = driver.sampler_room(shape.vocabulary)
  local kernel_names = M.KERNELS
  local geometry = { blob_offset = envelope.BLOB_OFFSET }
  -- }}}

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

  return {
    assembly = table.concat(body, "\n") .. "\n",
    riding = riding,
    riding_at = APPEND,
    work_bytes = WORK_BYTES,
    shape = shape,
    tensor_count = tensor_count,
    engine_needed = engine_needed,
    tokenizer_needed = tokenizer_needed,
    sampler_needed = sampler_needed,
  }
end
-- }}}

return M
