-- 109-emit-forward-check.lua
--
-- A payload that runs a WHOLE FORWARD PASS on a bare ARM machine and says
-- how many of its scores matched what the first architecture produced. The
-- other half of issue 401's remaining gap.
--
-- For a general: the ten pieces of arithmetic were already proved to agree
-- one at a time (100, 101). This runs them in the order a thought requires,
-- driven by the conducting written in the same tongue, over a whole small
-- model -- and compares every score against the first architecture's, as
-- integers, so nothing rounds and "close" cannot happen.
--
-- WHY THIS IS A DIFFERENT CLAIM FROM 101. A kernel can be right alone and be
-- handed the wrong thing by the kernel before it. The first architecture
-- learned exactly that: composing nine kernels that each passed found a
-- disagreement of four parts in a thousand million, at the second token
-- only, and the defect was in the REFERENCE rather than the assembly. No
-- amount of testing pieces separately reaches that.
--
-- WHAT THE MACHINE CARRIES. The whole model -- every weight of it -- as raw
-- words, plus the scores the first architecture gave for a fixed prompt.
-- Nothing is recomputed on the ARM side to compare against, because a
-- payload that computed its own expected answers would be comparing an
-- implementation against itself and would pass whatever it did.
--
-- WHY THE WEIGHTS ARE COPIED AS BITS RATHER THAN CONVERTED. They are read
-- straight out of the packed model as thirty-two bit words and written into
-- the payload as those same words. No number is ever turned into text and
-- back, so there is no conversion in the path at all -- which is the defect
-- 107 exists because of, avoided here by not doing the thing.
--
-- WHERE THE WRITABLE MEMORY IS. On the stack, all of it. Firmware that
-- honours section rights maps the payload's code read-only, so a buffer in
-- .text faults on some machines and not others -- a lesson this project has
-- paid for in 033 and again in 101. Nothing here writes inside the payload.

local M = {}

-- {{{ M.workspace(shape, steps, slot_count)
-- Where everything writable lives, as offsets from the stack pointer.
--
-- Computed rather than written down. The alternative is a page of constants
-- that have to be re-added by hand every time the model's shape changes, and
-- offsets counted by hand producing numbers that look like numbers is
-- already on this project's list of things that have cost it a day.
--
-- Everything is padded to sixteen bytes so that a region's start and its
-- length are both something the stack pointer and a store-pair are happy
-- with, and so the two markers around the scratch can be zeroed as one run.
function M.workspace(shape, steps, slot_count)
  local at, cursor = {}, 0

  local function reserve(name, bytes)
    at[name] = cursor
    cursor = cursor + bytes
    if cursor % 16 ~= 0 then cursor = cursor + (16 - cursor % 16) end
  end

  local query_width = shape.heads * shape.head_width
  local kv_width = shape.kv_heads * shape.head_width
  local cache_numbers = shape.layers * shape.context * kv_width

  -- what says things: the hex buffer the console writes from, the two words
  -- that keep the first disagreement between the two matrix kernels, and the
  -- tally of how loudly the deliberately wrong conducting disagreed. These
  -- live in memory rather than registers because every register a called
  -- routine must give back is already holding a counter.
  reserve("hex", 64)
  reserve("wide_got", 8)
  reserve("wide_want", 8)
  reserve("bent", 8)

  -- what the conductor is told, and never changes once built
  reserve("plan", slot_count * 8)
  reserve("layer_table", shape.layers * 9 * 8)

  -- what one run dirties, and what is therefore wiped before the second one
  at.scratch_begin = cursor
  reserve("state", shape.hidden * 4)
  reserve("normalised", shape.hidden * 4)
  reserve("query", query_width * 4)
  reserve("attended", query_width * 4)
  reserve("projected", shape.hidden * 4)
  reserve("gate", shape.feedforward * 4)
  reserve("up", shape.feedforward * 4)
  reserve("scores", shape.context * 4)
  reserve("cache_keys", cache_numbers * 4)
  reserve("cache_values", cache_numbers * 4)
  at.scratch_end = cursor

  -- the three answers, kept apart so they can be compared against each
  -- other: the two matrix kernels, and the deliberately mis-wired
  -- conducting that has to come out different from both.
  reserve("logits_plain", steps * shape.vocabulary * 4)
  reserve("logits_wide", steps * shape.vocabulary * 4)
  reserve("logits_miswired", steps * shape.vocabulary * 4)

  at.total = cursor

  -- WHAT IS ACTUALLY TAKEN OFF THE STACK POINTER, rounded up to a whole
  -- page. The instruction that moves the stack pointer takes a twelve-bit
  -- number, or a twelve-bit number shifted up by twelve and nothing in
  -- between -- so seven thousand three hundred and seventy-six is not a
  -- number it can express and eight thousand one hundred and ninety-two is.
  -- Rounding here rather than at the call site keeps the one place that
  -- knows the size the one place that decides it.
  at.reserved = cursor
  if at.reserved % 4096 ~= 0 then
    at.reserved = at.reserved + (4096 - at.reserved % 4096)
  end

  return at
end
-- }}}

-- {{{ local function label_for(name)
-- A tensor's name as an assembler label. Names carry a dot to say which
-- layer they belong to, and a label wants none.
local function label_for(name)
  return "t_" .. name:gsub("%.", "_")
end
-- }}}

-- {{{ M.aarch64(options)
--
-- options:
--   shape          the model's counts
--   tensors        ordered { name = , count = }, from 034
--   words_of       function(name) -> array of thirty-two bit patterns
--   prompt         the tokens to run, in order
--   recorded       per step, an array of the first tongue's score patterns
--   scale_bits     the attention scale, as the first tongue's plan holds it
--   epsilon_bits   the normalisation constant, likewise
--   kernels        the second tongue's arithmetic, as assembler text
--   conductor      the second tongue's conducting, as assembler text
--   plan           the module that describes the plan's layout (056)
function M.aarch64(options)
  local shape = options.shape
  local plan_module = options.plan
  local at = plan_module.offsets()
  local steps = #options.prompt
  local work = M.workspace(shape, steps, #plan_module.SLOTS)

  local out = {}
  local function line(text) out[#out + 1] = text end

  -- {{{ local function lay_down(label, words)
  -- A block of numbers into the payload, and A REFUSAL TO WRITE ONE THAT IS
  -- NOT VARIED.
  --
  -- The same guard 101 carries, and for the same reason: a payload was once
  -- built holding two hundred and fifty-six numbers of which three were
  -- distinct, and the machine that ran it did correct arithmetic over wrong
  -- data and was very nearly recorded as a broken port. However the numbers
  -- get made, and whatever breaks next, data that all looks the same never
  -- reaches a machine again.
  --
  -- Small blocks are exempt because a short run can legitimately repeat, and
  -- refusing that would be refusing arithmetic.
  local function lay_down(label, words)
    line("  .balign 16")
    line(label .. ":")

    local distinct, count = {}, 0
    local row = {}
    for index, word in ipairs(words) do
      local text = string.format("0x%08x", word)
      if not distinct[text] then
        distinct[text] = true
        count = count + 1
      end
      row[#row + 1] = text
      -- eight to a line: the same bytes, a tenth of the text, and an
      -- assembler that finishes in a reasonable time on ninety kilobytes of
      -- weights.
      if #row == 8 or index == #words then
        line("  .word " .. table.concat(row, ", "))
        row = {}
      end
    end

    if #words > 8 and count < #words * 0.9 then
      error(string.format(
        "109-emit-forward-check: '%s' would carry %d numbers of which only "
        .. "%d are distinct. That is not a tensor, it is one number "
        .. "repeated, and a machine given it will compute the right answer "
        .. "over the wrong weights and look broken.",
        label, #words, count))
    end
  end
  -- }}}

  -- THE FIRST INSTRUCTION MUST BE OURS. Firmware enters at offset zero of
  -- the code, so whatever is emitted first is what runs. Emitting the
  -- kernels first once meant the machine entered the matrix product with the
  -- firmware's registers as arguments, returned immediately because they
  -- happened to mean "no rows", and handed control back to firmware that
  -- carried on booting to its own shell. Nothing failed and nothing was said.
  line("  .text")
  line("  .globl _start")
  line("_start:")
  line("  b start_here")

  -- {{{ the arithmetic and the conducting, with their exports stripped
  --
  -- A call to an EXPORTED name is a note for a linker, even from an
  -- assembler that would happily resolve a local one itself. There is no
  -- linker here, so extracting the raw bytes drops the note and leaves the
  -- branch offset at zero -- and a call whose offset is zero is a call to
  -- ITSELF. This is the project's oldest trap and it has now appeared four
  -- times; the rule covering all of them is in notes/023.
  --
  -- It applies to the conductor exactly as it applies to the kernels, and
  -- with an extra edge: the payload takes the ADDRESS of every kernel to
  -- fill the plan, and an `adr` to a global symbol leaves a relocation just
  -- as a call to one does.
  local function strip(text)
    return (text:gsub("%s*%.section%s+%.note%.GNU%-stack[^\n]*\n", "\n")
                :gsub("^%s*%.text%s*\n", "")
                :gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
                :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n"))
  end

  line(strip(options.kernels))
  line(strip(options.conductor))
  line(strip(options.conductor_miswired))
  -- }}}

  line("start_here:")
  line("  sub sp, sp, #" .. work.reserved)
  line("  mov x19, x1")                     -- the firmware's table
  line("  ldr x20, [x19, #64]")             -- its console
  line("  mov x21, sp")                     -- everything writable, from here
  line("  mov x22, xzr")                    -- scores matched
  line("  mov x23, xzr")                    -- scores compared
  line("  mov x24, xzr")                    -- the two matrix kernels agreed
  line("  mov x25, xzr")                    -- and were compared
  line("  mov x26, xzr")                    -- what this machine got
  line("  mov x27, xzr")                    -- what the first tongue said
  line("  mov x28, xzr")                    -- whether one has been captured

  -- {{{ addressing the workspace
  --
  -- An add-immediate reaches four thousand and ninety-five bytes and the
  -- workspace is larger than that, so anything further out has its offset
  -- built into a register first. Written as one helper rather than decided
  -- per call site, because getting it wrong once produces an assembler error
  -- and getting it wrong the other way produces a wrong address.
  local function address_of(register, offset)
    if offset == 0 then
      line("  mov " .. register .. ", x21")
    elseif offset <= 4095 then
      line("  add " .. register .. ", x21, #" .. offset)
    else
      line(string.format("  movz x9, #0x%x", offset % 0x10000))
      if offset >= 0x10000 then
        line(string.format("  movk x9, #0x%x, lsl #16",
                           math.floor(offset / 0x10000) % 0x10000))
      end
      line("  add " .. register .. ", x21, x9")
    end
  end
  -- }}}

  -- {{{ saying things
  local said = 0
  local function say_text(text)
    said = said + 1
    local skip, label = "fskip" .. said, "ftext" .. said
    line("  b " .. skip)
    line(label .. ":")
    for index = 1, #text do line("  .short " .. text:byte(index)) end
    line("  .short 0")
    line("  .balign 4")
    line(skip .. ":")
    line("  adr x1, " .. label)
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end

  local converted = 0
  local function say_hex(register)
    converted = converted + 1
    local loop, digit, done = "fhex" .. converted, "fdig" .. converted,
                              "fdone" .. converted
    line("  mov x9, " .. register)
    address_of("x10", work.hex)
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
    address_of("x1", work.hex)
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end
  -- }}}

  say_text("\r\na whole thought, in the second tongue\r\n")

  -- {{{ the model, the prompt's answers, laid inline
  --
  -- Every weight the model holds, then the scores the first architecture
  -- produced for each step of the prompt. All as raw words: nothing is
  -- parsed, nothing rounds, and the comparison later is between integers.
  local data_labels = {}
  line("  b fdata_done")

  for _, tensor in ipairs(options.tensors) do
    data_labels[tensor.name] = label_for(tensor.name)
    lay_down(label_for(tensor.name), options.words_of(tensor.name))
  end

  for step = 1, steps do
    lay_down("recorded" .. step, options.recorded[step])
  end

  line("fdata_done:")
  -- }}}

  -- {{{ everything writable, cleared before anything reads it
  --
  -- Not tidiness. The first architecture's buffers come from an allocator
  -- that zeroes, so if some value in the engine is ever read before it is
  -- written, that machine reads a zero and this one would read whatever the
  -- firmware left on the stack. The two would then disagree, the port would
  -- be blamed, and the actual defect -- a read before a write -- would be
  -- somewhere else entirely. Matching the other machine's starting state
  -- keeps a disagreement meaning what it is supposed to mean.
  local function zero_region(from, to, tag)
    local words = (to - from) / 8
    address_of("x10", from)
    line(string.format("  movz x11, #0x%x", words % 0x10000))
    if words >= 0x10000 then
      line(string.format("  movk x11, #0x%x, lsl #16",
                         math.floor(words / 0x10000) % 0x10000))
    end
    line("fzero" .. tag .. ":")
    line("  str xzr, [x10], #8")
    line("  subs x11, x11, #1")
    line("  b.ne fzero" .. tag)
  end

  zero_region(0, work.reserved, "all")
  -- }}}

  -- {{{ the plan, built where the conductor will look for it
  --
  -- The conductor reaches nothing by name. It asks only "what is at this
  -- offset of the plan", which is why the same instructions run here and in
  -- a hosted library, and why this block is the only place that knows what a
  -- kernel is called.
  local function plan_slot(name)
    if at[name] == nil then
      error("109-emit-forward-check: the plan has no slot called '"
            .. tostring(name) .. "'")
    end
    return "[x0, #" .. at[name] .. "]"
  end

  address_of("x0", work.plan)

  local query_width = shape.heads * shape.head_width
  local kv_width = shape.kv_heads * shape.head_width

  local counts = {
    layers = shape.layers,
    hidden = shape.hidden,
    heads = shape.heads,
    head_width = shape.head_width,
    kv_heads = shape.kv_heads,
    heads_per_kv = shape.heads / shape.kv_heads,
    feedforward = shape.feedforward,
    vocabulary = shape.vocabulary,
    context = shape.context,
    kv_width = kv_width,
    query_width = query_width,
  }
  -- ordered, so the emitted payload is the same text every time rather than
  -- whatever order a hash happened to hand back.
  local count_order = {
    "layers", "hidden", "heads", "head_width", "kv_heads", "heads_per_kv",
    "feedforward", "vocabulary", "context", "kv_width", "query_width",
  }
  for _, name in ipairs(count_order) do
    local value = counts[name]
    if value ~= math.floor(value) or value < 0 or value >= 0x10000 then
      error("109-emit-forward-check: the count '" .. name .. "' is "
            .. tostring(value) .. ", which does not fit the single "
            .. "move-immediate this builds it with. A larger model needs "
            .. "the two-part build the constants use.")
    end
    line(string.format("  movz x10, #0x%x", value))
    line("  str x10, " .. plan_slot(name))
  end

  -- The two floating constants arrive as the exact patterns the first
  -- architecture's plan held. They are not recomputed here: a square root
  -- taken twice on two machines is a thing that can differ, and the whole
  -- point of the comparison is that nothing is allowed to.
  local function store_word(bits, slot_name)
    line(string.format("  movz w10, #0x%x", bits % 0x10000))
    line(string.format("  movk w10, #0x%x, lsl #16",
                       math.floor(bits / 0x10000) % 0x10000))
    line("  str w10, " .. plan_slot(slot_name))
  end
  store_word(options.scale_bits, "scale")
  store_word(options.epsilon_bits, "epsilon")

  -- the kernels, as addresses. `multiply` is filled per run, below.
  local kernel_slots = {
    { "k_rms_normalise", "rms_normalise" },
    { "k_rotate", "rotate" },
    { "k_attention_scores", "attention_scores" },
    { "k_softmax", "softmax" },
    { "k_attention_mix", "attention_mix" },
    { "k_swiglu", "swiglu" },
    { "k_add_into", "add_into" },
  }
  for _, pair in ipairs(kernel_slots) do
    line("  adr x10, " .. pair[2])
    line("  str x10, " .. plan_slot(pair[1]))
  end

  -- the fixed tensors, as addresses into the block laid down above
  for _, name in ipairs({ "token_embedding", "rotation", "output_norm", "output" }) do
    if data_labels[name] == nil then
      error("109-emit-forward-check: the model has no tensor called '"
            .. name .. "', which the conductor needs by slot rather than by "
            .. "search. A model shaped differently needs 034 extended.")
    end
    line("  adr x10, " .. data_labels[name])
    line("  str x10, " .. plan_slot(name))
  end

  -- the cache and the scratch, as places on the stack
  for _, name in ipairs({ "cache_keys", "cache_values", "state", "normalised",
                          "query", "attended", "projected", "gate", "up",
                          "scores" }) do
    address_of("x10", work[name])
    line("  str x10, " .. plan_slot(name))
  end

  -- {{{ the per-layer table: nine tensors a layer, in the conductor's order
  address_of("x11", work.layer_table)
  line("  str x11, " .. plan_slot("layer_table"))
  for layer = 0, shape.layers - 1 do
    for which, tensor in ipairs(plan_module.LAYER_ORDER) do
      local name = "layer" .. layer .. "." .. tensor
      if data_labels[name] == nil then
        error("109-emit-forward-check: the model has no tensor called '"
              .. name .. "'. The conductor reads this row by position, so a "
              .. "missing one is a wrong answer rather than an error.")
      end
      line("  adr x10, " .. data_labels[name])
      line("  str x10, [x11, #"
           .. ((layer * #plan_module.LAYER_ORDER) + (which - 1)) * 8 .. "]")
    end
  end
  -- }}}
  -- }}}

  -- {{{ a whole pass per token, run twice -- once each way through the matrix
  --
  -- Running the whole prompt with the plain kernel and again with the one
  -- that reads four numbers at a time, and requiring the two to agree, is a
  -- far harder test of the wide kernel than any single call: a difference of
  -- one bit anywhere compounds through every tensor and every layer before
  -- it reaches a score.
  local function emit_run(routine, which_multiply, logits_at, tag)
    -- the scratch and the cache, back to how the first run found them. The
    -- cache in particular carries every position this prompt has already
    -- seen, so a second run over a dirty one is not the same question.
    zero_region(work.scratch_begin, work.scratch_end, tag)

    address_of("x0", work.plan)
    line("  adr x10, " .. which_multiply)
    line("  str x10, " .. plan_slot("multiply"))

    for step, token in ipairs(options.prompt) do
      -- A mark per step, said BEFORE the step runs. Everything else this
      -- payload says comes at the end, so a machine that stops partway says
      -- nothing at all, and the last mark is the only thing that narrows it.
      say_text(".")
      address_of("x0", work.plan)
      line(string.format("  movz x1, #0x%x", token))
      line(string.format("  movz x2, #0x%x", step - 1))
      address_of("x3", logits_at + (step - 1) * shape.vocabulary * 4)
      line("  bl " .. routine)
    end
  end

  emit_run("forward_conduct", "matrix_vector_plain", work.logits_plain, "plain")
  emit_run("forward_conduct", "matrix_vector_wide", work.logits_wide, "wide")
  -- The wrong one, over the same weights and the same prompt, with the plain
  -- matrix kernel so that the ONLY difference between it and the first run
  -- is the conducting.
  emit_run("forward_conduct_miswired", "matrix_vector_plain",
           work.logits_miswired, "bent")
  -- }}}

  -- {{{ every score against the first architecture's, as integers
  for step = 1, steps do
    address_of("x5", work.logits_plain + (step - 1) * shape.vocabulary * 4)
    line("  adr x6, recorded" .. step)
    line("  mov w7, #" .. shape.vocabulary)
    local loop = "fcmp" .. step
    line(loop .. ":")
    line("  ldr w8, [x5], #4")               -- what this machine got
    line("  ldr w9, [x6], #4")               -- what the first tongue said
    line("  add x23, x23, #1")
    line("  cmp w8, w9")
    line("  b.eq " .. loop .. "same")
    -- The first disagreement, kept whole, and only the first. A count says
    -- nothing about WHETHER the port rounds differently somewhere or is
    -- plainly wrong, and those want opposite responses. So the pair is
    -- carried home and the host works out the distance, rather than
    -- floating-point arithmetic being done here to answer a question about
    -- floating-point arithmetic.
    line("  cbnz x28, " .. loop .. "no")
    line("  mov x26, x8")
    line("  mov x27, x9")
    line("  mov x28, #1")
    line("  b " .. loop .. "no")
    line(loop .. "same:")
    line("  add x22, x22, #1")
    line(loop .. "no:")
    line("  subs w7, w7, #1")
    line("  b.ne " .. loop)
  end
  -- }}}

  -- {{{ and the two matrix kernels against each other, over the whole pass
  for step = 1, steps do
    address_of("x5", work.logits_plain + (step - 1) * shape.vocabulary * 4)
    address_of("x6", work.logits_wide + (step - 1) * shape.vocabulary * 4)
    line("  mov w7, #" .. shape.vocabulary)
    local loop = "fwide" .. step
    line(loop .. ":")
    line("  ldr w8, [x5], #4")
    line("  ldr w9, [x6], #4")
    line("  add x25, x25, #1")
    line("  cmp w8, w9")
    line("  b.eq " .. loop .. "same")
    -- kept in memory rather than a register, because every callee-saved one
    -- is already holding something and this is the rarer report.
    address_of("x13", work.wide_got)
    line("  ldr x14, [x13]")
    line("  cbnz x14, " .. loop .. "no")
    line("  str x8, [x13]")
    address_of("x13", work.wide_want)
    line("  str x9, [x13]")
    line("  b " .. loop .. "no")
    line(loop .. "same:")
    line("  add x24, x24, #1")
    line(loop .. "no:")
    line("  subs w7, w7, #1")
    line("  b.ne " .. loop)
  end
  -- }}}

  -- {{{ and the deliberately wrong conducting, which has to come out different
  --
  -- This is the direction the test would otherwise never be pushed in. Every
  -- other number here says "the same thing came out", and a comparison that
  -- can only ever report agreement proves nothing about whether it would
  -- notice a disagreement. So one run is bent on purpose -- the feedforward's
  -- two projections handed to each other -- and the count of how many scores
  -- moved is reported alongside the ones that did not.
  --
  -- A zero here is not a passing test. It means every score survived a
  -- conducting known to be wrong, which would mean this whole payload is
  -- comparing something to itself.
  for step = 1, steps do
    address_of("x5", work.logits_plain + (step - 1) * shape.vocabulary * 4)
    address_of("x6", work.logits_miswired + (step - 1) * shape.vocabulary * 4)
    line("  mov w7, #" .. shape.vocabulary)
    local loop = "fbent" .. step
    line(loop .. ":")
    line("  ldr w8, [x5], #4")
    line("  ldr w9, [x6], #4")
    line("  cmp w8, w9")
    line("  b.eq " .. loop .. "no")
    address_of("x13", work.bent)
    line("  ldr x14, [x13]")
    line("  add x14, x14, #1")
    line("  str x14, [x13]")
    line(loop .. "no:")
    line("  subs w7, w7, #1")
    line("  b.ne " .. loop)
  end
  -- }}}

  say_text("pass conducted\r\n  matched ")
  say_hex("x22")
  say_text("\r\n  of ")
  say_hex("x23")
  say_text("\r\n  wide ")
  say_hex("x24")
  say_text("\r\n  wof ")
  say_hex("x25")
  say_text("\r\n  got ")
  say_hex("x26")
  say_text("\r\n  want ")
  say_hex("x27")
  -- READ AFTER THE LABEL IS SAID, NOT BEFORE. Saying anything is a call
  -- into the firmware's console, and the convention lets a called routine
  -- destroy x9 through x15. Loading these two before the label meant the
  -- firmware overwrote them on its way out, and the payload then reported
  -- whatever it had left behind -- eight, in the run that found this, with
  -- nothing disagreeing at all. It looked exactly like a real value.
  --
  -- The counters above are safe from the same thing only because x19
  -- through x28 are the registers a called routine must give back, which is
  -- also why the firmware's own table survives in x19 across all of this.
  say_text("\r\n  wgot ")
  address_of("x13", work.wide_got)
  line("  ldr x13, [x13]")
  say_hex("x13")
  say_text("\r\n  wwant ")
  address_of("x13", work.wide_want)
  line("  ldr x13, [x13]")
  say_hex("x13")
  say_text("\r\n  bent ")
  address_of("x13", work.bent)
  line("  ldr x13, [x13]")
  say_hex("x13")
  say_text("\r\n")

  line("fhalt:")
  line("  wfi")
  line("  b fhalt")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
