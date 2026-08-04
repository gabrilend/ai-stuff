-- 118-emit-sampler-check.lua
--
-- A payload that draws on a bare ARM machine and says whether it chose the
-- same words the first architecture chose. Issue 401.
--
-- For a general: a score being off in its last bit stays off in its last
-- bit. A CHOICE that flips once joins the conversation, and everything after
-- it is said in a different conversation. So this does not check that the
-- two architectures are close; it checks that across many hundreds of draws,
-- under every setting the sampler has, they picked the same word every time
-- and recorded the same chance for it, bit for bit.
--
-- WHY THE DRAWS ARE CHAINED RATHER THAN INDEPENDENT. The carried stream
-- advances with every draw -- position, state, how many have been taken from
-- this number, and whether it has wrapped. Comparing single draws would
-- check the arithmetic and miss the bookkeeping. Running hundreds in a row
-- from one stream means a single wrong step puts every later draw in a
-- different place, which is exactly the failure being guarded against.
--
-- WHERE THE WRITABLE MEMORY IS. On the stack, all of it, because firmware
-- that honours section rights maps the payload's code read-only.

local M = {}

-- {{{ M.workspace(count, settings_count, draws, stream_slots, plan_slots)
-- Where everything writable lives, as offsets from the stack pointer.
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
  -- what this machine chose, kept so the whole run can be compared at once
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

-- {{{ M.aarch64(options)
--
-- options: sampler (057), scores, settings, stream_numbers, per_number,
--   recorded (per draw: token and chance bits), kernels, conductor_free
--   assembly text pieces, float_bits
function M.aarch64(options)
  local sampler = options.sampler
  local plan_at = sampler.plan_offsets()
  local stream_at = sampler.stream_offsets()
  local count = #options.scores
  local draws = #options.recorded

  local work = M.workspace(count, draws, #sampler.STREAM_SLOTS,
                           #sampler.PLAN_SLOTS)

  local out = {}
  local function line(text) out[#out + 1] = text end
  local bits = options.float_bits

  -- {{{ local function lay_down(label, words, at_least)
  -- A block of numbers, and a refusal to write one that is not varied -- the
  -- same guard 101 carries, because a payload was once built holding two
  -- hundred and fifty-six numbers of which three were distinct and the
  -- machine that ran it did correct arithmetic over wrong data and was very
  -- nearly recorded as a broken port.
  --
  -- TWO KINDS OF BLOCK, AND THEY NEED DIFFERENT RULES. For INPUTS -- scores,
  -- carried numbers, weights -- nearly every value should differ, because
  -- anything else means the generator handed back a stale value. That is the
  -- default and it stays at ninety percent.
  --
  -- For OUTCOMES it is wrong, and firmly so. Six hundred and twenty draws
  -- from a vocabulary of forty-eight cannot be ninety percent distinct; they
  -- can be at most forty-eight distinct, and demanding more is demanding
  -- that a choice from a small set stop being one. The guard's own note
  -- already says a short run may legitimately repeat and that refusing it
  -- would be refusing arithmetic -- this is that case at length.
  --
  -- So an outcome block says how many distinct values it expects at least.
  -- That still catches the failure worth catching: a generator stuck on one
  -- answer, or a recording loop that wrote the same draw six hundred times.
  -- What it stops doing is calling a legitimate distribution broken.
  local function lay_down(label, words, at_least)
    line("  .balign 16")
    line(label .. ":")
    local distinct, seen = {}, 0
    local row = {}
    for index, word in ipairs(words) do
      local text = string.format("0x%08x", word)
      if not distinct[text] then distinct[text] = true ; seen = seen + 1 end
      row[#row + 1] = text
      if #row == 8 or index == #words then
        line("  .word " .. table.concat(row, ", "))
        row = {}
      end
    end

    if at_least then
      if seen < at_least then
        error(string.format(
          "118-emit-sampler-check: '%s' carries %d numbers with only %d "
          .. "distinct values, and at least %d were expected. A run of draws "
          .. "that lands on almost nothing is a generator stuck on one "
          .. "answer, not a distribution.", label, #words, seen, at_least))
      end
    elseif #words > 8 and seen < #words * 0.9 then
      error(string.format(
        "118-emit-sampler-check: '%s' would carry %d numbers of which only "
        .. "%d are distinct. That is not test data, it is one number "
        .. "repeated.", label, #words, seen))
    end
  end
  -- }}}

  line("  .text")
  line("  .globl _start")
  line("_start:")
  line("  b start_here")

  -- the exponential and the sampler, with their exports stripped. A call to
  -- an exported name is a note for a linker, there is none here, and the
  -- offset then stays zero -- which is a call to itself.
  local function strip(text)
    return (text:gsub("%s*%.section%s+%.note%.GNU%-stack[^\n]*\n", "\n")
                :gsub("^%s*%.text%s*\n", "")
                :gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
                :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n"))
  end
  line(strip(options.kernels))
  line(strip(options.sampler_source))

  line("start_here:")
  line("  sub sp, sp, #" .. work.reserved)
  line("  mov x19, x1")                     -- the firmware's table
  line("  ldr x20, [x19, #64]")             -- its console
  line("  mov x21, sp")                     -- everything writable, from here
  line("  mov x22, xzr")                    -- choices matched
  line("  mov x23, xzr")                    -- choices compared
  line("  mov x24, xzr")                    -- chances matched
  line("  mov x25, xzr")                    -- and compared
  line("  mov x26, xzr")                    -- the first draw that differed
  line("  mov x27, xzr")                    -- whether one has been captured

  -- {{{ addressing the workspace
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
    local skip, label = "sskip" .. said, "stext" .. said
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
    local loop, digit, done = "shex" .. converted, "sdig" .. converted,
                              "sdone" .. converted
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

  say_text("\r\ndrawing in the second tongue\r\n")

  -- {{{ the data
  line("  b sdata_done")

  local score_words = {}
  for _, value in ipairs(options.scores) do
    score_words[#score_words + 1] = bits.of(value)
  end
  lay_down("scores", score_words)
  lay_down("carried", options.stream_numbers)

  local want_tokens, want_chances = {}, {}
  for _, entry in ipairs(options.recorded) do
    -- a token is sixty-four bits; laid as two words, low half first, which
    -- is the order this machine and the first one both store them in
    want_tokens[#want_tokens + 1] = entry.token % 4294967296
    want_tokens[#want_tokens + 1] = math.floor(entry.token / 4294967296)
    want_chances[#want_chances + 1] = entry.chance
  end
  -- Outcomes, not inputs. The tokens are drawn from a small vocabulary and
  -- half the block is the high half of each sixty-four bit token, which is
  -- zero for every token any real vocabulary has -- so the distinct count is
  -- bounded by the vocabulary and cannot approach the block's length. What
  -- is worth insisting on is that the run went to more than a handful of
  -- different words, which is what a stuck generator would fail.
  lay_down("wanttokens", want_tokens, options.least_distinct_tokens or 5)
  lay_down("wantchances", want_chances, options.least_distinct_chances or 5)

  line("sdata_done:")
  -- }}}

  -- {{{ everything writable, cleared before anything reads it
  address_of("x10", 0)
  line("  movz x11, #" .. (work.reserved / 8))
  line("szero:")
  line("  str xzr, [x10], #8")
  line("  subs x11, x11, #1")
  line("  b.ne szero")
  -- }}}

  -- {{{ the carried stream, as the first architecture set it up
  address_of("x0", work.stream)
  line("  adr x9, carried")
  line("  str x9, [x0, #" .. stream_at.numbers .. "]")
  line("  movz x9, #" .. #options.stream_numbers)
  line("  str x9, [x0, #" .. stream_at.count .. "]")
  line("  str xzr, [x0, #" .. stream_at.position .. "]")
  line("  str xzr, [x0, #" .. stream_at.state .. "]")
  line("  movz x9, #" .. options.per_number)
  line("  str x9, [x0, #" .. stream_at.per_number .. "]")
  -- drawn starts equal to per_number, so the very first draw reseeds
  line("  str x9, [x0, #" .. stream_at.drawn .. "]")
  line("  str xzr, [x0, #" .. stream_at.wrapped .. "]")
  -- }}}

  -- {{{ the plan, once; only the three settings change between runs
  address_of("x0", work.plan)
  line("  adr x9, exp_one")
  line("  str x9, [x0, #" .. plan_at.k_exp_one .. "]")
  for _, pair in ipairs({ { "probabilities", "probabilities" },
                          { "kept_chances", "kept_chances" },
                          { "kept_tokens", "kept_tokens" },
                          { "stream", "stream" } }) do
    address_of("x9", work[pair[2]])
    line("  str x9, [x0, #" .. plan_at[pair[1]] .. "]")
  end
  -- }}}

  -- {{{ every setting, and every draw under it, in order
  --
  -- The stream is NOT reset between settings. One run of draws from one
  -- carried file, exactly as the first architecture did it, so the position
  -- and the reseeding are compared as well as the arithmetic.
  local draw_index = 0
  for _, setting in ipairs(options.settings) do
    say_text(".")
    address_of("x0", work.plan)
    line(string.format("  movz w9, #0x%x", bits.of(setting.temperature) % 0x10000))
    line(string.format("  movk w9, #0x%x, lsl #16",
                       math.floor(bits.of(setting.temperature) / 0x10000)))
    line("  str w9, [x0, #" .. plan_at.temperature .. "]")
    line(string.format("  movz w9, #0x%x", bits.of(setting.top_p) % 0x10000))
    line(string.format("  movk w9, #0x%x, lsl #16",
                       math.floor(bits.of(setting.top_p) / 0x10000)))
    line("  str w9, [x0, #" .. plan_at.top_p .. "]")
    line("  movz x9, #" .. setting.top_k)
    line("  str x9, [x0, #" .. plan_at.top_k .. "]")

    for _ = 1, setting.draws do
      address_of("x0", work.plan)
      line("  adr x1, scores")
      line("  movz x2, #" .. count)
      address_of("x3", work.chance)
      line("  bl sampler_choose")
      -- the token and the chance, kept where the whole run can be compared
      address_of("x9", work.chosen + draw_index * 8)
      line("  str x0, [x9]")
      address_of("x9", work.chance)
      line("  ldr w10, [x9]")
      address_of("x9", work.chances + draw_index * 4)
      line("  str w10, [x9]")
      draw_index = draw_index + 1
    end
  end
  -- }}}

  -- {{{ the whole run against the first architecture's
  address_of("x5", work.chosen)
  line("  adr x6, wanttokens")
  line("  movz x7, #" .. draws)
  line("stcmp:")
  line("  ldr x8, [x5], #8")
  line("  ldr x9, [x6], #8")
  line("  add x23, x23, #1")
  line("  cmp x8, x9")
  line("  b.eq stcmpsame")
  line("  cbnz x27, stcmpno")
  line("  mov x26, x23")                    -- which draw first went astray
  line("  mov x27, #1")
  line("  b stcmpno")
  line("stcmpsame:")
  line("  add x22, x22, #1")
  line("stcmpno:")
  line("  subs x7, x7, #1")
  line("  b.ne stcmp")

  address_of("x5", work.chances)
  line("  adr x6, wantchances")
  line("  movz x7, #" .. draws)
  line("sccmp:")
  line("  ldr w8, [x5], #4")
  line("  ldr w9, [x6], #4")
  line("  add x25, x25, #1")
  line("  cmp w8, w9")
  line("  b.ne sccmpno")
  line("  add x24, x24, #1")
  line("sccmpno:")
  line("  subs x7, x7, #1")
  line("  b.ne sccmp")
  -- }}}

  -- {{{ and where the stream ended up, which is bookkeeping rather than arithmetic
  address_of("x9", work.stream)
  line("  ldr x28, [x9, #" .. stream_at.position .. "]")
  -- }}}

  say_text("draws checked\r\n  chose ")
  say_hex("x22")
  say_text("\r\n  of ")
  say_hex("x23")
  say_text("\r\n  chances ")
  say_hex("x24")
  say_text("\r\n  cof ")
  say_hex("x25")
  say_text("\r\n  firstbad ")
  say_hex("x26")
  say_text("\r\n  streamat ")
  say_hex("x28")
  say_text("\r\n")

  line("shalt:")
  line("  wfi")
  line("  b shalt")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
