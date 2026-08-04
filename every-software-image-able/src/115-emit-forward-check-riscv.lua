-- 115-emit-forward-check-riscv.lua
--
-- A payload that runs a WHOLE FORWARD PASS on a bare RISC-V machine and says
-- how many of its scores matched what the first architecture produced. The
-- third architecture's half of what 109 does for the second.
--
-- For a general: the eleven pieces of arithmetic were already proved to agree
-- one at a time (111, 112, 113). This runs them in the order a thought
-- requires, driven by the conducting written in the same tongue, over a whole
-- small model -- and compares every score against the first architecture's as
-- an integer, so nothing rounds and "close" cannot happen.
--
-- WHY THIS IS A DIFFERENT CLAIM. A routine can be right alone and be handed
-- the wrong thing by the routine before it. The first architecture learned
-- exactly that: composing nine routines that each passed found a disagreement
-- of four parts in a thousand million, at the second token only, and the
-- defect was in the REFERENCE rather than the assembly.
--
-- WHY EVERYTHING IS IN ONE COUNTED PROGRAM. This assembler leaves a
-- relocation on a branch to a label in its own file, there is no linker to
-- answer it, and the extracted bytes then encode a branch to the
-- instruction's own address -- so every loop would spin forever, silently.
-- The word emitter (054) counts every distance itself, and it has to see
-- every instruction to do so.
--
-- WHERE THE WRITABLE MEMORY IS. On the stack, all of it. Firmware that
-- honours section rights maps the payload's code read-only, so a buffer in
-- the instructions faults on some machines and not others.

local M = {}

-- {{{ M.workspace(shape, steps, slot_count)
-- Where everything writable lives, as offsets from the stack pointer.
-- Computed rather than written down, for the same reason 109's is: offsets
-- counted by hand produce numbers that look like numbers.
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

  reserve("hex", 64)
  reserve("wide_got", 8)
  reserve("wide_want", 8)

  reserve("plan", slot_count * 8)
  reserve("layer_table", shape.layers * 9 * 8)

  -- what one run dirties, and what is therefore wiped before the next
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

  reserve("logits_plain", steps * shape.vocabulary * 4)
  reserve("logits_wide", steps * shape.vocabulary * 4)
  reserve("logits_miswired", steps * shape.vocabulary * 4)

  at.total = cursor
  -- rounded up to a whole page, purely for legibility in a report; the
  -- stack pointer is moved by a value built into a register here rather than
  -- by an immediate, so any size would assemble.
  at.reserved = cursor
  if at.reserved % 4096 ~= 0 then
    at.reserved = at.reserved + (4096 - at.reserved % 4096)
  end
  return at
end
-- }}}

-- {{{ local function label_for(name)
local function label_for(name)
  return "t_" .. name:gsub("%.", "_")
end
-- }}}

-- {{{ M.riscv64(options)
--
-- options: shape, tensors, words_of, prompt, recorded, scale_bits,
-- epsilon_bits, kernels (module), conductor (module), plan (module 056),
-- specification, float_bits, dir
function M.riscv64(options)
  local words = dofile((options.dir or ".") .. "/src/054-riscv-words.lua")
  local p = words.new()

  local shape = options.shape
  local plan_module = options.plan
  local at = plan_module.offsets()
  local steps = #options.prompt
  local work = M.workspace(shape, steps, #plan_module.SLOTS)

  -- {{{ the pool -- every block of numbers and every string, after the code
  local pool_order, strings, string_order = {}, {}, {}
  local function pooled_words(label, values, as_bits)
    pool_order[#pool_order + 1] = {
      label = label, values = values, as_bits = as_bits,
    }
    return label
  end
  local function pooled_text(text)
    if not strings[text] then
      strings[text] = "string" .. (#string_order + 1)
      string_order[#string_order + 1] = text
    end
    return strings[text]
  end
  -- }}}

  local function address(register, label)
    p:address(register, label, "s1")
  end

  -- {{{ local function work_address(register, offset)
  -- Somewhere in the workspace. An add-immediate reaches two thousand and
  -- forty-seven bytes on this architecture and the workspace is larger, so
  -- anything further out has its offset built into a register first. Written
  -- as one helper rather than decided per call site, because getting it
  -- wrong one way is an assembler error and the other way is a wrong address.
  local function work_address(register, offset)
    if register == "t6" then
      error("115-emit-forward-check-riscv: t6 is this helper's own scratch "
            .. "and cannot also be where the answer goes")
    end
    if offset == 0 then
      p:op("mv " .. register .. ", sp")
    elseif offset <= 2047 then
      p:op("addi " .. register .. ", sp, " .. offset)
    else
      p:load_constant("t6", offset)
      p:op("add " .. register .. ", sp, t6")
    end
  end
  -- }}}

  -- {{{ saying things
  local function say_text(text)
    address("a1", pooled_text(text))
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr ra, 0(t1)")
  end

  local converted = 0
  local function say_hex(register)
    converted = converted + 1
    local loop = "hex" .. converted
    p:op("mv t0, " .. register)
    work_address("t1", work.hex)
    p:op("addi t2, zero, 16")
    p:op("addi a6, zero, 39")
    p:label(loop)
    p:op("srli t3, t0, 60")
    p:op("slli t0, t0, 4")
    p:op("sltiu t4, t3, 10")
    p:op("xori t4, t4, 1")
    p:op("mul t4, t4, a6")
    p:op("addi t5, t3, 48")
    p:op("add t5, t5, t4")
    p:op("sh t5, 0(t1)")
    p:op("addi t1, t1, 2")
    p:op("addi t2, t2, -1")
    p:branch("bne", "t2", "zero", loop)
    p:op("sh zero, 0(t1)")
    work_address("a1", work.hex)
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr ra, 0(t1)")
  end
  -- }}}

  -- {{{ the prologue -- the anchor must be the very first instruction
  p:op("auipc s1, 0")
  p:op("mv s3, a1")                           -- the firmware's table
  p:op("ld s4, 64(s3)")                       -- its console
  p:load_constant("t0", work.reserved)
  p:op("sub sp, sp, t0")
  p:op("mv s5, zero")                         -- scores matched
  p:op("mv s6, zero")                         -- scores compared
  p:op("mv s7, zero")                         -- what this machine got
  p:op("mv s8, zero")                         -- what the first tongue said
  p:op("mv s9, zero")                         -- whether one has been captured
  p:op("mv s10, zero")                        -- the two matrix routines agreed
  p:op("mv s11, zero")                        -- and were compared
  p:op("mv s2, zero")                         -- scores the bent conducting moved
  -- }}}

  say_text("\r\na whole thought, in the third tongue\r\n")

  -- {{{ everything writable, cleared before anything reads it
  --
  -- Not tidiness. The first architecture's buffers come from an allocator
  -- that zeroes, so a value read before it is written gives a zero there and
  -- whatever the firmware left on the stack here. The two would disagree,
  -- the port would be blamed, and the real defect would be elsewhere
  -- entirely. Matching the other machine's starting state keeps a
  -- disagreement meaning what it is supposed to mean.
  local cleared = 0
  local function zero_region(from, to)
    cleared = cleared + 1
    local loop = "zero" .. cleared
    work_address("t0", from)
    p:load_constant("t1", (to - from) / 8)
    p:label(loop)
    p:op("sd zero, 0(t0)")
    p:op("addi t0, t0, 8")
    p:op("addi t1, t1, -1")
    p:branch("bne", "t1", "zero", loop)
  end

  zero_region(0, work.reserved)
  -- }}}

  -- {{{ the model and the recorded answers, laid in the pool
  local data_labels = {}
  for _, tensor in ipairs(options.tensors) do
    data_labels[tensor.name] = label_for(tensor.name)
    pooled_words(label_for(tensor.name), options.words_of(tensor.name), true)
  end
  for step = 1, steps do
    pooled_words("recorded" .. step, options.recorded[step], true)
  end
  -- }}}

  -- {{{ the plan, built where the conductor will look for it
  local function plan_slot(name)
    if at[name] == nil then
      error("115-emit-forward-check-riscv: the plan has no slot called '"
            .. tostring(name) .. "'")
    end
    return at[name] .. "(a0)"
  end

  work_address("a0", work.plan)

  local counts = {
    layers = shape.layers, hidden = shape.hidden, heads = shape.heads,
    head_width = shape.head_width, kv_heads = shape.kv_heads,
    heads_per_kv = shape.heads / shape.kv_heads,
    feedforward = shape.feedforward, vocabulary = shape.vocabulary,
    context = shape.context,
    kv_width = shape.kv_heads * shape.head_width,
    query_width = shape.heads * shape.head_width,
  }
  local count_order = {
    "layers", "hidden", "heads", "head_width", "kv_heads", "heads_per_kv",
    "feedforward", "vocabulary", "context", "kv_width", "query_width",
  }
  for _, name in ipairs(count_order) do
    local value = counts[name]
    if value ~= math.floor(value) or value < 0 then
      error("115-emit-forward-check-riscv: the count '" .. name .. "' is "
            .. tostring(value) .. ", which is not a whole number of anything")
    end
    p:load_constant("t0", value)
    p:op("sd t0, " .. plan_slot(name))
  end

  -- The two floating constants arrive as the exact patterns the first
  -- architecture's plan held. They are not recomputed here: a square root
  -- taken twice on two machines is a thing that can differ, and the whole
  -- point of the comparison is that nothing is allowed to.
  local function store_word(bits, slot_name)
    local value = bits
    if value > 2147483647 then value = value - 4294967296 end
    p:load_constant("t0", value)
    p:op("sw t0, " .. plan_slot(slot_name))
  end
  store_word(options.scale_bits, "scale")
  store_word(options.epsilon_bits, "epsilon")

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
    address("t0", pair[2])
    p:op("sd t0, " .. plan_slot(pair[1]))
  end

  for _, name in ipairs({ "token_embedding", "rotation", "output_norm", "output" }) do
    if data_labels[name] == nil then
      error("115-emit-forward-check-riscv: the model has no tensor called '"
            .. name .. "', which the conductor needs by slot rather than by "
            .. "search. A model shaped differently needs 034 extended.")
    end
    address("t0", data_labels[name])
    p:op("sd t0, " .. plan_slot(name))
  end

  for _, name in ipairs({ "cache_keys", "cache_values", "state", "normalised",
                          "query", "attended", "projected", "gate", "up",
                          "scores" }) do
    work_address("t0", work[name])
    p:op("sd t0, " .. plan_slot(name))
  end

  -- {{{ the per-layer table: nine tensors a layer, in the conductor's order
  work_address("a1", work.layer_table)
  p:op("sd a1, " .. plan_slot("layer_table"))
  for layer = 0, shape.layers - 1 do
    for which, tensor in ipairs(plan_module.LAYER_ORDER) do
      local name = "layer" .. layer .. "." .. tensor
      if data_labels[name] == nil then
        error("115-emit-forward-check-riscv: the model has no tensor called '"
              .. name .. "'. The conductor reads this row by position, so a "
              .. "missing one is a wrong answer rather than an error.")
      end
      address("t0", data_labels[name])
      p:op("sd t0, "
           .. ((layer * #plan_module.LAYER_ORDER) + (which - 1)) * 8 .. "(a1)")
    end
  end
  -- }}}
  -- }}}

  -- {{{ a whole pass per token, run three ways
  local function emit_run(routine, which_multiply, logits_at)
    zero_region(work.scratch_begin, work.scratch_end)
    work_address("a0", work.plan)
    address("t0", which_multiply)
    p:op("sd t0, " .. plan_slot("multiply"))

    for step, token in ipairs(options.prompt) do
      -- A mark per step, said BEFORE the step runs. Everything else this
      -- payload says comes at the end, so a machine that stops partway says
      -- nothing at all and the last mark is the only thing that narrows it.
      say_text(".")
      work_address("a0", work.plan)
      p:load_constant("a1", token)
      p:load_constant("a2", step - 1)
      work_address("a3", logits_at + (step - 1) * shape.vocabulary * 4)
      p:call(routine)
    end
  end

  emit_run("forward_conduct", "matrix_vector_plain", work.logits_plain)
  emit_run("forward_conduct", "matrix_vector_wide", work.logits_wide)
  -- The wrong one, over the same weights and the same prompt, with the plain
  -- matrix routine so the ONLY difference from the first run is the
  -- conducting.
  emit_run("forward_conduct_miswired", "matrix_vector_plain",
           work.logits_miswired)
  -- }}}

  -- {{{ the comparisons
  local compared = 0

  -- against the first architecture's scores, as integers, loaded WITHOUT
  -- sign extension so a pattern with its top bit set is reported as the
  -- thirty-two bits it is.
  local function compare_against_record(step)
    compared = compared + 1
    local loop = "cmp" .. compared
    work_address("t0", work.logits_plain + (step - 1) * shape.vocabulary * 4)
    address("t1", "recorded" .. step)
    p:load_constant("t2", shape.vocabulary)
    p:label(loop)
    p:op("lwu t3, 0(t0)")
    p:op("lwu t4, 0(t1)")
    p:op("addi s6, s6, 1")
    p:branch("beq", "t3", "t4", loop .. "same")
    -- the first disagreement, kept whole, and only the first. A count says
    -- nothing about WHETHER the port rounds differently somewhere or is
    -- plainly wrong, and those want opposite responses.
    p:branch("bne", "s9", "zero", loop .. "no")
    p:op("mv s7, t3")
    p:op("mv s8, t4")
    p:op("addi s9, zero, 1")
    p:jump(loop .. "no")
    p:label(loop .. "same")
    p:op("addi s5, s5, 1")
    p:label(loop .. "no")
    p:op("addi t0, t0, 4")
    p:op("addi t1, t1, 4")
    p:op("addi t2, t2, -1")
    p:branch("bne", "t2", "zero", loop)
  end

  local function compare_two_runs(step, other_at, agreed, total, keep_first)
    compared = compared + 1
    local loop = "cmp" .. compared
    work_address("t0", work.logits_plain + (step - 1) * shape.vocabulary * 4)
    work_address("t1", other_at + (step - 1) * shape.vocabulary * 4)
    p:load_constant("t2", shape.vocabulary)
    p:label(loop)
    p:op("lwu t3, 0(t0)")
    p:op("lwu t4, 0(t1)")
    if total then p:op("addi " .. total .. ", " .. total .. ", 1") end
    p:branch("beq", "t3", "t4", loop .. "same")
    if keep_first then
      work_address("a2", work.wide_got)
      p:op("ld a3, 0(a2)")
      p:branch("bne", "a3", "zero", loop .. "no")
      p:op("sd t3, 0(a2)")
      work_address("a2", work.wide_want)
      p:op("sd t4, 0(a2)")
    else
      p:op("addi s2, s2, 1")
    end
    p:jump(loop .. "no")
    p:label(loop .. "same")
    if agreed then p:op("addi " .. agreed .. ", " .. agreed .. ", 1") end
    p:label(loop .. "no")
    p:op("addi t0, t0, 4")
    p:op("addi t1, t1, 4")
    p:op("addi t2, t2, -1")
    p:branch("bne", "t2", "zero", loop)
  end

  for step = 1, steps do compare_against_record(step) end
  for step = 1, steps do
    compare_two_runs(step, work.logits_wide, "s10", "s11", true)
  end
  -- And the deliberately wrong conducting, which has to come out different.
  -- A zero here is not a passing test: it would mean every score survived a
  -- conducting known to be wrong, and therefore that this whole payload is
  -- comparing something against itself.
  for step = 1, steps do
    compare_two_runs(step, work.logits_miswired, nil, nil, false)
  end
  -- }}}

  say_text("pass conducted\r\n  matched ")
  say_hex("s5")
  say_text("\r\n  of ")
  say_hex("s6")
  say_text("\r\n  wide ")
  say_hex("s10")
  say_text("\r\n  wof ")
  say_hex("s11")
  say_text("\r\n  got ")
  say_hex("s7")
  say_text("\r\n  want ")
  say_hex("s8")
  say_text("\r\n  bent ")
  say_hex("s2")
  say_text("\r\n")

  p:label("halted")
  p:op("wfi")
  p:jump("halted")

  -- {{{ the routines and the conductings, past the halt
  -- They are only ever reached by a call, so nothing can fall into them.
  options.kernels.emit(p, nil, {
    specification = options.specification,
    float_bits = options.float_bits,
  })
  options.conductor.emit(p, plan_module)
  options.conductor.emit(p, plan_module, {
    name = "forward_conduct_miswired", miswire = true,
  })
  -- }}}

  -- {{{ the pool -- numbers, then strings
  for _, block in ipairs(pool_order) do
    p:align(16)
    p:label(block.label)
    local distinct, count = {}, 0
    for _, value in ipairs(block.values) do
      local pattern = block.as_bits and value or options.float_bits.of(value)
      p:word(pattern)
      if not distinct[pattern] then
        distinct[pattern] = true
        count = count + 1
      end
    end
    -- REFUSE A BLOCK THAT IS NOT VARIED, the same guard 101 and 112 carry.
    if #block.values > 8 and count < #block.values * 0.9 then
      error(string.format(
        "115-emit-forward-check-riscv: '%s' would carry %d numbers of which "
        .. "only %d are distinct. That is not a tensor, it is one number "
        .. "repeated, and a machine given it will compute the right answer "
        .. "over the wrong weights and look broken.",
        block.label, #block.values, count))
    end
  end
  for _, text in ipairs(string_order) do
    p:align(4)
    p:label(strings[text])
    p:shorts(text)
  end
  -- }}}

  return p:resolve()
end
-- }}}

return M
