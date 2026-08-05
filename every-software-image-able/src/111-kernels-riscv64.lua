-- 111-kernels-riscv64.lua
--
-- The arithmetic in the third tongue. Issue 401.
--
-- For a general: the same innermost loops the machine already has, written a
-- third time in a third processor's instructions. The test of a port is not
-- that it looks right; it is that it produces the same numbers, bit for bit,
-- as the first one did.
--
-- WHY THIS FILE IS BUILT AND NOT WRITTEN. The other two tongues are held as
-- text, because their assemblers finish branch arithmetic themselves. This
-- one's does not: with relaxation and compressed instructions both switched
-- off, a conditional branch to a label in the same file STILL leaves a
-- relocation behind, and the extracted bytes encode a branch to the
-- instruction's own address. With no linker, every loop becomes a silent
-- infinite one. So every routine here emits into the two-pass word emitter
-- (054), which counts the distance itself and writes the finished
-- instruction. That is the difference this architecture insists on, and it
-- is the reason the tool was built before the port.
--
-- THE CALLING CONVENTION. Integer arguments in a0 onward, floating ones in
-- fa0 onward, a return in a0 or fa0. t0-t6 and ft0-ft11 may be destroyed by
-- anything; s0-s11 and fs0-fs11 must be given back. Every routine here uses
-- only the first kind, EXCEPT the two that call the exponential -- those
-- keep what must outlive the call in the second kind, and say so.
--
-- THE ORDER OF ADDITION IS THE SPECIFICATION, exactly as in the other two.
-- Every accumulation is single precision in ascending index order. A faster
-- answer that differs in the last bit is a different specification rather
-- than a better implementation of this one.
--
-- WHAT THIS ARCHITECTURE DOES NOT HAVE, and it was measured rather than
-- assumed. A bare probe that configures a vector register and then says so
-- gets no further on the processor this project's RISC-V board names. Where
-- the hardware does exist, it stays switched off until a machine-mode
-- control register enables it -- a privilege question, depending on what
-- level the firmware hands over at, which differs between the three
-- firmwares this project already knows hand over three different ways.
--
-- So the fast matrix product here keeps its four totals in ORDINARY
-- floating registers. Same second specification, same lane assignment, same
-- final combining order, so it remains comparable to the first
-- architecture's fast kernel bit for bit -- and it needs no extension, no
-- privilege, and no negotiation with firmware. A genuinely vectorised one
-- can follow later, for chips that have the hardware, as a fourth kernel
-- rather than as a replacement for this one.

local M = {}

-- {{{ M.written -- what exists here, so a test can ask rather than be told
--
-- The exponential comes before the two that call it only for readability;
-- unlike the other two tongues, the emitter resolves every distance itself,
-- so order carries no meaning here.
M.written = {
  "matrix_vector_plain", "matrix_vector_wide", "matrix_vector_fast",
  "matrix_vector_quantised",
  "rms_normalise",
  "add_into", "rotate", "attention_scores", "attention_mix",
  "exp_one", "softmax", "swiglu",
}
-- }}}

-- {{{ M.missing_from(first_tongue_names)
-- What the first architecture has that this one does not, WORKED OUT rather
-- than remembered. The second architecture kept a hand-written list of what
-- was still to do, emptied it when the port felt finished, and was then
-- missing a routine that nothing reported. This asks instead.
function M.missing_from(first_tongue_names)
  local have = {}
  for _, name in ipairs(M.written) do have[name] = true end
  local missing = {}
  for _, name in ipairs(first_tongue_names) do
    if not have[name] then missing[#missing + 1] = name end
  end
  return missing
end
-- }}}

local emitters = {}

-- {{{ emitters.matrix_vector_plain
--
-- void matrix_vector_plain(float *out, const float *matrix,
--                          const float *input, int rows, int columns)
--
-- out a0, matrix a1, input a2, rows a3, columns a4.
--
-- The counts arrive as thirty-two bit values sign-extended into sixty-four
-- bit registers, which is what the convention says an int does, so the
-- signed comparisons below are the right ones.
emitters.matrix_vector_plain = function(p)
  p:label("matrix_vector_plain")
  p:branch("bge", "zero", "a3", "mvp_done")   -- no rows: nothing to do
  p:op("addi t0, zero, 0")                    -- row
  p:label("mvp_row")
  p:op("fmv.w.x ft0, zero")                   -- running total for this row
  p:op("mul t1, t0, a4")
  p:op("slli t1, t1, 2")
  p:op("add t1, a1, t1")                      -- where this row begins
  p:op("addi t2, zero, 0")                    -- column
  p:branch("bge", "zero", "a4", "mvp_store")  -- a row of no columns totals zero
  p:label("mvp_col")
  p:op("slli t3, t2, 2")
  p:op("add t4, t1, t3")
  p:op("flw ft1, 0(t4)")
  p:op("add t5, a2, t3")
  p:op("flw ft2, 0(t5)")
  p:op("fmul.s ft1, ft1, ft2")
  p:op("fadd.s ft0, ft0, ft1")
  p:op("addi t2, t2, 1")
  p:branch("blt", "t2", "a4", "mvp_col")
  p:label("mvp_store")
  p:op("slli t3, t0, 2")
  p:op("add t4, a0, t3")
  p:op("fsw ft0, 0(t4)")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a3", "mvp_row")
  p:label("mvp_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.matrix_vector_wide -- four at a time, one total
--
-- The same answer as the plain one, reading four numbers per step. The four
-- products are folded into ONE running total in the same order the plain
-- version would use, which is what keeps the answer identical.
--
-- On the other two architectures this reads a whole vector register at once.
-- Here the four loads are four ordinary loads, because there is no vector
-- register to read into on the processor this project's board names. The
-- shape of the loop and the order of the folding are the same, so the answer
-- is the same, and the gain is whatever the processor can overlap on its own.
emitters.matrix_vector_wide = function(p)
  p:label("matrix_vector_wide")
  p:branch("bge", "zero", "a3", "mvw_done")
  p:op("addi t0, zero, 0")                    -- row
  p:label("mvw_row")
  p:op("fmv.w.x ft0, zero")                   -- one running total
  p:op("mul t1, t0, a4")
  p:op("slli t1, t1, 2")
  p:op("add t1, a1, t1")                      -- where this row begins
  p:op("addi t2, zero, 0")                    -- column
  p:op("andi t6, a4, -4")                     -- columns in whole groups of four
  p:branch("bge", "zero", "t6", "mvw_tail_check")
  p:label("mvw_group")
  p:op("slli t3, t2, 2")
  p:op("add t4, t1, t3")                      -- four from the row
  p:op("add t5, a2, t3")                      -- four from the input
  for step = 0, 3 do
    p:op("flw ft1, " .. (step * 4) .. "(t4)")
    p:op("flw ft2, " .. (step * 4) .. "(t5)")
    p:op("fmul.s ft1, ft1, ft2")
    p:op("fadd.s ft0, ft0, ft1")              -- folded in, in order
  end
  p:op("addi t2, t2, 4")
  p:branch("blt", "t2", "t6", "mvw_group")
  p:label("mvw_tail_check")
  p:branch("bge", "t2", "a4", "mvw_store")
  p:label("mvw_tail")
  p:op("slli t3, t2, 2")
  p:op("add t4, t1, t3")
  p:op("flw ft1, 0(t4)")
  p:op("add t5, a2, t3")
  p:op("flw ft2, 0(t5)")
  p:op("fmul.s ft1, ft1, ft2")
  p:op("fadd.s ft0, ft0, ft1")
  p:op("addi t2, t2, 1")
  p:branch("blt", "t2", "a4", "mvw_tail")
  p:label("mvw_store")
  p:op("slli t3, t0, 2")
  p:op("add t4, a0, t3")
  p:op("fsw ft0, 0(t4)")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a3", "mvw_row")
  p:label("mvw_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.matrix_vector_fast -- four independent totals
--
-- The same operation as the two above and DELIBERATELY NOT THE SAME ANSWER.
--
-- Four totals that never wait on each other, instead of one that waits on
-- every addition. Floating-point addition is not associative, so the answer
-- differs in the last bits -- not because either is wrong, but because they
-- sum in different orders and the order is part of the answer. It is a
-- second specification, held to the first architecture's fast kernel and
-- never to the exact one.
--
-- LANE ASSIGNMENT MUST MATCH THE OTHER TWO ARCHITECTURES. There, one
-- instruction adds a whole vector of four products into a whole vector of
-- four totals, so total i receives columns i, i+4, i+8 and so on. Here the
-- four additions are written out, and they must land in that same
-- arrangement or the answer is a third specification nobody asked for.
--
-- THE FINAL COMBINING IS SPECIFIED RATHER THAN INCIDENTAL:
--     lane0 += lane2, lane1 += lane3, then lane0 += lane1
-- and any remaining columns are folded in one at a time AFTERWARDS.
emitters.matrix_vector_fast = function(p)
  p:label("matrix_vector_fast")
  p:branch("bge", "zero", "a3", "mvf_done")
  p:op("addi t0, zero, 0")                    -- row
  p:label("mvf_row")
  p:op("fmv.w.x ft4, zero")                   -- the four totals, one per lane
  p:op("fmv.w.x ft5, zero")
  p:op("fmv.w.x ft6, zero")
  p:op("fmv.w.x ft7, zero")
  p:op("mul t1, t0, a4")
  p:op("slli t1, t1, 2")
  p:op("add t1, a1, t1")
  p:op("addi t2, zero, 0")
  p:op("andi t6, a4, -4")
  p:branch("bge", "zero", "t6", "mvf_combine")
  p:label("mvf_group")
  p:op("slli t3, t2, 2")
  p:op("add t4, t1, t3")
  p:op("add t5, a2, t3")
  for lane = 0, 3 do
    p:op("flw ft1, " .. (lane * 4) .. "(t4)")
    p:op("flw ft2, " .. (lane * 4) .. "(t5)")
    p:op("fmul.s ft1, ft1, ft2")
    -- straight into that lane's own total, waiting on nothing
    p:op("fadd.s ft" .. (4 + lane) .. ", ft" .. (4 + lane) .. ", ft1")
  end
  p:op("addi t2, t2, 4")
  p:branch("blt", "t2", "t6", "mvf_group")
  p:label("mvf_combine")
  p:op("fadd.s ft4, ft4, ft6")                -- lane0 += lane2
  p:op("fadd.s ft5, ft5, ft7")                -- lane1 += lane3
  p:op("fadd.s ft0, ft4, ft5")                -- and the two halves together
  p:branch("bge", "t2", "a4", "mvf_store")
  p:label("mvf_tail")
  p:op("slli t3, t2, 2")
  p:op("add t4, t1, t3")
  p:op("flw ft1, 0(t4)")
  p:op("add t5, a2, t3")
  p:op("flw ft2, 0(t5)")
  p:op("fmul.s ft1, ft1, ft2")
  p:op("fadd.s ft0, ft0, ft1")
  p:op("addi t2, t2, 1")
  p:branch("blt", "t2", "a4", "mvf_tail")
  p:label("mvf_store")
  p:op("slli t3, t0, 2")
  p:op("add t4, a0, t3")
  p:op("fsw ft0, 0(t4)")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a3", "mvf_row")
  p:label("mvf_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.matrix_vector_quantised -- weights at four bits
--
-- void matrix_vector_quantised(float *out, const unsigned char *matrix,
--                              const float *input, int rows, int columns)
--
-- out a0, matrix a1, input a2, rows a3, columns a4.
--
-- A FOURTH SPECIFICATION, not a smaller version of the three above. Its
-- weights have already lost information and its answer is different on
-- purpose, so it is never compared against the exact product -- it is held
-- to `123` and to the other two architectures.
--
-- THE SCALE IS UNPACKED IN WHOLE-NUMBER ARITHMETIC, and this architecture is
-- the reason all three do it that way. Half-precision here is an extension
-- (Zfh) that the base set does not include and the processor this project's
-- board names does not have -- the same shape of absence as its vector
-- hardware, and measured the same way. The other two could each borrow a
-- conversion instruction and this one cannot, so none of them do: three
-- implementations agreeing is the point, and one taking a shortcut the
-- others cannot follow is how they stop.
--
-- The unpacking is the same three steps everywhere: shift the pattern up
-- thirteen places so its mantissa lands where a single precision mantissa
-- goes, add the difference between the two exponent biases, and -- only when
-- the exponent field was zero -- take one step into the normal range and
-- subtract it off again, which resolves a subnormal without counting leading
-- zeroes. A scale is never negative and never infinite, because the
-- quantiser takes a magnitude and saturates.
--
-- TWO WEIGHTS PER PASS, and not for speed: choosing a half of a byte by
-- testing an index would put a branch in the innermost loop of the machine.
emitters.matrix_vector_quantised = function(p)
  p:label("matrix_vector_quantised")
  p:branch("bge", "zero", "a3", "mvq_done")   -- no rows: nothing to do

  -- The patterns the scale's unpacking needs, built once -- in a5, a6 and a7
  -- rather than in the s registers, which is not a style choice. This routine
  -- calls nothing, so it is tempting to treat any register as scratch; the s
  -- registers belong to whoever called, and a routine that keeps them is a
  -- routine that breaks a loop somewhere above it and hangs rather than
  -- fails. The argument registers past the fifth are free precisely because
  -- this routine takes five.
  p:load_constant("a5", 0x0f800000)           -- where the exponent field sits
  p:load_constant("a6", 0x38000000)           -- the biases differ by this
  p:load_constant("a7", 0x00800000)           -- one step into the normals
  p:load_constant("t0", 0x38800000)
  p:op("fmv.w.x ft7, t0")                     -- that step, as a number

  p:op("addi t0, zero, 0")                    -- row
  p:label("mvq_row")
  p:op("fmv.w.x ft0, zero")                   -- running total for this row
  p:op("srli t1, a4, 5")                      -- blocks in a row: columns / 32
  p:op("mul t1, t0, t1")                      -- rows of blocks before this one
  p:op("addi t2, zero, 18")
  p:op("mul t1, t1, t2")                      -- eighteen bytes to a block
  p:op("add t1, a1, t1")                      -- where this row's bytes begin
  p:op("addi t2, zero, 0")                    -- column
  p:branch("bge", "zero", "a4", "mvq_store")  -- a row of no columns is zero

  p:label("mvq_block")
  -- the scale, out of two bytes and into a single precision register
  p:op("lhu t3, 0(t1)")
  p:op("slli t3, t3, 13")
  p:op("and t4, t3, a5")                      -- the exponent field
  p:op("add t3, t3, a6")
  p:branch("bne", "t4", "zero", "mvq_normal")
  p:op("add t3, t3, a7")                      -- a step into the normal range
  p:op("fmv.w.x ft1, t3")
  p:op("fsub.s ft1, ft1, ft7")                -- and the same step, taken off
  p:jump("mvq_have_scale")
  p:label("mvq_normal")
  p:op("fmv.w.x ft1, t3")
  p:label("mvq_have_scale")

  p:op("addi t5, zero, 0")                    -- which byte of the sixteen
  p:label("mvq_byte")
  p:op("add t6, t1, t5")
  p:op("lbu t3, 2(t6)")                       -- two weights

  p:op("andi t4, t3, 15")                     -- the earlier one is the low half
  p:op("addi t4, t4, -8")                     -- eight stands for nothing
  p:op("fcvt.s.w ft2, t4, rne")
  p:op("fmul.s ft2, ft2, ft1")                -- times the block's scale
  p:op("slli t6, t2, 2")
  p:op("add t6, a2, t6")
  p:op("flw ft3, 0(t6)")
  p:op("fmul.s ft2, ft2, ft3")                -- times what it meets
  p:op("fadd.s ft0, ft0, ft2")                -- ascending order, as everywhere
  p:op("addi t2, t2, 1")

  p:op("srli t4, t3, 4")                      -- the later one is the high half
  p:op("addi t4, t4, -8")
  p:op("fcvt.s.w ft2, t4, rne")
  p:op("fmul.s ft2, ft2, ft1")
  p:op("slli t6, t2, 2")
  p:op("add t6, a2, t6")
  p:op("flw ft3, 0(t6)")
  p:op("fmul.s ft2, ft2, ft3")
  p:op("fadd.s ft0, ft0, ft2")
  p:op("addi t2, t2, 1")

  p:op("addi t5, t5, 1")
  p:op("addi t6, zero, 16")
  p:branch("blt", "t5", "t6", "mvq_byte")

  p:op("addi t1, t1, 18")                     -- the next block
  p:branch("blt", "t2", "a4", "mvq_block")

  p:label("mvq_store")
  p:op("slli t3, t0, 2")
  p:op("add t3, a0, t3")
  p:op("fsw ft0, 0(t3)")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a3", "mvq_row")
  p:label("mvq_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.rms_normalise
--
-- void rms_normalise(float *out, const float *input, const float *weight,
--                    int size, float epsilon)
--
-- out a0, input a1, weight a2, size a3, epsilon fa0.
--
-- The value one is built in a register rather than loaded from anywhere: a
-- constant in memory needs a symbol reference, and a symbol reference in
-- this project is a note for a linker that nothing reads.
emitters.rms_normalise = function(p)
  p:label("rms_normalise")
  p:op("fmv.s ft5, fa0")                      -- keep epsilon
  p:branch("bge", "zero", "a3", "rms_done")
  p:op("fmv.w.x ft0, zero")                   -- sum of squares
  p:op("addi t0, zero, 0")
  p:label("rms_sum")
  p:op("slli t1, t0, 2")
  p:op("add t2, a1, t1")
  p:op("flw ft1, 0(t2)")
  p:op("fmul.s ft1, ft1, ft1")
  p:op("fadd.s ft0, ft0, ft1")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a3", "rms_sum")

  p:op("fcvt.s.w ft2, a3")                    -- how many numbers there were
  p:op("fdiv.s ft0, ft0, ft2")                -- the mean of the squares
  p:op("fadd.s ft0, ft0, ft5")                -- plus the small constant
  p:op("fsqrt.s ft0, ft0")
  p:load_constant("t1", 0x3f800000)           -- the bits of one, built
  p:op("fmv.w.x ft4, t1")
  p:op("fdiv.s ft0, ft4, ft0")                -- the scale to apply

  p:op("addi t0, zero, 0")
  p:label("rms_scale")
  p:op("slli t1, t0, 2")
  p:op("add t2, a1, t1")
  p:op("flw ft1, 0(t2)")
  p:op("fmul.s ft1, ft1, ft0")
  p:op("add t3, a2, t1")
  p:op("flw ft2, 0(t3)")
  p:op("fmul.s ft1, ft1, ft2")
  p:op("add t4, a0, t1")
  p:op("fsw ft1, 0(t4)")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a3", "rms_scale")
  p:label("rms_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.add_into
--
-- void add_into(float *destination, const float *addend, int count)
--
-- destination a0, addend a1, count a2.
--
-- What carries a token's meaning past a layer rather than through it.
emitters.add_into = function(p)
  p:label("add_into")
  p:branch("bge", "zero", "a2", "add_done")
  p:op("addi t0, zero, 0")
  p:label("add_loop")
  p:op("slli t1, t0, 2")
  p:op("add t2, a0, t1")
  p:op("flw ft0, 0(t2)")
  p:op("add t3, a1, t1")
  p:op("flw ft1, 0(t3)")
  p:op("fadd.s ft0, ft0, ft1")
  p:op("fsw ft0, 0(t2)")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a2", "add_loop")
  p:label("add_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.rotate
--
-- void rotate(float *vec, const float *turns, int heads, int head_width)
--
-- vec a0, turns a1, heads a2, head_width a3.
--
-- Turns each pair of numbers in each head by the angle for this position,
-- reading the cosine and sine from the carried table rather than computing
-- them -- which is why this routine is built from multiplication and
-- addition alone, and can therefore be required to match exactly.
emitters.rotate = function(p)
  p:label("rotate")
  p:branch("bge", "zero", "a2", "rot_done")
  p:branch("bge", "zero", "a3", "rot_done")
  p:op("srli t0, a3, 1")                      -- pairs per head
  p:branch("beq", "t0", "zero", "rot_done")
  p:op("addi t1, zero, 0")                    -- head
  p:label("rot_head")
  p:op("mul t2, t1, a3")                      -- where this head begins
  p:op("addi t3, zero, 0")                    -- pair
  p:label("rot_pair")
  p:op("slli t4, t3, 1")                      -- pair * 2, into the row of turns
  p:op("add t5, t2, t4")                      -- and into this head of the vector
  p:op("slli t6, t5, 2")
  p:op("add t6, a0, t6")
  p:op("flw ft0, 0(t6)")                      -- x
  p:op("flw ft1, 4(t6)")                      -- y
  p:op("slli a5, t4, 2")
  p:op("add a5, a1, a5")
  p:op("flw ft2, 0(a5)")                      -- cosine
  p:op("flw ft3, 4(a5)")                      -- sine
  p:op("fmul.s ft4, ft0, ft2")                -- x cos
  p:op("fmul.s ft5, ft1, ft3")                -- y sin
  p:op("fsub.s ft4, ft4, ft5")                -- x cos - y sin
  p:op("fmul.s ft6, ft0, ft3")                -- x sin
  p:op("fmul.s ft7, ft1, ft2")                -- y cos
  p:op("fadd.s ft6, ft6, ft7")                -- x sin + y cos
  p:op("fsw ft4, 0(t6)")
  p:op("fsw ft6, 4(t6)")
  p:op("addi t3, t3, 1")
  p:branch("blt", "t3", "t0", "rot_pair")
  p:op("addi t1, t1, 1")
  p:branch("blt", "t1", "a2", "rot_head")
  p:label("rot_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.attention_scores
--
-- void attention_scores(float *scores, const float *query, const float *keys,
--                       int count, int width, int stride, float scale)
--
-- scores a0, query a1, keys a2, count a3, width a4, stride a5, scale fa0.
--
-- How well this token's question matches each earlier token's answer. The
-- keys sit one position apart by the stride, because every layer and every
-- key head shares one array.
emitters.attention_scores = function(p)
  p:label("attention_scores")
  p:branch("bge", "zero", "a3", "asc_done")
  p:op("fmv.s ft7, fa0")                      -- keep the scale
  p:op("addi t0, zero, 0")                    -- which past position
  p:label("asc_pos")
  p:op("mul t1, t0, a5")                      -- position * stride
  p:op("slli t1, t1, 2")
  p:op("add t1, a2, t1")                      -- that position's keys
  p:op("fmv.w.x ft1, zero")                   -- running total
  p:op("addi t2, zero, 0")
  p:label("asc_dot")
  p:branch("bge", "t2", "a4", "asc_dot_done")
  p:op("slli t3, t2, 2")
  p:op("add t4, a1, t3")
  p:op("flw ft2, 0(t4)")
  p:op("add t5, t1, t3")
  p:op("flw ft3, 0(t5)")
  p:op("fmul.s ft2, ft2, ft3")
  p:op("fadd.s ft1, ft1, ft2")
  p:op("addi t2, t2, 1")
  p:jump("asc_dot")
  p:label("asc_dot_done")
  p:op("fmul.s ft1, ft1, ft7")                -- times the scale
  p:op("slli t3, t0, 2")
  p:op("add t4, a0, t3")
  p:op("fsw ft1, 0(t4)")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a3", "asc_pos")
  p:label("asc_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.attention_mix
--
-- void attention_mix(float *out, const float *weights, const float *values,
--                    int count, int width, int stride)
--
-- out a0, weights a1, values a2, count a3, width a4, stride a5.
--
-- What to carry forward: each earlier token's value, weighted by how well it
-- matched, accumulated in ascending order because that is the order the
-- specification names. The running total is read back out of the
-- destination each time rather than kept in a register, exactly as the other
-- two tongues do -- the operand order of that addition is part of the
-- answer.
emitters.attention_mix = function(p)
  p:label("attention_mix")
  p:branch("bge", "zero", "a4", "amx_done")
  p:op("addi t0, zero, 0")                    -- clear the destination first
  p:label("amx_clear")
  p:op("slli t1, t0, 2")
  p:op("add t2, a0, t1")
  p:op("sw zero, 0(t2)")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a4", "amx_clear")
  p:branch("bge", "zero", "a3", "amx_done")
  p:op("addi t0, zero, 0")                    -- which past position
  p:label("amx_pos")
  p:op("mul t1, t0, a5")
  p:op("slli t1, t1, 2")
  p:op("add t1, a2, t1")                      -- that position's values
  p:op("slli t2, t0, 2")
  p:op("add t2, a1, t2")
  p:op("flw ft0, 0(t2)")                      -- its weight
  p:op("addi t3, zero, 0")
  p:label("amx_inner")
  p:branch("bge", "t3", "a4", "amx_inner_done")
  p:op("slli t4, t3, 2")
  p:op("add t5, t1, t4")
  p:op("flw ft1, 0(t5)")
  p:op("fmul.s ft1, ft1, ft0")
  p:op("add t6, a0, t4")
  p:op("flw ft2, 0(t6)")
  p:op("fadd.s ft1, ft2, ft1")
  p:op("fsw ft1, 0(t6)")
  p:op("addi t3, t3, 1")
  p:jump("amx_inner")
  p:label("amx_inner_done")
  p:op("addi t0, t0, 1")
  p:branch("blt", "t0", "a3", "amx_pos")
  p:label("amx_done")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.exp_one -- built from the specification, not transcribed
--
-- float exp_one(float x)
--
-- The power arrives in fa0 and the answer comes back in fa0.
--
-- Its constants are COMPUTED from the specification rather than written
-- down. Writing the bit pattern of a polynomial coefficient by hand is how
-- the first architecture once got one digit wrong in a way nothing
-- downstream could have noticed.
--
-- The method is the specification's rather than a choice made here: turn
-- raising e to a power into raising two to a power, split that into a whole
-- part and a fraction, adjust the number's exponent field by the whole part
-- -- which is exact and free -- and approximate the fraction with a short
-- polynomial.
--
-- THIS ARCHITECTURE HAS NO FLOATING CONDITION FLAGS. The other two compare
-- and then branch on the result of the comparison. Here a comparison writes
-- a one or a zero into an ordinary register and the branch tests that. Same
-- meaning, including for a value that is not a number: the comparison
-- answers false, exactly as an unordered comparison does elsewhere.
emitters.exp_one = function(p, options)
  local specification = options.specification
  local float_bits = options.float_bits
  local series = specification.SERIES[specification.CHOSEN]

  local function constant(register, bits)
    -- load_constant refuses anything outside thirty-two bits, and every bit
    -- pattern here is exactly thirty-two -- but the top bit set makes it
    -- larger than a signed thirty-two bit number, so it is handed over as
    -- the negative it would be read as. The bits land identically.
    local value = bits
    if value > 2147483647 then value = value - 4294967296 end
    p:load_constant(register, value)
  end

  p:label("exp_one")

  -- clamp above: anything past the limit is the largest number there is
  constant("t0", float_bits.of(specification.LIMIT))
  p:op("fmv.w.x ft1, t0")
  p:op("fle.s t1, fa0, ft1")
  p:branch("bne", "t1", "zero", "exp_not_high")
  constant("t0", 0x7f7fffff)
  p:op("fmv.w.x fa0, t0")
  p:op("jalr zero, 0(ra)")
  p:label("exp_not_high")

  -- clamp below: anything past minus the limit is nothing
  constant("t0", float_bits.of(-specification.LIMIT))
  p:op("fmv.w.x ft1, t0")
  p:op("fle.s t1, ft1, fa0")
  p:branch("bne", "t1", "zero", "exp_not_low")
  p:op("fmv.w.x fa0, zero")
  p:op("jalr zero, 0(ra)")
  p:label("exp_not_low")

  -- how many powers of two, rounded to the nearest whole one
  constant("t0", specification.LOG2E_BITS)
  p:op("fmv.w.x ft1, t0")
  p:op("fmul.s ft2, fa0, ft1")
  p:op("fcvt.w.s t2, ft2, rne")               -- to nearest, ties to even
  p:op("fcvt.s.w ft3, t2")

  -- and what is left over
  constant("t0", specification.LN2_BITS)
  p:op("fmv.w.x ft1, t0")
  p:op("fmul.s ft3, ft3, ft1")
  p:op("fsub.s fa0, fa0, ft3")

  -- the series, nested: multiply by the leftover, add the next coefficient
  constant("t0", float_bits.of(series[1]))
  p:op("fmv.w.x ft4, t0")
  for index = 2, #series do
    constant("t0", float_bits.of(series[index]))
    p:op("fmv.w.x ft5, t0")
    p:op("fmul.s ft4, ft4, fa0")
    p:op("fadd.s ft4, ft4, ft5")
  end

  -- the powers of two, applied straight to the exponent field
  p:op("addi t2, t2, 127")
  p:op("addi t3, zero, 1")
  p:branch("bge", "t2", "t3", "exp_not_under")
  p:op("fmv.w.x fa0, zero")                   -- underflowed to nothing
  p:op("jalr zero, 0(ra)")
  p:label("exp_not_under")
  p:op("addi t3, zero, 254")
  p:branch("bge", "t3", "t2", "exp_in_range")
  constant("t0", 0x7f7fffff)
  p:op("fmv.w.x fa0, t0")
  p:op("jalr zero, 0(ra)")
  p:label("exp_in_range")
  p:op("slli t2, t2, 23")
  p:op("fmv.w.x ft5, t2")
  p:op("fmul.s ft4, ft4, ft5")
  p:op("fmv.s fa0, ft4")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.softmax
--
-- void softmax(float *values, int count)
--
-- values a0, count a1. Turns scores into weights adding to one, in place.
--
-- The largest is taken off first. That changes nothing about the answer and
-- stops the exponentials running away -- and because it is done, every
-- argument handed to the exponential is zero or negative, which is the range
-- it is most accurate over.
--
-- THIS ONE CALLS SOMETHING, which is what makes it different from every
-- routine above. Anything that must survive a call goes in the registers the
-- convention obliges a callee to give back -- including the floating ones,
-- which are easy to forget because the integer ones are the famous half. The
-- return address is one of the things that must survive, and losing it is
-- not a wrong answer but a machine that never comes back.
emitters.softmax = function(p)
  p:label("softmax")
  p:branch("bge", "zero", "a1", "sm_return")
  p:op("addi sp, sp, -64")
  p:op("sd ra, 0(sp)")
  p:op("sd s0, 8(sp)")
  p:op("sd s1, 16(sp)")
  p:op("sd s2, 24(sp)")
  p:op("fsd fs0, 32(sp)")
  p:op("fsd fs1, 40(sp)")

  p:op("mv s0, a0")                           -- the values
  p:op("mv s1, a1")                           -- how many

  p:op("flw fs0, 0(s0)")                      -- the largest, kept across calls
  p:op("addi s2, zero, 1")
  p:label("sm_max")
  p:branch("bge", "s2", "s1", "sm_max_done")
  p:op("slli t0, s2, 2")
  p:op("add t1, s0, t0")
  p:op("flw ft1, 0(t1)")
  p:op("fle.s t2, ft1, fs0")
  p:branch("bne", "t2", "zero", "sm_max_next")
  p:op("fmv.s fs0, ft1")
  p:label("sm_max_next")
  p:op("addi s2, s2, 1")
  p:jump("sm_max")
  p:label("sm_max_done")

  p:op("fmv.w.x fs1, zero")                   -- the running total, kept too
  p:op("addi s2, zero, 0")
  p:label("sm_exp")
  p:branch("bge", "s2", "s1", "sm_exp_done")
  p:op("slli t0, s2, 2")
  p:op("add t1, s0, t0")
  p:op("flw fa0, 0(t1)")
  p:op("fsub.s fa0, fa0, fs0")
  p:call("exp_one")
  p:op("slli t0, s2, 2")
  p:op("add t1, s0, t0")
  p:op("fsw fa0, 0(t1)")
  p:op("fadd.s fs1, fs1, fa0")
  p:op("addi s2, s2, 1")
  p:jump("sm_exp")
  p:label("sm_exp_done")

  p:op("addi s2, zero, 0")
  p:label("sm_div")
  p:branch("bge", "s2", "s1", "sm_div_done")
  p:op("slli t0, s2, 2")
  p:op("add t1, s0, t0")
  p:op("flw ft0, 0(t1)")
  p:op("fdiv.s ft0, ft0, fs1")
  p:op("fsw ft0, 0(t1)")
  p:op("addi s2, s2, 1")
  p:jump("sm_div")
  p:label("sm_div_done")

  p:op("fld fs1, 40(sp)")
  p:op("fld fs0, 32(sp)")
  p:op("ld s2, 24(sp)")
  p:op("ld s1, 16(sp)")
  p:op("ld s0, 8(sp)")
  p:op("ld ra, 0(sp)")
  p:op("addi sp, sp, 64")
  p:label("sm_return")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ emitters.swiglu
--
-- void swiglu(float *gate, const float *up, int count)
--
-- gate a0, up a1, count a2.
--
-- The gate decides how much of each position passes, on a curve smooth
-- everywhere rather than a hard cutoff, and what passes is multiplied by the
-- other half.
--
-- The negation is written as a subtraction from zero rather than as a negate
-- instruction, to match the first architecture exactly: the two differ in
-- the sign of zero, and a specification that is exact everywhere else should
-- not be approximate there.
emitters.swiglu = function(p)
  p:label("swiglu")
  p:branch("bge", "zero", "a2", "sw_return")
  p:op("addi sp, sp, -64")
  p:op("sd ra, 0(sp)")
  p:op("sd s0, 8(sp)")
  p:op("sd s1, 16(sp)")
  p:op("sd s2, 24(sp)")
  p:op("sd s3, 32(sp)")
  p:op("fsd fs0, 40(sp)")

  p:op("mv s0, a0")                           -- the gate
  p:op("mv s1, a1")                           -- the other half
  p:op("mv s2, a2")                           -- how many
  p:op("addi s3, zero, 0")
  p:label("sw_loop")
  p:branch("bge", "s3", "s2", "sw_done")
  p:op("slli t0, s3, 2")
  p:op("add t1, s0, t0")
  p:op("flw fs0, 0(t1)")                      -- the value, wanted after the call
  p:op("fmv.w.x fa0, zero")
  p:op("fsub.s fa0, fa0, fs0")                -- minus the value
  p:call("exp_one")
  p:load_constant("t0", 0x3f800000)           -- one
  p:op("fmv.w.x ft1, t0")
  p:op("fadd.s fa0, fa0, ft1")                -- one plus e to minus the value
  p:op("fdiv.s fa0, fs0, fa0")                -- how much passes
  p:op("slli t0, s3, 2")
  p:op("add t1, s1, t0")
  p:op("flw ft1, 0(t1)")
  p:op("fmul.s fa0, fa0, ft1")                -- times the other half
  p:op("add t1, s0, t0")
  p:op("fsw fa0, 0(t1)")
  p:op("addi s3, s3, 1")
  p:jump("sw_loop")
  p:label("sw_done")

  p:op("fld fs0, 40(sp)")
  p:op("ld s3, 32(sp)")
  p:op("ld s2, 24(sp)")
  p:op("ld s1, 16(sp)")
  p:op("ld s0, 8(sp)")
  p:op("ld ra, 0(sp)")
  p:op("addi sp, sp, 64")
  p:label("sw_return")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ M.emit(p, names, options)
-- Lay every named routine into a program being built. Unlike the other two
-- tongues this returns nothing: the routines become part of one program,
-- because the emitter must see every instruction to count the distances.
function M.emit(p, names, options)
  for _, name in ipairs(names or M.written) do
    local emitter = emitters[name]
    if not emitter then
      error("111-kernels-riscv64: nothing written for '" .. tostring(name)
            .. "', and M.written says otherwise")
    end
    emitter(p, options or {})
  end
end
-- }}}

return M
