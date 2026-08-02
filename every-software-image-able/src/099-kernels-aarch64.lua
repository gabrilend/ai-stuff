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

-- {{{ M.source(names)
-- Everything written so far, in one assembler file.
function M.source(names)
  local parts = { "  .text" }
  for _, name in ipairs(names or { "matrix_vector_plain", "matrix_vector_wide",
                                   "rms_normalise" }) do
    if M[name] then parts[#parts + 1] = M[name] end
  end
  parts[#parts + 1] = '  .section .note.GNU-stack,"",@progbits'
  parts[#parts + 1] = ""
  return table.concat(parts, "\n")
end
-- }}}

-- {{{ M.written -- what exists here, so a test can ask rather than be told
--
-- Six of the nine are not written yet. Named rather than omitted, because a
-- port that quietly covers less than the first tongue is a port that looks
-- finished.
M.written = { "matrix_vector_plain", "matrix_vector_wide", "rms_normalise" }

M.not_written_yet = {
  "exp_one", "softmax", "swiglu", "rotate", "attention_scores",
  "attention_mix", "add_into",
}
-- }}}

return M
