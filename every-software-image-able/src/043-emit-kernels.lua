-- 043-emit-kernels.lua
--
-- The arithmetic, in assembly. Generated rather than written, like everything
-- else here, so a second architecture is a second table rather than a second
-- file to keep in step.
--
-- For a general: this writes the innermost loops of the model's arithmetic in
-- the processor's own instructions. Almost all of a machine's thinking time is
-- spent inside these few loops, which is why they are the only part written
-- this close to the metal.
--
-- WHY THESE TWO AND NO OTHERS. They are built from multiplication, addition
-- and square root alone. Those three are exactly specified, so an assembly
-- version can be required to match the reference *bit for bit* rather than
-- approximately -- and a comparison that admits "close enough" turns every
-- future disagreement into a judgement call. Everything else in a forward pass
-- passes through an exponential, a sine or a cosine, none of which agree
-- between implementations.
--
-- WHY THEY TAKE POINTERS AND NOTHING ELSE. A kernel that touches only memory
-- handed to it needs no symbol references, no data section and no relocations,
-- so the same bytes run hosted -- where they can be tested quickly -- and on
-- bare metal, where they cannot. This is the only part of the engine that gets
-- to be tested without booting anything.
--
-- The calling convention is the ordinary one for each architecture: arguments
-- in registers, in order. It is written into the bundled patterns (issue 303)
-- so that everything the machine writes later agrees with everything else it
-- wrote.

local ffi = require("ffi")

local M = {}

-- {{{ bit patterns, computed rather than written down
--
-- Assembly has no way to say "one seven-hundred-and-twentieth" -- a constant
-- must arrive as the exact bits of a single-precision number. Writing those by
-- hand is how one of these came to be `0x3a83b8ac` when the correct pattern is
-- `0x3ab60b61`, which would have made the exponential quietly slightly wrong
-- in a way nothing downstream could have noticed.
--
-- So they are computed from the same values the reference uses, and the
-- assembly is generated with them already in place. One source, and no
-- opportunity to transcribe.
local box = ffi.new("float[1]")
local as_bits = ffi.cast("uint32_t *", box)

local function bits_of(value)
  box[0] = value
  return string.format("0x%08x", as_bits[0])
end

M.bits_of = bits_of
-- }}}

-- {{{ M.x86_64
M.x86_64 = {

  -- {{{ matrix_vector -- plain
  --
  -- void matrix_vector(float *out, const float *matrix, const float *input,
  --                    int rows, int columns)
  --
  -- out is rdi, matrix rsi, input rdx, rows ecx, columns r8d.
  --
  -- For each row: walk the row and the input together, multiplying and adding
  -- into one running total, and store it. The matrix is laid out row by row,
  -- so each row is one contiguous run -- which is what lets the vectorised
  -- version read straight down it without gathering.
  --
  -- Accumulation is single precision in ascending order, because that is the
  -- specification and not merely what fell out (see 035).
  matrix_vector_plain = [[
  .globl matrix_vector_plain
  .type matrix_vector_plain, @function
matrix_vector_plain:
  testl %ecx, %ecx
  jle 9f                        # no rows: nothing to do, and not an error
  xorl %r9d, %r9d               # row = 0
1:
  xorps %xmm0, %xmm0            # running total for this row
  movl %r9d, %eax
  imull %r8d, %eax              # row * columns
  leaq (%rsi,%rax,4), %r11      # where this row begins
  xorl %r10d, %r10d             # column = 0
  testl %r8d, %r8d
  jle 3f                        # a row of no columns totals zero
2:
  movss (%r11,%r10,4), %xmm1
  mulss (%rdx,%r10,4), %xmm1
  addss %xmm1, %xmm0
  incl %r10d
  cmpl %r8d, %r10d
  jl 2b
3:
  movss %xmm0, (%rdi,%r9,4)
  incl %r9d
  cmpl %ecx, %r9d
  jl 1b
9:
  retq
]],
  -- }}}

  -- {{{ matrix_vector_wide -- four at a time
  --
  -- The same operation and the same answer, reading four numbers per step.
  -- This is where nearly all the speed is: the work is multiply-and-accumulate
  -- over long runs of contiguous numbers, which is precisely what these
  -- instructions exist for.
  --
  -- THE ADDITION ORDER IS PRESERVED DELIBERATELY. Four partial totals summed
  -- at the end would give a different answer from one running total -- floating
  -- point addition is not associative, and the difference is real. Keeping one
  -- accumulator and folding each group of four into it in order costs some of
  -- the available speed and buys an answer identical to the plain version,
  -- which is what makes the comparison worth anything.
  --
  -- A faster version that sums four independent totals is legitimate and would
  -- need its own fixture, generated from a reference that does the same. It
  -- would not be comparable to this one.
  matrix_vector_wide = [[
  .globl matrix_vector_wide
  .type matrix_vector_wide, @function
matrix_vector_wide:
  testl %ecx, %ecx
  jle 9f
  xorl %r9d, %r9d               # row = 0
1:
  xorps %xmm0, %xmm0            # running total for this row
  movl %r9d, %eax
  imull %r8d, %eax
  leaq (%rsi,%rax,4), %r11      # where this row begins
  xorl %r10d, %r10d             # column = 0

  movl %r8d, %eax
  andl $-4, %eax                # how many columns fit in whole groups of four
  testl %eax, %eax
  jle 3f
2:
  movups (%r11,%r10,4), %xmm1   # four from the row
  movups (%rdx,%r10,4), %xmm2   # four from the input
  mulps %xmm2, %xmm1            # four products at once

  # fold them into the running total in the same order the plain version
  # would, so the answer is identical rather than merely close.
  movaps %xmm1, %xmm3
  addss %xmm3, %xmm0            # product 0
  shufps $0x39, %xmm3, %xmm3    # rotate the next one into place
  addss %xmm3, %xmm0            # product 1
  shufps $0x39, %xmm3, %xmm3
  addss %xmm3, %xmm0            # product 2
  shufps $0x39, %xmm3, %xmm3
  addss %xmm3, %xmm0            # product 3

  addl $4, %r10d
  cmpl %eax, %r10d
  jl 2b
3:
  cmpl %r8d, %r10d              # the remainder, one at a time
  jge 5f
4:
  movss (%r11,%r10,4), %xmm1
  mulss (%rdx,%r10,4), %xmm1
  addss %xmm1, %xmm0
  incl %r10d
  cmpl %r8d, %r10d
  jl 4b
5:
  movss %xmm0, (%rdi,%r9,4)
  incl %r9d
  cmpl %ecx, %r9d
  jl 1b
9:
  retq
]],
  -- }}}

  -- {{{ rms_normalise
  --
  -- void rms_normalise(float *out, const float *input, const float *weight,
  --                    int size, float epsilon)
  --
  -- out is rdi, input rsi, weight rdx, size ecx, epsilon xmm0.
  --
  -- Scale a vector so its typical magnitude is one, then apply a learned scale
  -- per position. Every layer does this twice, and it is why the numbers
  -- flowing through stay in a range the rest of the arithmetic can work with.
  --
  -- The small constant added before the square root stops a vector of zeros
  -- from dividing by zero. It is part of the specification rather than a
  -- guard: leaving it out changes every answer slightly, so it arrives as an
  -- argument rather than being chosen here.
  --
  -- The value one is built in a register rather than loaded from anywhere.
  -- A constant in memory would need a symbol reference, and a symbol reference
  -- in this project is a note for a linker that nothing reads (see notes/023).
  rms_normalise = [[
  .globl rms_normalise
  .type rms_normalise, @function
rms_normalise:
  movaps %xmm0, %xmm5           # keep epsilon before the accumulator wants xmm0
  testl %ecx, %ecx
  jle 9f
  xorps %xmm0, %xmm0            # sum of squares
  xorl %eax, %eax
1:
  movss (%rsi,%rax,4), %xmm1
  mulss %xmm1, %xmm1
  addss %xmm1, %xmm0
  incl %eax
  cmpl %ecx, %eax
  jl 1b

  cvtsi2ssl %ecx, %xmm2         # how many numbers there were
  divss %xmm2, %xmm0            # the mean of the squares
  addss %xmm5, %xmm0            # plus the small constant
  sqrtss %xmm0, %xmm0
  movl $0x3f800000, %eax        # the bits of one, built rather than fetched
  movd %eax, %xmm4
  divss %xmm0, %xmm4            # the scale to apply
  movaps %xmm4, %xmm0

  xorl %eax, %eax
2:
  movss (%rsi,%rax,4), %xmm1
  mulss %xmm0, %xmm1
  mulss (%rdx,%rax,4), %xmm1
  movss %xmm1, (%rdi,%rax,4)
  incl %eax
  cmpl %ecx, %eax
  jl 2b
9:
  retq
]],
  -- }}}
}
-- }}}

-- {{{ the exponential, in assembly
--
-- The last function that stood between this project and a forward pass
-- comparable exactly rather than approximately. It is written here to follow
-- the specification in 047 step for step -- the same constants, the same
-- polynomial, the same order of operations -- because agreeing with the
-- reference matters more than any other property it could have.
--
-- The method: turn raising e to a power into raising two to a power, split
-- that into a whole part and a fraction, adjust the number's exponent field by
-- the whole part (exact, and free), and approximate the fraction with a short
-- polynomial. Seven terms, chosen by measurement rather than preference (048).
--
-- Both constants are loaded as bit patterns built in a register. A constant in
-- memory would need a symbol reference, and a symbol reference here is a note
-- for a linker that nothing reads.
-- Built as a function rather than held as text, because its constants are
-- computed from the specification (047) rather than transcribed.
function M.build_exp_x86_64(specification)
  local series = specification.SERIES[specification.CHOSEN]

  local body = {}
  local function line(text) body[#body + 1] = text end

  line([[
  .globl exp_one
  .type exp_one, @function
exp_one:
  # xmm0 holds the power. The answer comes back in xmm0.

  # clamp above: anything past the limit returns the largest there is
  movl $]] .. bits_of(specification.LIMIT) .. [[, %eax
  movd %eax, %xmm1
  comiss %xmm1, %xmm0
  jbe 1f
  movl $0x7f7fffff, %eax        # the largest single-precision number
  movd %eax, %xmm0
  retq
1:
  # clamp below: anything past minus the limit returns zero
  movl $]] .. bits_of(-specification.LIMIT) .. [[, %eax
  movd %eax, %xmm1
  comiss %xmm0, %xmm1
  jbe 2f
  xorps %xmm0, %xmm0
  retq
2:
  # how many powers of two, rounded to the nearest whole one
  movl $]] .. string.format("0x%08x", specification.LOG2E_BITS) .. [[, %eax
  movd %eax, %xmm1
  movaps %xmm0, %xmm2
  mulss %xmm1, %xmm2
  cvtss2si %xmm2, %ecx          # rounds to nearest, which is what is wanted
  cvtsi2ssl %ecx, %xmm3

  # and what is left over, always between minus a half and a half of ln 2
  movl $]] .. string.format("0x%08x", specification.LN2_BITS) .. [[, %eax
  movd %eax, %xmm1
  mulss %xmm1, %xmm3
  subss %xmm3, %xmm0            # xmm0 is now the leftover

  # the series, nested: multiply by the leftover, add the next coefficient.
  # Generated from the specification, highest coefficient first.]])

  -- the first coefficient starts the total; every one after is a multiply and
  -- an add, in the reference's order, because the order is part of the answer.
  line("  movl $" .. bits_of(series[1]) .. ", %eax")
  line("  movd %eax, %xmm2")
  for index = 2, #series do
    line("  movl $" .. bits_of(series[index]) .. ", %eax")
    line("  movd %eax, %xmm4")
    line("  mulss %xmm0, %xmm2")
    line("  addss %xmm4, %xmm2")
  end

  line([[
  # the powers of two, applied straight to the exponent field
  addl $127, %ecx
  cmpl $1, %ecx
  jge 3f
  xorps %xmm0, %xmm0            # underflowed to nothing
  retq
3:
  cmpl $254, %ecx
  jle 4f
  movl $0x7f7fffff, %eax
  movd %eax, %xmm0
  retq
4:
  shll $23, %ecx
  movd %ecx, %xmm5
  mulss %xmm5, %xmm2
  movaps %xmm2, %xmm0
  retq]])

  return table.concat(body, "\n")
end
-- }}}

-- {{{ softmax, in assembly
--
-- void softmax(float *values, int count)
--
-- values is rdi, count esi. Turns a set of scores into weights adding to one,
-- in place.
--
-- The largest is subtracted first. That changes nothing about the answer and
-- stops the exponentials from running away -- and because it is done, every
-- argument handed to the exponential is zero or negative, which is the range
-- it is most accurate over.
M.x86_64.softmax = [[
  .globl softmax
  .type softmax, @function
softmax:
  testl %esi, %esi
  jle 9f
  pushq %rbx
  pushq %r12
  pushq %r13
  # Thirty-two bytes of scratch, ABOVE the stack pointer.
  #
  # The obvious place to keep something across a call is just below the stack
  # pointer, where a function may use a little space without asking. It is the
  # one place that cannot be used here: a call writes its return address
  # exactly there, so anything left below the pointer is destroyed by the very
  # instruction it had to survive. This produced a softmax whose every value
  # was a fraction of a fraction of nothing, and it did not fail.
  #
  # The size is thirty-two rather than eight so that the pointer stays
  # sixteen-byte aligned at each call, which the convention requires.
  subq $32, %rsp
  movq %rdi, %rbx               # the values
  movl %esi, %r12d              # how many

  # find the largest
  movss (%rbx), %xmm6
  movl $1, %eax
1:
  cmpl %r12d, %eax
  jge 2f
  movss (%rbx,%rax,4), %xmm1
  comiss %xmm6, %xmm1
  jbe 11f
  movaps %xmm1, %xmm6
11:
  incl %eax
  jmp 1b
2:
  # raise e to each score less the largest, and total them as we go
  xorps %xmm7, %xmm7            # the running total
  xorl %r13d, %r13d
3:
  cmpl %r12d, %r13d
  jge 4f
  movss (%rbx,%r13,4), %xmm0
  subss %xmm6, %xmm0
  movss %xmm6, (%rsp)           # every one of these may be used by the call
  movss %xmm7, 8(%rsp)
  call exp_one
  movss (%rsp), %xmm6
  movss 8(%rsp), %xmm7
  movss %xmm0, (%rbx,%r13,4)
  addss %xmm0, %xmm7
  incl %r13d
  jmp 3b
4:
  # and divide each by the total
  xorl %eax, %eax
5:
  cmpl %r12d, %eax
  jge 6f
  movss (%rbx,%rax,4), %xmm1
  divss %xmm7, %xmm1
  movss %xmm1, (%rbx,%rax,4)
  incl %eax
  jmp 5b
6:
  addq $32, %rsp
  popq %r13
  popq %r12
  popq %rbx
9:
  retq
]]
-- }}}

-- {{{ the gate, in assembly
--
-- void swiglu(float *gate, const float *up, int count)
--
-- gate is rdi, up rsi, count edx. The gate decides how much of each position
-- passes, on a curve that is smooth everywhere rather than a hard cutoff, and
-- what passes is then multiplied by the other half.
M.x86_64.swiglu = [[
  .globl swiglu
  .type swiglu, @function
swiglu:
  testl %edx, %edx
  jle 9f
  pushq %rbx
  pushq %r12
  pushq %r13
  subq $32, %rsp                # above the pointer, and aligned -- see softmax
  movq %rdi, %rbx
  movq %rsi, %r12
  movl %edx, %r13d
  xorl %eax, %eax
1:
  cmpl %r13d, %eax
  jge 2f
  movss (%rbx,%rax,4), %xmm0
  movss %xmm0, (%rsp)           # the value itself, wanted again after the call
  movl %eax, 8(%rsp)
  xorps %xmm1, %xmm1
  subss %xmm0, %xmm1            # minus the value
  movaps %xmm1, %xmm0
  call exp_one
  movl 8(%rsp), %eax
  movl $0x3f800000, %ecx        # one
  movd %ecx, %xmm2
  addss %xmm2, %xmm0            # one plus e to minus the value
  movss (%rsp), %xmm3           # the value again
  divss %xmm0, %xmm3            # how much passes
  mulss (%r12,%rax,4), %xmm3    # times the other half
  movss %xmm3, (%rbx,%rax,4)
  incl %eax
  jmp 1b
2:
  # thirty-two, matching the prologue. Restoring a different amount leaves the
  # stack pointer somewhere else than it started and the function returns to
  # whatever happens to be there -- which, unusually for this project, does
  # crash rather than quietly continue.
  addq $32, %rsp
  popq %r13
  popq %r12
  popq %rbx
9:
  retq
]]
-- }}}

-- {{{ M.names -- what exists, so a test can ask rather than be told
M.names = {
  "matrix_vector_plain", "matrix_vector_wide", "rms_normalise",
  "exp_one", "softmax", "swiglu",
}
-- }}}

-- {{{ M.source(arch)
-- Everything for one architecture, in one assembler file.
function M.source(arch, specification)
  local kernels = M[arch]
  if not kernels then
    error("043-emit-kernels: no kernels written for " .. tostring(arch))
  end

  -- the exponential is generated rather than stored, so its constants come
  -- from the specification and cannot be transcribed wrongly
  if arch == "x86_64" and specification then
    kernels.exp_one = M.build_exp_x86_64(specification)
  end

  local parts = { "  .text" }
  for _, name in ipairs(M.names) do
    if kernels[name] then parts[#parts + 1] = kernels[name] end
  end

  -- A declaration that this code does not need a stack it can execute.
  --
  -- Hand-written assembly carries no such note, and a linker meeting an object
  -- without one assumes the worst and marks the whole result as requiring an
  -- executable stack -- which current loaders then refuse outright. The note
  -- is meaningless on bare metal, where nothing reads it, and required
  -- wherever this is loaded into a running system for testing.
  parts[#parts + 1] = '  .section .note.GNU-stack,"",@progbits'
  parts[#parts + 1] = ""
  return table.concat(parts, "\n")
end
-- }}}

return M
