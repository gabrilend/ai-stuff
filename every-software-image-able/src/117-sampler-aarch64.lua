-- 117-sampler-aarch64.lua
--
-- Choosing what to say next, in the second tongue. Issue 401.
--
-- For a general: the engine hands back a score for every word it might say.
-- This turns those scores into a choice. It is the piece between thinking
-- and speaking, and until it exists on an architecture, an engine there can
-- think and never say anything.
--
-- WHY EXACTNESS IS WORTH MORE HERE THAN ANYWHERE ELSE IN THE ENGINE. A score
-- that is off by one bit stays off by one bit. A CHOICE that flips at one
-- boundary joins the context, and every choice after it happens in a
-- different conversation -- two implementations diverge wholesale from that
-- moment rather than drifting. So this is held to the first architecture
-- choice for choice, and the chance each was chosen with is compared as bits.
--
-- NO SORT. The readable version orders every token by likelihood and cuts the
-- tail. This repeatedly extracts the first strict maximum instead -- same
-- order, reached lazily, stopped as soon as a cutter says stop. The tie rule
-- (equal chances go to the lower token) is what makes the two walks provably
-- identical.
--
-- A CONSUMED CANDIDATE IS FELLED TO MINUS ONE, which no probability can be,
-- so a slot never wins twice.
--
-- WHERE THE COMPARISONS HAD TO BE CHECKED RATHER THAN TRANSLATED. The first
-- architecture's float comparison sets its flags so that an unordered pair
-- -- one where something is not a number -- takes the same branch as
-- less-or-equal. This architecture's flags are laid out differently, and the
-- question of whether the two agree on that case had to be worked out rather
-- than assumed. They do: after a floating compare here, `le` means
-- less-or-equal OR unordered and `gt` means ordered greater, which is
-- exactly what the first tongue's `jbe` and `ja` mean. Nothing in a real
-- score is ever not a number, and a specification exact everywhere else
-- should not be approximate there.
--
-- WHAT SURVIVES A CALL. The exponential is called once per token, and this
-- architecture's convention says the low halves of the first eight vector
-- registers must be given back. The three running floats therefore live in
-- those rather than on the stack -- which is where the first tongue keeps
-- them, because it has no such registers to use.

local M = {}

-- {{{ M.source(sampler)
--
-- int64_t sampler_choose(const SamplerPlan *plan, const float *scores,
--                        int64_t count, float *chance_out)
--
-- plan x0, scores x1, count x2, chance_out x3.
--
-- `sampler` is the module that describes the two structures (057), passed in
-- so there stays exactly one description of where every slot sits.
--
--   x19  the plan          x20  the scores      x21  how many
--   x22  where the chance is written            x23  the index, and afterwards
--                                                    how many were kept
--   x24  the limit on how many may be kept
--   s8   the running total        s9  the largest score     s10  the kept total
function M.source(sampler)
  local plan = sampler.plan_offsets()
  local stream = sampler.stream_offsets()
  local out = {}
  local function line(text) out[#out + 1] = text end
  local function slot(name) return "[x19, #" .. plan[name] .. "]" end

  -- a whole thirty-two bit pattern into a register, sixteen bits at a time.
  -- There is no instruction that places an arbitrary one in a single step,
  -- and no loading it from memory either: a constant in memory needs a name,
  -- and a name in a payload is a note for a linker that nothing reads.
  local function constant(register, bits)
    line(string.format("  movz %s, #0x%x", register, bits % 0x10000))
    line(string.format("  movk %s, #0x%x, lsl #16", register,
                       math.floor(bits / 0x10000) % 0x10000))
  end

  line("  .globl sampler_choose")
  line("  .type sampler_choose, @function")
  line("sampler_choose:")
  -- Ninety-six rather than eighty, and the difference is the whole reason to
  -- write the layout down: the frame pair takes the first sixteen bytes, so
  -- the third floating register saved at offset eight would land on the
  -- return address, and the routine would come back to wherever the low half
  -- of a probability happened to point.
  line("  stp x29, x30, [sp, #-96]!")
  line("  mov x29, sp")
  line("  stp x19, x20, [sp, #16]")
  line("  stp x21, x22, [sp, #32]")
  line("  stp x23, x24, [sp, #48]")
  -- the floating registers this architecture obliges a callee to give back.
  -- Easy to forget, because the integer ones are the famous half.
  line("  stp d8, d9, [sp, #64]")
  line("  str d10, [sp, #80]")

  line("  mov x19, x0")
  line("  mov x20, x1")
  line("  mov x21, x2")
  line("  mov x22, x3")

  -- {{{ a temperature of zero is a different instruction: take the highest
  line("  ldr s0, " .. slot("temperature"))
  line("  fmov s1, wzr")
  line("  fcmp s0, s1")
  line("  b.gt warm")

  line("  ldr s2, [x20]")                   -- the first, until beaten
  line("  mov x0, xzr")
  line("  mov x9, #1")
  line("cold_scan:")
  line("  cmp x9, x21")
  line("  b.ge cold_done")
  line("  ldr s3, [x20, x9, lsl #2]")
  line("  fcmp s3, s2")
  line("  b.le cold_next")                  -- only strictly greater replaces,
  line("  fmov s2, s3")                     -- so the first of equals wins
  line("  mov x0, x9")
  line("cold_next:")
  line("  add x9, x9, #1")
  line("  b cold_scan")
  line("cold_done:")
  constant("w10", 0x3f800000)               -- chosen with certainty: one
  line("  str w10, [x22]")
  line("  b sampler_done")
  line("warm:")
  -- }}}

  -- {{{ scores into probabilities, every step at single precision
  line("  ldr s9, [x20]")                   -- the largest, found first
  line("  mov x9, #1")
  line("largest_scan:")
  line("  cmp x9, x21")
  line("  b.ge largest_done")
  line("  ldr s3, [x20, x9, lsl #2]")
  line("  fcmp s3, s9")
  line("  b.le largest_next")
  line("  fmov s9, s3")
  line("largest_next:")
  line("  add x9, x9, #1")
  line("  b largest_scan")
  line("largest_done:")

  line("  fmov s8, wzr")                    -- the total starts at nothing
  line("  mov x23, xzr")
  line("prob_loop:")
  line("  ldr s0, [x20, x23, lsl #2]")
  line("  fsub s0, s0, s9")                 -- the largest off first
  line("  ldr s1, " .. slot("temperature"))
  line("  fdiv s0, s0, s1")
  line("  ldr x9, " .. slot("k_exp_one"))
  line("  blr x9")
  line("  ldr x9, " .. slot("probabilities"))
  line("  str s0, [x9, x23, lsl #2]")
  line("  fadd s8, s8, s0")                 -- accumulated in ascending order
  line("  add x23, x23, #1")
  line("  cmp x23, x21")
  line("  b.lt prob_loop")

  line("  mov x23, xzr")
  line("divide_loop:")
  line("  ldr x9, " .. slot("probabilities"))
  line("  ldr s0, [x9, x23, lsl #2]")
  line("  fdiv s0, s0, s8")
  line("  str s0, [x9, x23, lsl #2]")
  line("  add x23, x23, #1")
  line("  cmp x23, x21")
  line("  b.lt divide_loop")
  -- }}}

  -- {{{ keep the likeliest, in order, until a cutter says stop
  --
  -- Each round takes the first strict maximum still standing, records it,
  -- and fells it. The felled value is minus one, which no probability can
  -- be, so a consumed slot never wins again.
  line("  ldr x24, " .. slot("top_k"))
  line("  cmp x24, x21")
  line("  b.le limit_known")
  line("  mov x24, x21")
  line("limit_known:")
  line("  fmov s10, wzr")                   -- the kept total starts at nothing
  line("  mov x23, xzr")
  line("select_loop:")
  line("  cmp x23, x24")
  line("  b.ge select_done")

  line("  ldr x9, " .. slot("probabilities"))
  line("  ldr s2, [x9]")
  line("  mov x8, xzr")
  line("  mov x11, #1")
  line("best_scan:")
  line("  cmp x11, x21")
  line("  b.ge best_done")
  line("  ldr s3, [x9, x11, lsl #2]")
  line("  fcmp s3, s2")
  line("  b.le best_next")
  line("  fmov s2, s3")
  line("  mov x8, x11")
  line("best_next:")
  line("  add x11, x11, #1")
  line("  b best_scan")
  line("best_done:")

  line("  ldr x12, " .. slot("kept_tokens"))
  line("  str x8, [x12, x23, lsl #3]")
  line("  ldr x12, " .. slot("kept_chances"))
  line("  str s2, [x12, x23, lsl #2]")
  constant("w13", 0xbf800000)               -- felled: minus one
  line("  str w13, [x9, x8, lsl #2]")
  line("  fadd s10, s10, s2")
  line("  add x23, x23, #1")
  line("  ldr s4, " .. slot("top_p"))
  line("  fcmp s10, s4")
  line("  b.ge select_done")                -- enough of the chance is covered
  line("  b select_loop")
  line("select_done:")
  -- }}}

  -- {{{ one draw from the stream
  --
  -- The readable version's next(), instruction for instruction: reseed from
  -- the carried file when this number is spent, step the generator in exact
  -- sixty-four bit integers, and hand back the state as a single divided by
  -- two to the thirty-first -- an exponent move that rounds nothing, which
  -- is why converting the state to single first is the only rounding here.
  line("  ldr x10, " .. slot("stream"))
  line("  ldr x9, [x10, #" .. stream.drawn .. "]")
  line("  ldr x11, [x10, #" .. stream.per_number .. "]")
  line("  cmp x9, x11")
  line("  b.lt seeded")
  line("  ldr x12, [x10, #" .. stream.numbers .. "]")
  line("  ldr x9, [x10, #" .. stream.position .. "]")
  line("  ldr w13, [x12, x9, lsl #2]")      -- loads thirty-two, zero-extended
  line("  str x13, [x10, #" .. stream.state .. "]")
  line("  str xzr, [x10, #" .. stream.drawn .. "]")
  line("  add x9, x9, #1")
  line("  ldr x11, [x10, #" .. stream.count .. "]")
  line("  cmp x9, x11")
  line("  b.lt position_kept")
  line("  mov x9, xzr")                     -- back to the start, and noticed
  line("  mov x13, #1")
  line("  str x13, [x10, #" .. stream.wrapped .. "]")
  line("position_kept:")
  line("  str x9, [x10, #" .. stream.position .. "]")
  line("seeded:")
  line("  ldr x9, [x10, #" .. stream.state .. "]")
  constant("w11", 1103515245)
  line("  mul x9, x9, x11")
  line("  movz x11, #12345")
  line("  add x9, x9, x11")
  line("  and x9, x9, #0x7fffffff")
  line("  str x9, [x10, #" .. stream.state .. "]")
  line("  ldr x11, [x10, #" .. stream.drawn .. "]")
  line("  add x11, x11, #1")
  line("  str x11, [x10, #" .. stream.drawn .. "]")
  line("  scvtf s0, x9")
  constant("w11", 0x4f000000)               -- two to the thirty-first, as bits
  line("  fmov s1, w11")
  line("  fdiv s0, s0, s1")
  line("  fmul s0, s0, s10")                -- scaled to what was kept
  -- }}}

  -- {{{ walk the kept until the draw is spent
  line("  fmov s1, wzr")
  line("  mov x11, xzr")
  line("walk:")
  line("  cmp x11, x23")
  line("  b.ge walk_past_end")
  line("  ldr x12, " .. slot("kept_chances"))
  line("  ldr s2, [x12, x11, lsl #2]")
  line("  fadd s1, s1, s2")
  line("  fcmp s0, s1")
  line("  b.le chosen")                     -- the draw landed inside this one
  line("  add x11, x11, #1")
  line("  b walk")
  line("walk_past_end:")
  -- rounding can leave the draw a hair past the end; the last kept is the
  -- right answer there, and taking it is arithmetic rather than a fallback.
  line("  sub x11, x23, #1")
  line("chosen:")
  line("  ldr x12, " .. slot("kept_chances"))
  line("  ldr s2, [x12, x11, lsl #2]")
  line("  str s2, [x22]")
  line("  ldr x12, " .. slot("kept_tokens"))
  line("  ldr x0, [x12, x11, lsl #3]")
  -- }}}

  line("sampler_done:")
  line("  ldr d10, [sp, #80]")
  line("  ldp d8, d9, [sp, #64]")
  line("  ldp x19, x20, [sp, #16]")
  line("  ldp x21, x22, [sp, #32]")
  line("  ldp x23, x24, [sp, #48]")
  line("  ldp x29, x30, [sp], #96")
  line("  ret")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
