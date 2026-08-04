-- 120-sampler-riscv64.lua
--
-- Choosing what to say next, in the third tongue. Issue 401.
--
-- For a general: the engine hands back a score for every word it might say.
-- This turns those scores into a choice. Until it exists on an architecture,
-- an engine there can think and never say anything.
--
-- WHY EXACTNESS IS WORTH MORE HERE THAN ANYWHERE ELSE IN THE ENGINE. A score
-- off in its last bit stays off in its last bit. A CHOICE that flips once
-- joins the context, and every word after it is said in a different
-- conversation -- two implementations diverge wholesale from that moment
-- rather than drifting. So this is held to the first architecture choice for
-- choice, and the chance each was chosen with is compared as bits.
--
-- THIS ARCHITECTURE HAS NO FLOATING CONDITION FLAGS, and that is the one
-- place the translation had to be reasoned about rather than copied. The
-- other two compare and then branch on flags, and both of them arrange those
-- flags so that an UNORDERED pair -- one where something is not a number --
-- takes the same branch as less-or-equal. Here a comparison instead writes a
-- one or a zero into an ordinary register, and every such instruction
-- answers zero for an unordered pair.
--
-- So each comparison is written as the POSITIVE test and branched on being
-- false: where the first tongue says "skip unless strictly greater", this
-- asks "is it strictly greater" and skips when the answer is no. An
-- unordered pair answers no, which is the same branch the other two take.
-- Nothing in a real score is ever not a number, and a specification exact
-- everywhere else should not be approximate there.
--
-- WHY IT EMITS RATHER THAN RETURNING TEXT. This assembler leaves a
-- relocation on a branch to a label in its own file, there is no linker to
-- answer it, and the branch then points at itself -- so every loop spins
-- forever, silently. The word emitter (054) counts every distance itself and
-- must see every instruction to do so.

local M = {}

-- {{{ M.emit(p, sampler)
--
-- int64_t sampler_choose(const SamplerPlan *plan, const float *scores,
--                        int64_t count, float *chance_out)
--
-- plan a0, scores a1, count a2, chance_out a3.
--
-- `sampler` is the module that describes the two structures (057), passed in
-- so there stays exactly one description of where every slot sits.
--
--   s0  the plan       s1  the scores      s2  how many
--   s3  where the chance is written
--   s4  the index, and afterwards how many were kept
--   s5  the limit on how many may be kept
--   fs0 the running total   fs1 the largest score   fs2 the kept total
function M.emit(p, sampler)
  local plan = sampler.plan_offsets()
  local stream = sampler.stream_offsets()
  local function slot(name) return plan[name] .. "(s0)" end

  -- a whole thirty-two bit pattern, handed to load_constant as the negative
  -- it would be read as when the top bit is set. The bits land identically.
  local function constant(register, bits)
    local value = bits
    if value > 2147483647 then value = value - 4294967296 end
    p:load_constant(register, value)
  end

  p:label("sampler_choose")
  -- ten things to give back: the return address, six registers, and three
  -- floating ones. Eighty bytes, which is already a multiple of sixteen.
  p:op("addi sp, sp, -80")
  p:op("sd ra, 0(sp)")
  for index = 0, 5 do
    p:op("sd s" .. index .. ", " .. (8 + index * 8) .. "(sp)")
  end
  -- the floating registers the convention obliges a callee to give back.
  -- Easy to forget, because the integer ones are the famous half.
  p:op("fsd fs0, 56(sp)")
  p:op("fsd fs1, 64(sp)")
  p:op("fsd fs2, 72(sp)")

  p:op("mv s0, a0")
  p:op("mv s1, a1")
  p:op("mv s2, a2")
  p:op("mv s3, a3")

  -- {{{ a temperature of zero is a different instruction: take the highest
  p:op("flw ft0, " .. slot("temperature"))
  p:op("fmv.w.x ft1, zero")
  p:op("flt.s t0, ft1, ft0")                -- is the temperature above zero
  p:branch("bne", "t0", "zero", "smp_warm")

  p:op("flw ft2, 0(s1)")                    -- the first, until beaten
  p:op("mv a0, zero")
  p:op("addi t1, zero, 1")
  p:label("smp_cold")
  p:branch("bge", "t1", "s2", "smp_cold_done")
  p:op("slli t2, t1, 2")
  p:op("add t2, s1, t2")
  p:op("flw ft3, 0(t2)")
  p:op("flt.s t0, ft2, ft3")                -- only strictly greater replaces,
  p:branch("beq", "t0", "zero", "smp_cold_next")   -- so the first of equals wins
  p:op("fmv.s ft2, ft3")
  p:op("mv a0, t1")
  p:label("smp_cold_next")
  p:op("addi t1, t1, 1")
  p:jump("smp_cold")
  p:label("smp_cold_done")
  constant("t0", 0x3f800000)                -- chosen with certainty: one
  p:op("sw t0, 0(s3)")
  p:jump("smp_done")
  p:label("smp_warm")
  -- }}}

  -- {{{ scores into probabilities, every step at single precision
  p:op("flw fs1, 0(s1)")                    -- the largest, found first
  p:op("addi t1, zero, 1")
  p:label("smp_largest")
  p:branch("bge", "t1", "s2", "smp_largest_done")
  p:op("slli t2, t1, 2")
  p:op("add t2, s1, t2")
  p:op("flw ft3, 0(t2)")
  p:op("flt.s t0, fs1, ft3")
  p:branch("beq", "t0", "zero", "smp_largest_next")
  p:op("fmv.s fs1, ft3")
  p:label("smp_largest_next")
  p:op("addi t1, t1, 1")
  p:jump("smp_largest")
  p:label("smp_largest_done")

  p:op("fmv.w.x fs0, zero")                 -- the total starts at nothing
  p:op("mv s4, zero")
  p:label("smp_prob")
  p:op("slli t2, s4, 2")
  p:op("add t2, s1, t2")
  p:op("flw fa0, 0(t2)")
  p:op("fsub.s fa0, fa0, fs1")              -- the largest off first
  p:op("flw ft1, " .. slot("temperature"))
  p:op("fdiv.s fa0, fa0, ft1")
  p:op("ld t0, " .. slot("k_exp_one"))
  p:op("jalr ra, 0(t0)")
  p:op("ld t1, " .. slot("probabilities"))
  p:op("slli t2, s4, 2")
  p:op("add t2, t1, t2")
  p:op("fsw fa0, 0(t2)")
  p:op("fadd.s fs0, fs0, fa0")              -- accumulated in ascending order
  p:op("addi s4, s4, 1")
  p:branch("blt", "s4", "s2", "smp_prob")

  p:op("mv s4, zero")
  p:label("smp_divide")
  p:op("ld t1, " .. slot("probabilities"))
  p:op("slli t2, s4, 2")
  p:op("add t2, t1, t2")
  p:op("flw ft0, 0(t2)")
  p:op("fdiv.s ft0, ft0, fs0")
  p:op("fsw ft0, 0(t2)")
  p:op("addi s4, s4, 1")
  p:branch("blt", "s4", "s2", "smp_divide")
  -- }}}

  -- {{{ keep the likeliest, in order, until a cutter says stop
  --
  -- Each round takes the first strict maximum still standing, records it,
  -- and fells it. The felled value is minus one, which no probability can
  -- be, so a consumed slot never wins again.
  p:op("ld s5, " .. slot("top_k"))
  p:branch("bge", "s2", "s5", "smp_limit_known")
  p:op("mv s5, s2")
  p:label("smp_limit_known")
  p:op("fmv.w.x fs2, zero")                 -- the kept total starts at nothing
  p:op("mv s4, zero")
  p:label("smp_select")
  p:branch("bge", "s4", "s5", "smp_select_done")

  p:op("ld t1, " .. slot("probabilities"))
  p:op("flw ft2, 0(t1)")
  p:op("mv a4, zero")                       -- which one is winning
  p:op("addi t3, zero, 1")
  p:label("smp_best")
  p:branch("bge", "t3", "s2", "smp_best_done")
  p:op("slli t2, t3, 2")
  p:op("add t2, t1, t2")
  p:op("flw ft3, 0(t2)")
  p:op("flt.s t0, ft2, ft3")
  p:branch("beq", "t0", "zero", "smp_best_next")
  p:op("fmv.s ft2, ft3")
  p:op("mv a4, t3")
  p:label("smp_best_next")
  p:op("addi t3, t3, 1")
  p:jump("smp_best")
  p:label("smp_best_done")

  p:op("ld t2, " .. slot("kept_tokens"))
  p:op("slli t3, s4, 3")
  p:op("add t3, t2, t3")
  p:op("sd a4, 0(t3)")
  p:op("ld t2, " .. slot("kept_chances"))
  p:op("slli t3, s4, 2")
  p:op("add t3, t2, t3")
  p:op("fsw ft2, 0(t3)")
  constant("t0", 0xbf800000)                -- felled: minus one
  p:op("slli t3, a4, 2")
  p:op("add t3, t1, t3")
  p:op("sw t0, 0(t3)")
  p:op("fadd.s fs2, fs2, ft2")
  p:op("addi s4, s4, 1")
  p:op("flw ft4, " .. slot("top_p"))
  p:op("fle.s t0, ft4, fs2")                -- enough of the chance covered
  p:branch("bne", "t0", "zero", "smp_select_done")
  p:jump("smp_select")
  p:label("smp_select_done")
  -- }}}

  -- {{{ one draw from the stream
  --
  -- The readable version's next(), instruction for instruction: reseed from
  -- the carried file when this number is spent, step the generator in exact
  -- sixty-four bit integers, and hand back the state as a single divided by
  -- two to the thirty-first -- an exponent move that rounds nothing, which
  -- is why converting the state to single first is the only rounding here.
  p:op("ld t4, " .. slot("stream"))
  p:op("ld t0, " .. stream.drawn .. "(t4)")
  p:op("ld t1, " .. stream.per_number .. "(t4)")
  p:branch("blt", "t0", "t1", "smp_seeded")
  p:op("ld t2, " .. stream.numbers .. "(t4)")
  p:op("ld t0, " .. stream.position .. "(t4)")
  p:op("slli t3, t0, 2")
  p:op("add t3, t2, t3")
  p:op("lwu t2, 0(t3)")                     -- thirty-two bits, zero-extended
  p:op("sd t2, " .. stream.state .. "(t4)")
  p:op("sd zero, " .. stream.drawn .. "(t4)")
  p:op("addi t0, t0, 1")
  p:op("ld t1, " .. stream.count .. "(t4)")
  p:branch("blt", "t0", "t1", "smp_position_kept")
  p:op("mv t0, zero")                       -- back to the start, and noticed
  p:op("addi t2, zero, 1")
  p:op("sd t2, " .. stream.wrapped .. "(t4)")
  p:label("smp_position_kept")
  p:op("sd t0, " .. stream.position .. "(t4)")
  p:label("smp_seeded")
  p:op("ld t0, " .. stream.state .. "(t4)")
  p:load_constant("t1", 1103515245)
  p:op("mul t0, t0, t1")
  p:load_constant("t1", 12345)
  p:op("add t0, t0, t1")
  p:load_constant("t1", 0x7fffffff)
  p:op("and t0, t0, t1")
  p:op("sd t0, " .. stream.state .. "(t4)")
  p:op("ld t1, " .. stream.drawn .. "(t4)")
  p:op("addi t1, t1, 1")
  p:op("sd t1, " .. stream.drawn .. "(t4)")
  -- Sixty-four bit integer to single, rounding to nearest and ties to even,
  -- SAID OUT LOUD. The state can be up to two thousand million and a single
  -- carries twenty-four bits of mantissa, so this genuinely rounds. Left
  -- unstated it would take whatever rounding mode the machine happened to be
  -- in, which is the right one at reset and not something to depend on --
  -- the other two architectures round here by their own default and this has
  -- to match them rather than match its own reset state.
  p:op("fcvt.s.l ft0, t0, rne")
  constant("t1", 0x4f000000)                -- two to the thirty-first, as bits
  p:op("fmv.w.x ft1, t1")
  p:op("fdiv.s ft0, ft0, ft1")
  p:op("fmul.s ft0, ft0, fs2")              -- scaled to what was kept
  -- }}}

  -- {{{ walk the kept until the draw is spent
  p:op("fmv.w.x ft1, zero")
  p:op("mv t3, zero")
  p:label("smp_walk")
  p:branch("bge", "t3", "s4", "smp_walk_past_end")
  p:op("ld t2, " .. slot("kept_chances"))
  p:op("slli t5, t3, 2")
  p:op("add t5, t2, t5")
  p:op("flw ft2, 0(t5)")
  p:op("fadd.s ft1, ft1, ft2")
  p:op("flt.s t0, ft1, ft0")                -- has the draw outrun the running total
  p:branch("beq", "t0", "zero", "smp_chosen")   -- no: it landed inside this one
  p:op("addi t3, t3, 1")
  p:jump("smp_walk")
  p:label("smp_walk_past_end")
  -- rounding can leave the draw a hair past the end; the last kept is the
  -- right answer there, and taking it is arithmetic rather than a fallback.
  p:op("addi t3, s4, -1")
  p:label("smp_chosen")
  p:op("ld t2, " .. slot("kept_chances"))
  p:op("slli t5, t3, 2")
  p:op("add t5, t2, t5")
  p:op("flw ft2, 0(t5)")
  p:op("fsw ft2, 0(s3)")
  p:op("ld t2, " .. slot("kept_tokens"))
  p:op("slli t5, t3, 3")
  p:op("add t5, t2, t5")
  p:op("ld a0, 0(t5)")
  -- }}}

  p:label("smp_done")
  p:op("fld fs2, 72(sp)")
  p:op("fld fs1, 64(sp)")
  p:op("fld fs0, 56(sp)")
  for index = 0, 5 do
    p:op("ld s" .. index .. ", " .. (8 + index * 8) .. "(sp)")
  end
  p:op("ld ra, 0(sp)")
  p:op("addi sp, sp, 80")
  p:op("jalr zero, 0(ra)")
end
-- }}}

return M
