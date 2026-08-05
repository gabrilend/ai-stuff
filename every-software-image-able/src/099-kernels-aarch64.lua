-- 099-kernels-aarch64.lua
--
-- The arithmetic in the second tongue. Issue 401, the half that ports almost
-- mechanically -- and "almost" is where the work is.
--
-- For a general: the same innermost loops the machine already has, written
-- again in a different processor's instructions. The test of a port is not
-- that it looks right; it is that it produces the same numbers, bit for bit,
-- as the first one did -- and the fixture that made that testable was built
-- in 103 for exactly this moment.
--
-- WHY IT IS A SEPARATE FILE FROM 043. That file holds the first tongue and
-- is already long. A second architecture in the same file would mean every
-- reader of either wading through both, and the emitter dispatches on
-- architecture anyway. Adding a third is adding a third file.
--
-- WHAT PORTS MECHANICALLY AND WHAT DOES NOT. The plain arithmetic is a
-- translation: multiply, add, compare, branch, all present on both. The
-- registers are more numerous here, which makes some of the shuffling the
-- first tongue needed unnecessary -- and removing it would change the answer,
-- so it is kept. Every accumulation is single precision in ascending index
-- order, because that is the specification and not merely what fell out.
--
-- THE ORDER OF ADDITION IS THE SPECIFICATION. This architecture has
-- instructions that would sum four numbers in one step, and they are not
-- used, for the same reason the first tongue's wide kernel keeps one running
-- accumulator: floating-point addition is not associative, and a faster
-- answer that differs in the last bit is a different specification rather
-- than a better implementation of this one.
--
-- The calling convention here puts the first arguments in x0, x1, x2, then
-- w3, w4, and floating arguments in s0 -- which is what the bundled patterns
-- say (083), so everything the machine writes later agrees with this.

local M = {}

-- {{{ M.matrix_vector_plain
--
-- void matrix_vector_plain(float *out, const float *matrix,
--                          const float *input, int rows, int columns)
--
-- out x0, matrix x1, input x2, rows w3, columns w4.
M.matrix_vector_plain = [[
  .globl matrix_vector_plain
  .type matrix_vector_plain, @function
matrix_vector_plain:
  cmp w3, #0
  b.le 9f                       // no rows: nothing to do, and not an error
  mov w5, #0                    // row
1:
  fmov s0, wzr                  // running total for this row
  mul w6, w5, w4                // row * columns
  add x6, x1, w6, sxtw #2       // where this row begins
  mov w7, #0                    // column
  cmp w4, #0
  b.le 3f                       // a row of no columns totals zero
2:
  ldr s1, [x6, w7, sxtw #2]
  ldr s2, [x2, w7, sxtw #2]
  fmul s1, s1, s2
  fadd s0, s0, s1
  add w7, w7, #1
  cmp w7, w4
  b.lt 2b
3:
  str s0, [x0, w5, sxtw #2]
  add w5, w5, #1
  cmp w5, w3
  b.lt 1b
9:
  ret
]]
-- }}}

-- {{{ M.matrix_vector_wide -- four at a time
--
-- The same answer, reading four numbers per step. The four products are
-- folded into ONE running total in the same order the plain version would,
-- rather than summed with the instruction that adds a whole vector together
-- -- which would be faster and would give a different answer.
--
-- The lane extraction is by index here rather than by rotating the register,
-- which is what the first tongue had to do. Same order, fewer instructions,
-- identical result.
M.matrix_vector_wide = [[
  .globl matrix_vector_wide
  .type matrix_vector_wide, @function
matrix_vector_wide:
  cmp w3, #0
  b.le 9f
  mov w5, #0                    // row
1:
  fmov s0, wzr                  // running total
  mul w6, w5, w4
  add x6, x1, w6, sxtw #2       // where this row begins
  mov w7, #0                    // column

  and w8, w4, #-4               // columns that fit in whole groups of four
  cmp w8, #0
  b.le 3f
2:
  add x9, x6, w7, sxtw #2
  ldr q1, [x9]                  // four from the row
  add x9, x2, w7, sxtw #2
  ldr q2, [x9]                  // four from the input
  fmul v1.4s, v1.4s, v2.4s      // four products at once

  // fold them in, in order. NOT faddv, which sums the vector in an order
  // the plain version never uses.
  mov s3, v1.s[0]
  fadd s0, s0, s3
  mov s3, v1.s[1]
  fadd s0, s0, s3
  mov s3, v1.s[2]
  fadd s0, s0, s3
  mov s3, v1.s[3]
  fadd s0, s0, s3

  add w7, w7, #4
  cmp w7, w8
  b.lt 2b
3:
  cmp w7, w4                    // the remainder, one at a time
  b.ge 5f
4:
  ldr s1, [x6, w7, sxtw #2]
  ldr s2, [x2, w7, sxtw #2]
  fmul s1, s1, s2
  fadd s0, s0, s1
  add w7, w7, #1
  cmp w7, w4
  b.lt 4b
5:
  str s0, [x0, w5, sxtw #2]
  add w5, w5, #1
  cmp w5, w3
  b.lt 1b
9:
  ret
]]
-- }}}

-- {{{ M.matrix_vector_fast -- four independent totals
--
-- The same operation as the two above and DELIBERATELY NOT THE SAME ANSWER.
--
-- The exact kernel folds each group of four products into ONE running total,
-- in order, so its answer is identical on every machine that has ever run
-- it. That ordering is what costs the speed: every addition waits for the
-- one before it, and the adder sits idle in between. This keeps FOUR totals,
-- one per lane, and never makes them wait for each other -- which is what
-- the vector hardware was built to do.
--
-- SO THIS IS A SECOND SPECIFICATION, not a faster implementation of the
-- first. It is never compared against the exact one. It is compared against
-- the first architecture's fast kernel, bit for bit, exactly as everything
-- else here is -- and that comparison is the whole reason `103` wrote the
-- second specification down rather than leaving it as "whatever is quick".
--
-- WHY IT WAS MISSING UNTIL NOW, which is worth more than the kernel. The
-- first tongue has eleven routines and this file had ten. Nothing said so:
-- the list of what is absent was a hand-kept table that had been emptied,
-- and the test that was meant to notice compared against a literal ten
-- rather than against what the first tongue actually has. Both agreed, and
-- both were wrong. The port that resulted had the routine that proves
-- correctness and not the one that provides the speed.
--
-- THE FINAL COMBINING IS SPECIFIED RATHER THAN INCIDENTAL, because a
-- different reduction order is a different answer again:
--     lane0 += lane2, lane1 += lane3, then lane0 += lane1
-- and any remaining columns are folded in one at a time AFTERWARDS. All four
-- lanes are read out before any of them is written back, because the
-- accumulator's low lane and the register the total ends up in are the same
-- thirty-two bits.
M.matrix_vector_fast = [[
  .globl matrix_vector_fast
  .type matrix_vector_fast, @function
matrix_vector_fast:
  cmp w3, #0
  b.le 9f
  mov w5, #0                    // row
1:
  movi v0.4s, #0                // four running totals, one per lane
  mul w6, w5, w4
  add x6, x1, w6, sxtw #2       // where this row begins
  mov w7, #0                    // column

  and w8, w4, #-4               // columns that fit in whole groups of four
  cmp w8, #0
  b.le 3f
2:
  add x9, x6, w7, sxtw #2
  ldr q1, [x9]                  // four from the row
  add x9, x2, w7, sxtw #2
  ldr q2, [x9]                  // four from the input
  fmul v1.4s, v1.4s, v2.4s
  fadd v0.4s, v0.4s, v1.4s      // straight into the four totals, none
                                // waiting on another -- the one instruction
                                // the exact kernel cannot use
  add w7, w7, #4
  cmp w7, w8
  b.lt 2b
3:
  mov s1, v0.s[0]
  mov s2, v0.s[1]
  mov s3, v0.s[2]
  mov s4, v0.s[3]
  fadd s1, s1, s3               // lane0 += lane2
  fadd s2, s2, s4               // lane1 += lane3
  fadd s0, s1, s2               // and the two halves together

  cmp w7, w4                    // whatever did not fit in a group of four
  b.ge 5f
4:
  ldr s1, [x6, w7, sxtw #2]
  ldr s2, [x2, w7, sxtw #2]
  fmul s1, s1, s2
  fadd s0, s0, s1
  add w7, w7, #1
  cmp w7, w4
  b.lt 4b
5:
  str s0, [x0, w5, sxtw #2]
  add w5, w5, #1
  cmp w5, w3
  b.lt 1b
9:
  ret
]]
-- }}}

-- {{{ M.matrix_vector_quantised -- weights at four bits, unpacked as it goes
--
-- void matrix_vector_quantised(float *out, const unsigned char *matrix,
--                              const float *input, int rows, int columns)
--
-- out x0, matrix x1, input x2, rows w3, columns w4.
--
-- A FOURTH SPECIFICATION, not a smaller version of the three above. The
-- weights it reads have already lost information and its answer is different
-- on purpose, so it is never compared against the exact product. It is held
-- to `123`, the readable specification, and to the other two architectures.
--
-- THE SCALE IS UNPACKED IN WHOLE-NUMBER ARITHMETIC, and this architecture is
-- the one that makes that look like a waste -- it has a half-to-single
-- conversion instruction sitting right there. It is not used. The first
-- architecture's equivalent is an optional extension a given chip may not
-- have, and the third's base instruction set has no half-precision at all,
-- so borrowing the instruction here would mean this architecture's answer
-- came from hardware the others must imitate. Three implementations agreeing
-- is the point; one of them taking a shortcut the others cannot is how they
-- stop.
--
-- The unpacking is the same three steps everywhere: shift the pattern up
-- thirteen places so its mantissa lands where a single precision mantissa
-- goes, add the difference between the two exponent biases, and -- only when
-- the exponent field was zero -- take one step into the normal range and
-- subtract it off again, which resolves a subnormal without counting leading
-- zeroes. A scale is never negative and never infinite, because the
-- quantiser takes a magnitude and saturates, so neither case is written.
--
-- TWO WEIGHTS PER PASS, and not for speed: choosing a half of a byte by
-- testing an index would put a branch in the innermost loop of the machine,
-- and taking the low half then the high half needs no test at all.
M.matrix_vector_quantised = [[
  .globl matrix_vector_quantised
  .type matrix_vector_quantised, @function
matrix_vector_quantised:
  cmp w3, #0
  b.le 9f                       // no rows: nothing to do, and not an error

  // the three patterns the scale's unpacking needs, built once
  movz w15, #0x0000
  movk w15, #0x0f80, lsl #16    // where the exponent field sits after shifting
  movz w16, #0x0000
  movk w16, #0x3800, lsl #16    // the two biases differ by this much
  movz w17, #0x0000
  movk w17, #0x0080, lsl #16    // one step into the normal range
  movz w13, #0x0000
  movk w13, #0x3880, lsl #16
  fmov s7, w13                  // and that step as a number, to take back off

  mov w5, #0                    // row
1:
  fmov s0, wzr                  // running total for this row
  lsr w6, w4, #5                // blocks in a row: columns / 32
  mul w7, w5, w6                // rows of blocks before this one
  mov w8, #18
  mul w7, w7, w8                // and eighteen bytes to a block
  add x9, x1, w7, sxtw          // where this row's bytes begin
  mov w10, #0                   // column
  cmp w4, #0
  b.le 5f                       // a row of no columns totals zero
2:
  // the scale, out of two bytes and into a single precision register
  ldrh w11, [x9]
  lsl w11, w11, #13
  and w12, w11, w15             // the exponent field, where it now sits
  add w11, w11, w16
  cbnz w12, 3f
  add w11, w11, w17             // a step into the normal range
  fmov s1, w11
  fsub s1, s1, s7               // and the same step, taken back off
  b 4f
3:
  fmov s1, w11
4:
  mov w14, #0                   // which byte of the sixteen
6:
  add x18, x9, w14, sxtw
  ldrb w11, [x18, #2]           // two weights

  and w12, w11, #15             // the earlier one is the low half
  sub w12, w12, #8              // eight stands for nothing
  scvtf s2, w12
  fmul s2, s2, s1               // times the block's scale
  ldr s3, [x2, w10, sxtw #2]
  fmul s2, s2, s3               // times what it meets
  fadd s0, s0, s2               // ascending order, as everywhere else
  add w10, w10, #1

  lsr w12, w11, #4              // and the later one is the high half
  sub w12, w12, #8
  scvtf s2, w12
  fmul s2, s2, s1
  ldr s3, [x2, w10, sxtw #2]
  fmul s2, s2, s3
  fadd s0, s0, s2
  add w10, w10, #1

  add w14, w14, #1
  cmp w14, #16
  b.lt 6b

  add x9, x9, #18               // the next block
  cmp w10, w4
  b.lt 2b
5:
  str s0, [x0, w5, sxtw #2]
  add w5, w5, #1
  cmp w5, w3
  b.lt 1b
9:
  ret
]]
-- }}}

-- {{{ M.rms_normalise
--
-- void rms_normalise(float *out, const float *input, const float *weight,
--                    int size, float epsilon)
--
-- out x0, input x1, weight x2, size w3, epsilon s0.
--
-- The value one is built in a register rather than loaded from anywhere: a
-- constant in memory needs a symbol reference, and a symbol reference in
-- this project is a note for a linker that nothing reads.
M.rms_normalise = [[
  .globl rms_normalise
  .type rms_normalise, @function
rms_normalise:
  fmov s5, s0                   // keep epsilon before the accumulator wants s0
  cmp w3, #0
  b.le 9f
  fmov s0, wzr                  // sum of squares
  mov w4, #0
1:
  ldr s1, [x1, w4, sxtw #2]
  fmul s1, s1, s1
  fadd s0, s0, s1
  add w4, w4, #1
  cmp w4, w3
  b.lt 1b

  scvtf s2, w3                  // how many numbers there were
  fdiv s0, s0, s2               // the mean of the squares
  fadd s0, s0, s5               // plus the small constant
  fsqrt s0, s0
  mov w4, #0x3f800000           // the bits of one, built rather than fetched
  fmov s4, w4
  fdiv s4, s4, s0               // the scale to apply
  fmov s0, s4

  mov w4, #0
2:
  ldr s1, [x1, w4, sxtw #2]
  fmul s1, s1, s0
  ldr s2, [x2, w4, sxtw #2]
  fmul s1, s1, s2
  str s1, [x0, w4, sxtw #2]
  add w4, w4, #1
  cmp w4, w3
  b.lt 2b
9:
  ret
]]
-- }}}

-- {{{ local function constant(register, bits)
-- A whole 32-bit pattern into a register, sixteen bits at a time.
--
-- There is no instruction that puts an arbitrary 32-bit number into a
-- register in one go, and there is no loading it from memory either -- a
-- constant in memory needs a name, and a name in a payload is a note for a
-- linker that nothing reads. So it is built: one instruction sets the low
-- half and clears the rest, a second sets the high half and keeps the rest.
local function constant(register, bits)
  local low = bits % 0x10000
  local high = math.floor(bits / 0x10000) % 0x10000
  return {
    string.format("  movz %s, #0x%x", register, low),
    string.format("  movk %s, #0x%x, lsl #16", register, high),
  }
end
-- }}}

-- {{{ M.add_into
--
-- void add_into(float *destination, const float *addend, int count)
--
-- destination x0, addend x1, count w2.
--
-- What carries a token's meaning past a layer rather than through it.
M.add_into = [[
  .globl add_into
  .type add_into, @function
add_into:
  cmp w2, #0
  b.le 9f
  mov w3, #0
1:
  ldr s0, [x0, w3, sxtw #2]
  ldr s1, [x1, w3, sxtw #2]
  fadd s0, s0, s1
  str s0, [x0, w3, sxtw #2]
  add w3, w3, #1
  cmp w3, w2
  b.lt 1b
9:
  ret
]]
-- }}}

-- {{{ M.rotate
--
-- void rotate(float *vec, const float *turns, int heads, int head_width)
--
-- vec x0, turns x1, heads w2, head_width w3.
--
-- Turns each pair of numbers in each head by the angle for this position,
-- reading the cosine and sine from the carried table rather than computing
-- them -- which is why this kernel is built from multiplication and addition
-- alone, and can therefore be required to match exactly.
M.rotate = [[
  .globl rotate
  .type rotate, @function
rotate:
  cmp w2, #0
  b.le 9f
  cmp w3, #0
  b.le 9f
  lsr w4, w3, #1                // pairs per head
  cbz w4, 9f
  mov w5, #0                    // head
1:
  mul w6, w5, w3                // where this head begins
  mov w7, #0                    // pair
2:
  lsl w8, w7, #1                // pair * 2, into the row of turns
  add w9, w6, w8                // and into this head of the vector
  add w10, w9, #1
  add w11, w8, #1

  ldr s0, [x0, w9, sxtw #2]     // x
  ldr s1, [x0, w10, sxtw #2]    // y
  ldr s2, [x1, w8, sxtw #2]     // cosine
  ldr s3, [x1, w11, sxtw #2]    // sine

  fmul s4, s0, s2               // x cos
  fmul s5, s1, s3               // y sin
  fsub s4, s4, s5               // x cos - y sin
  fmul s6, s0, s3               // x sin
  fmul s7, s1, s2               // y cos
  fadd s6, s6, s7               // x sin + y cos

  str s4, [x0, w9, sxtw #2]
  str s6, [x0, w10, sxtw #2]

  add w7, w7, #1
  cmp w7, w4
  b.lt 2b
  add w5, w5, #1
  cmp w5, w2
  b.lt 1b
9:
  ret
]]
-- }}}

-- {{{ M.attention_scores
--
-- void attention_scores(float *scores, const float *query, const float *keys,
--                       int count, int width, int stride, float scale)
--
-- scores x0, query x1, keys x2, count w3, width w4, stride w5, scale s0.
--
-- How well this token's question matches each earlier token's answer. The
-- keys sit one position apart by the stride, because every layer and every
-- key head shares one array.
M.attention_scores = [[
  .globl attention_scores
  .type attention_scores, @function
attention_scores:
  cmp w3, #0
  b.le 9f
  fmov s7, s0                   // keep the scale; s0 is wanted for totals
  mov w6, #0                    // which past position
1:
  mul w7, w6, w5                // position * stride
  add x8, x2, w7, sxtw #2       // that position's keys
  fmov s1, wzr                  // running total
  mov w9, #0
2:
  cmp w9, w4
  b.ge 3f
  ldr s2, [x1, w9, sxtw #2]
  ldr s3, [x8, w9, sxtw #2]
  fmul s2, s2, s3
  fadd s1, s1, s2
  add w9, w9, #1
  b 2b
3:
  fmul s1, s1, s7               // times the scale
  str s1, [x0, w6, sxtw #2]
  add w6, w6, #1
  cmp w6, w3
  b.lt 1b
9:
  ret
]]
-- }}}

-- {{{ M.attention_mix
--
-- void attention_mix(float *out, const float *weights, const float *values,
--                    int count, int width, int stride)
--
-- out x0, weights x1, values x2, count w3, width w4, stride w5.
--
-- What to carry forward: each earlier token's value, weighted by how well it
-- matched, accumulated in ascending order because that is the order the
-- specification names.
M.attention_mix = [[
  .globl attention_mix
  .type attention_mix, @function
attention_mix:
  cmp w4, #0
  b.le 9f
  mov w6, #0                    // clear the destination first
1:
  str wzr, [x0, w6, sxtw #2]
  add w6, w6, #1
  cmp w6, w4
  b.lt 1b
  cmp w3, #0
  b.le 9f
  mov w6, #0                    // which past position
2:
  mul w7, w6, w5
  add x8, x2, w7, sxtw #2       // that position's values
  ldr s0, [x1, w6, sxtw #2]     // its weight
  mov w9, #0
3:
  cmp w9, w4
  b.ge 4f
  ldr s1, [x8, w9, sxtw #2]
  fmul s1, s1, s0
  ldr s2, [x0, w9, sxtw #2]
  fadd s1, s2, s1
  str s1, [x0, w9, sxtw #2]
  add w9, w9, #1
  b 3b
4:
  add w6, w6, #1
  cmp w6, w3
  b.lt 2b
9:
  ret
]]
-- }}}

-- {{{ M.build_exp(specification)
--
-- float exp_one(float x)
--
-- The power arrives in s0 and the answer comes back in s0.
--
-- Built by a function rather than held as text, because its constants are
-- COMPUTED from the specification rather than transcribed. Writing the bit
-- pattern of a polynomial coefficient by hand is how the first architecture
-- once got one digit wrong in a way nothing downstream could have noticed.
--
-- The method, and it is the specification's rather than a choice made here:
-- turn raising e to a power into raising two to a power, split that into a
-- whole part and a fraction, adjust the number's exponent field by the whole
-- part -- which is exact and free -- and approximate the fraction with a
-- short polynomial.
--
-- Everything in it is multiplication and addition, which is what lets an
-- exponential be required to match another machine's exactly. Borrowing the
-- host language's exponential instead would have made every softmax in the
-- engine incomparable between architectures.
function M.build_exp(specification, float_bits)
  local series = specification.SERIES[specification.CHOSEN]
  local body = {}
  local function line(text) body[#body + 1] = text end
  local function put(register, bits)
    for _, instruction in ipairs(constant(register, bits)) do line(instruction) end
  end

  line("  .globl exp_one")
  line("  .type exp_one, @function")
  line("exp_one:")

  -- clamp above: anything past the limit is the largest number there is
  put("w1", float_bits.of(specification.LIMIT))
  line("  fmov s1, w1")
  line("  fcmp s0, s1")
  line("  b.le 1f")
  put("w1", 0x7f7fffff)
  line("  fmov s0, w1")
  line("  ret")
  line("1:")

  -- clamp below: anything past minus the limit is nothing
  put("w1", float_bits.of(-specification.LIMIT))
  line("  fmov s1, w1")
  line("  fcmp s0, s1")
  line("  b.ge 2f")
  line("  fmov s0, wzr")
  line("  ret")
  line("2:")

  -- how many powers of two, rounded to the nearest whole one
  put("w1", specification.LOG2E_BITS)
  line("  fmov s1, w1")
  line("  fmul s2, s0, s1")
  line("  fcvtns w2, s2")             -- to nearest, ties to even, as the first
  line("  scvtf s3, w2")

  -- and what is left over
  put("w1", specification.LN2_BITS)
  line("  fmov s1, w1")
  line("  fmul s3, s3, s1")
  line("  fsub s0, s0, s3")

  -- the series, nested: multiply by the leftover, add the next coefficient
  put("w1", float_bits.of(series[1]))
  line("  fmov s4, w1")
  for index = 2, #series do
    put("w1", float_bits.of(series[index]))
    line("  fmov s5, w1")
    line("  fmul s4, s4, s0")
    line("  fadd s4, s4, s5")
  end

  -- the powers of two, applied straight to the exponent field
  line("  add w2, w2, #127")
  line("  cmp w2, #1")
  line("  b.ge 3f")
  line("  fmov s0, wzr")              -- underflowed to nothing
  line("  ret")
  line("3:")
  line("  cmp w2, #254")
  line("  b.le 4f")
  put("w1", 0x7f7fffff)
  line("  fmov s0, w1")
  line("  ret")
  line("4:")
  line("  lsl w2, w2, #23")
  line("  fmov s5, w2")
  line("  fmul s4, s4, s5")
  line("  fmov s0, s4")
  line("  ret")
  line("")

  return table.concat(body, "\n")
end
-- }}}

-- {{{ M.softmax
--
-- void softmax(float *values, int count)
--
-- values x0, count w1. Turns scores into weights adding to one, in place.
--
-- The largest is taken off first. That changes nothing about the answer and
-- stops the exponentials running away -- and because it is done, every
-- argument handed to the exponential is zero or negative, which is the range
-- it is most accurate over.
--
-- THIS ONE CALLS SOMETHING, which is what makes it different from every
-- kernel above. Anything that must survive a call goes in the registers the
-- convention obliges a callee to give back -- including the floating ones,
-- which are easy to forget because the integer ones are the famous half.
M.softmax = [[
  .globl softmax
  .type softmax, @function
softmax:
  cmp w1, #0
  b.le 9f
  stp x29, x30, [sp, #-64]!
  mov x29, sp
  stp x19, x20, [sp, #16]
  stp x21, x22, [sp, #32]
  stp d8, d9, [sp, #48]

  mov x19, x0                   // the values
  mov w20, w1                   // how many

  ldr s8, [x19]                 // the largest, kept across calls
  mov w21, #1
1:
  cmp w21, w20
  b.ge 2f
  ldr s1, [x19, w21, sxtw #2]
  fcmp s1, s8
  b.le 11f
  fmov s8, s1
11:
  add w21, w21, #1
  b 1b
2:
  fmov s9, wzr                  // the running total, kept across calls
  mov w22, #0
3:
  cmp w22, w20
  b.ge 4f
  ldr s0, [x19, w22, sxtw #2]
  fsub s0, s0, s8
  bl exp_one
  str s0, [x19, w22, sxtw #2]
  fadd s9, s9, s0
  add w22, w22, #1
  b 3b
4:
  mov w22, #0
5:
  cmp w22, w20
  b.ge 6f
  ldr s0, [x19, w22, sxtw #2]
  fdiv s0, s0, s9
  str s0, [x19, w22, sxtw #2]
  add w22, w22, #1
  b 5b
6:
  ldp d8, d9, [sp, #48]
  ldp x21, x22, [sp, #32]
  ldp x19, x20, [sp, #16]
  ldp x29, x30, [sp], #64
9:
  ret
]]
-- }}}

-- {{{ M.swiglu
--
-- void swiglu(float *gate, const float *up, int count)
--
-- gate x0, up x1, count w2.
--
-- The gate decides how much of each position passes, on a curve smooth
-- everywhere rather than a hard cutoff, and what passes is multiplied by the
-- other half.
--
-- The negation is written as a subtraction from zero rather than as a negate
-- instruction, to match the first architecture exactly: the two differ in
-- the sign of zero, and a specification that is exact everywhere else should
-- not be approximate there.
M.swiglu = [[
  .globl swiglu
  .type swiglu, @function
swiglu:
  cmp w2, #0
  b.le 9f
  stp x29, x30, [sp, #-64]!
  mov x29, sp
  stp x19, x20, [sp, #16]
  stp x21, x22, [sp, #32]
  stp d8, d9, [sp, #48]

  mov x19, x0
  mov x20, x1
  mov w21, w2
  mov w22, #0
1:
  cmp w22, w21
  b.ge 2f
  ldr s8, [x19, w22, sxtw #2]   // the value itself, wanted after the call
  fmov s0, wzr
  fsub s0, s0, s8               // minus the value
  bl exp_one
  movz w1, #0x0
  movk w1, #0x3f80, lsl #16     // one
  fmov s1, w1
  fadd s0, s0, s1               // one plus e to minus the value
  fdiv s0, s8, s0               // how much passes
  ldr s1, [x20, w22, sxtw #2]
  fmul s0, s0, s1               // times the other half
  str s0, [x19, w22, sxtw #2]
  add w22, w22, #1
  b 1b
2:
  ldp d8, d9, [sp, #48]
  ldp x21, x22, [sp, #32]
  ldp x19, x20, [sp, #16]
  ldp x29, x30, [sp], #64
9:
  ret
]]
-- }}}

-- {{{ M.source(names)
-- Everything written so far, in one assembler file.
function M.source(names, specification, float_bits)
  local parts = { "  .text" }
  for _, name in ipairs(names or M.written) do
    if name == "exp_one" then
      if specification and float_bits then
        parts[#parts + 1] = M.build_exp(specification, float_bits)
      end
    elseif M[name] then
      parts[#parts + 1] = M[name]
    end
  end
  parts[#parts + 1] = '  .section .note.GNU-stack,"",@progbits'
  parts[#parts + 1] = ""
  return table.concat(parts, "\n")
end
-- }}}

-- {{{ M.written -- what exists here, so a test can ask rather than be told
--
-- The exponential comes before the two that call it, because the assembler
-- resolves a call to something it has already seen and this file is emitted
-- in order.
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
-- than remembered.
--
-- There was a hand-kept table here called `not_written_yet`, holding the
-- names still to be done. It was emptied when the port felt finished and
-- then said nothing ever again -- while the first tongue quietly had one
-- more routine than this file did. The test that was supposed to catch that
-- compared the count against a literal ten, so the stale table and the stale
-- test agreed with each other and the missing routine was the fast matrix
-- product: the one that provides all of the speed.
--
-- A port that quietly covers less than the first tongue is a port that looks
-- finished, which is what the emptied table said in its own comment while
-- being the reason it happened. So nothing is remembered now. The caller
-- hands over the first tongue's list and this returns the difference.
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

return M
