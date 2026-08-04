-- 121-emit-sampler-check-riscv.lua
--
-- A payload that draws on a bare RISC-V machine and says whether it chose the
-- same words the first architecture chose. The third architecture's half of
-- what 118 does for the second.
--
-- For a general: a score off in its last bit stays off in its last bit. A
-- CHOICE that flips once joins the conversation, and everything after it is
-- said in a different conversation. So this checks that across many hundreds
-- of draws, under every setting the sampler has, both machines picked the
-- same word every time and recorded the same chance for it, bit for bit.
--
-- WHY THE DRAWS ARE CHAINED. The carried stream advances with every draw --
-- position, state, how many have been taken from this number, whether it has
-- wrapped. Independent draws would check the arithmetic and miss the
-- bookkeeping, so one run passes through every setting from one file and
-- both machines are required to finish looking at the same place in it.

local M = {}

-- {{{ M.workspace(count, draws, stream_slots, plan_slots)
function M.workspace(count, draws, stream_slots, plan_slots)
  local at, cursor = {}, 0
  local function reserve(name, bytes)
    at[name] = cursor
    cursor = cursor + bytes
    if cursor % 16 ~= 0 then cursor = cursor + (16 - cursor % 16) end
  end

  reserve("hex", 64)
  reserve("chance", 8)
  reserve("plan", plan_slots * 8)
  reserve("stream", stream_slots * 8)
  reserve("probabilities", count * 4)
  reserve("kept_chances", count * 4)
  reserve("kept_tokens", count * 8)
  reserve("chosen", draws * 8)
  reserve("chances", draws * 4)

  at.total = cursor
  at.reserved = cursor
  if at.reserved % 4096 ~= 0 then
    at.reserved = at.reserved + (4096 - at.reserved % 4096)
  end
  return at
end
-- }}}

-- {{{ M.riscv64(options)
function M.riscv64(options)
  local words = dofile((options.dir or ".") .. "/src/054-riscv-words.lua")
  local p = words.new()

  local sampler = options.sampler
  local plan_at = sampler.plan_offsets()
  local stream_at = sampler.stream_offsets()
  local count = #options.scores
  local draws = #options.recorded
  local bits = options.float_bits

  local work = M.workspace(count, draws, #sampler.STREAM_SLOTS,
                           #sampler.PLAN_SLOTS)

  -- {{{ the pool, and the two rules for what may go in it
  --
  -- INPUTS should be almost entirely distinct -- anything else means a
  -- generator handed back a stale value, which once built a payload holding
  -- two hundred and fifty-six numbers of which three differed. OUTCOMES
  -- cannot be: six hundred draws from a vocabulary of forty-eight land on at
  -- most forty-eight values, and demanding more demands that a choice from a
  -- small set stop being one. So an outcome block states a minimum instead,
  -- which still catches a generator stuck on one answer.
  local pool_order, strings, string_order = {}, {}, {}
  local function pooled_words(label, values, at_least)
    pool_order[#pool_order + 1] =
      { label = label, values = values, at_least = at_least }
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
  -- An add-immediate reaches two thousand and forty-seven bytes here and the
  -- workspace is larger, so anything further out has its offset built into a
  -- register first.
  local function work_address(register, offset)
    if register == "t6" then
      error("121-emit-sampler-check-riscv: t6 is this helper's own scratch")
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
  p:op("mv s3, a1")                         -- the firmware's table
  p:op("ld s4, 64(s3)")                     -- its console
  p:load_constant("t0", work.reserved)
  p:op("sub sp, sp, t0")
  p:op("mv s5, zero")                       -- choices matched
  p:op("mv s6, zero")                       -- choices compared
  p:op("mv s7, zero")                       -- chances matched
  p:op("mv s8, zero")                       -- and compared
  p:op("mv s9, zero")                       -- the first draw that differed
  p:op("mv s10, zero")                      -- whether one has been captured
  -- }}}

  say_text("\r\ndrawing in the third tongue\r\n")

  -- everything writable, cleared before anything reads it
  work_address("t0", 0)
  p:load_constant("t1", work.reserved / 8)
  p:label("szero")
  p:op("sd zero, 0(t0)")
  p:op("addi t0, t0, 8")
  p:op("addi t1, t1, -1")
  p:branch("bne", "t1", "zero", "szero")

  -- {{{ the data
  local score_words = {}
  for _, value in ipairs(options.scores) do
    score_words[#score_words + 1] = bits.of(value)
  end
  pooled_words("scores", score_words)
  pooled_words("carried", options.stream_numbers)

  local want_tokens, want_chances = {}, {}
  for _, entry in ipairs(options.recorded) do
    -- a token is sixty-four bits, laid as two words with the low half first,
    -- which is the order both machines store them in
    want_tokens[#want_tokens + 1] = entry.token % 4294967296
    want_tokens[#want_tokens + 1] = math.floor(entry.token / 4294967296)
    want_chances[#want_chances + 1] = entry.chance
  end
  pooled_words("wanttokens", want_tokens, 5)
  pooled_words("wantchances", want_chances, 5)
  -- }}}

  -- {{{ the carried stream, as the first architecture set it up
  work_address("a0", work.stream)
  address("t0", "carried")
  p:op("sd t0, " .. stream_at.numbers .. "(a0)")
  p:load_constant("t0", #options.stream_numbers)
  p:op("sd t0, " .. stream_at.count .. "(a0)")
  p:op("sd zero, " .. stream_at.position .. "(a0)")
  p:op("sd zero, " .. stream_at.state .. "(a0)")
  p:load_constant("t0", options.per_number)
  p:op("sd t0, " .. stream_at.per_number .. "(a0)")
  -- drawn starts equal to per_number, so the very first draw reseeds
  p:op("sd t0, " .. stream_at.drawn .. "(a0)")
  p:op("sd zero, " .. stream_at.wrapped .. "(a0)")
  -- }}}

  -- {{{ the plan, once; only the three settings change between runs
  work_address("a0", work.plan)
  address("t0", "exp_one")
  p:op("sd t0, " .. plan_at.k_exp_one .. "(a0)")
  for _, name in ipairs({ "probabilities", "kept_chances", "kept_tokens",
                          "stream" }) do
    work_address("t0", work[name])
    p:op("sd t0, " .. plan_at[name] .. "(a0)")
  end
  -- }}}

  -- {{{ every setting, and every draw under it, in order
  --
  -- The stream is NOT reset between settings. One run of draws from one
  -- carried file, exactly as the first architecture did it.
  local draw_index = 0
  for _, setting in ipairs(options.settings) do
    say_text(".")
    work_address("a0", work.plan)
    local function store_float(value, slot_name)
      local pattern = bits.of(value)
      if pattern > 2147483647 then pattern = pattern - 4294967296 end
      p:load_constant("t0", pattern)
      p:op("sw t0, " .. plan_at[slot_name] .. "(a0)")
    end
    store_float(setting.temperature, "temperature")
    store_float(setting.top_p, "top_p")
    p:load_constant("t0", setting.top_k)
    p:op("sd t0, " .. plan_at.top_k .. "(a0)")

    for _ = 1, setting.draws do
      work_address("a0", work.plan)
      address("a1", "scores")
      p:load_constant("a2", count)
      work_address("a3", work.chance)
      p:call("sampler_choose")
      work_address("t0", work.chosen + draw_index * 8)
      p:op("sd a0, 0(t0)")
      work_address("t0", work.chance)
      p:op("lw t1, 0(t0)")
      work_address("t0", work.chances + draw_index * 4)
      p:op("sw t1, 0(t0)")
      draw_index = draw_index + 1
    end
  end
  -- }}}

  -- {{{ the whole run against the first architecture's
  work_address("t0", work.chosen)
  address("t1", "wanttokens")
  p:load_constant("t2", draws)
  p:label("stcmp")
  p:op("ld t3, 0(t0)")
  p:op("ld t4, 0(t1)")
  p:op("addi s6, s6, 1")
  p:branch("beq", "t3", "t4", "stcmpsame")
  p:branch("bne", "s10", "zero", "stcmpno")
  p:op("mv s9, s6")                         -- which draw first went astray
  p:op("addi s10, zero, 1")
  p:jump("stcmpno")
  p:label("stcmpsame")
  p:op("addi s5, s5, 1")
  p:label("stcmpno")
  p:op("addi t0, t0, 8")
  p:op("addi t1, t1, 8")
  p:op("addi t2, t2, -1")
  p:branch("bne", "t2", "zero", "stcmp")

  work_address("t0", work.chances)
  address("t1", "wantchances")
  p:load_constant("t2", draws)
  p:label("sccmp")
  p:op("lwu t3, 0(t0)")
  p:op("lwu t4, 0(t1)")
  p:op("addi s8, s8, 1")
  p:branch("bne", "t3", "t4", "sccmpno")
  p:op("addi s7, s7, 1")
  p:label("sccmpno")
  p:op("addi t0, t0, 4")
  p:op("addi t1, t1, 4")
  p:op("addi t2, t2, -1")
  p:branch("bne", "t2", "zero", "sccmp")
  -- }}}

  -- where the stream ended up, which is bookkeeping rather than arithmetic
  work_address("t0", work.stream)
  p:op("ld s11, " .. stream_at.position .. "(t0)")

  say_text("draws checked\r\n  chose ")
  say_hex("s5")
  say_text("\r\n  of ")
  say_hex("s6")
  say_text("\r\n  chances ")
  say_hex("s7")
  say_text("\r\n  cof ")
  say_hex("s8")
  say_text("\r\n  firstbad ")
  say_hex("s9")
  say_text("\r\n  streamat ")
  say_hex("s11")
  say_text("\r\n")

  p:label("halted")
  p:op("wfi")
  p:jump("halted")

  -- the routines, past the halt where nothing can fall into them
  options.kernels.emit(p, { "exp_one" }, {
    specification = options.specification,
    float_bits = options.float_bits,
  })
  options.sampler_module.emit(p, sampler)

  -- {{{ the pool
  for _, block in ipairs(pool_order) do
    p:align(16)
    p:label(block.label)
    local distinct, seen = {}, 0
    for _, value in ipairs(block.values) do
      p:word(value)
      if not distinct[value] then distinct[value] = true ; seen = seen + 1 end
    end
    if block.at_least then
      if seen < block.at_least then
        error(string.format(
          "121-emit-sampler-check-riscv: '%s' carries %d numbers with only "
          .. "%d distinct, and at least %d were expected. A run of draws that "
          .. "lands on almost nothing is a generator stuck on one answer.",
          block.label, #block.values, seen, block.at_least))
      end
    elseif #block.values > 8 and seen < #block.values * 0.9 then
      error(string.format(
        "121-emit-sampler-check-riscv: '%s' would carry %d numbers of which "
        .. "only %d are distinct. That is not test data, it is one number "
        .. "repeated.", block.label, #block.values, seen))
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
