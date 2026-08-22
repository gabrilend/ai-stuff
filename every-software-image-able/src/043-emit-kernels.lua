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
-- Through the shared conversion (107) rather than done here. The version
-- that lived in this file wrote a float and read it back through a pointer
-- of a different shape, which is correct until the loop it sits in gets hot
-- and the compiler decides the second read cannot have changed.
--
-- It was never wrong HERE, because it is called a handful of times -- once
-- per polynomial coefficient -- and the failure needs hundreds of calls to
-- appear. It was wrong in a file that copied it, where it emitted two
-- hundred and fifty-six numbers of which three were distinct and very nearly
-- got an innocent port recorded as broken.
--
-- Moved rather than left alone, because the next thing wanting a table of
-- constants would have copied it again, and the copy is where it bites.
local float_bits = dofile(
  (os.getenv("ESIA_DIR") or "/mnt/mtwo/programming/ai-stuff/every-software-image-able")
  .. "/src/107-float-bits.lua")

local function bits_of(value)
  return float_bits.hex(value)
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

  -- {{{ matrix_vector_fast -- four independent totals
  --
  -- The same operation as the two above and DELIBERATELY NOT THE SAME ANSWER.
  --
  -- The exact kernel folds each group of four products into ONE running
  -- total, in order, so that its answer is identical to the plain version.
  -- That ordering is what costs the speed: every addition must wait for the
  -- one before it, and the processor's adder sits idle between them.
  --
  -- This keeps FOUR totals, one per lane, and never makes them wait for each
  -- other. Four additions are in flight at once, which is what the hardware
  -- was built to do. Floating-point addition is not associative, so the
  -- answer differs in the last bits -- not because either is wrong, but
  -- because they are summing in different orders, and the order is part of
  -- the answer.
  --
  -- SO THIS IS A SECOND SPECIFICATION, not a faster implementation of the
  -- first. It has its own readable twin and its own recorded answers, and it
  -- is never compared against the exact one.
  --
  -- WHAT THE PROJECT KEEPS THE EXACT ONE FOR. Proving a port. Run the exact
  -- kernel once on a new architecture and its answers must match the first
  -- architecture's bit for bit, which is a claim no tolerance can make. Then
  -- run this one forever after.
  --
  -- The final combining is specified rather than incidental, because a
  -- different reduction order is a different answer again:
  --     lane0 += lane2, lane1 += lane3, then lane0 += lane1
  -- and any remaining columns are folded in one at a time AFTERWARDS.
  matrix_vector_fast = [[
  .globl matrix_vector_fast
  .type matrix_vector_fast, @function
matrix_vector_fast:
  testl %ecx, %ecx
  jle 9f
  xorl %r9d, %r9d               # row = 0
1:
  xorps %xmm0, %xmm0            # four running totals, one per lane
  movl %r9d, %eax
  imull %r8d, %eax
  leaq (%rsi,%rax,4), %r11      # where this row begins
  xorl %r10d, %r10d

  movl %r8d, %eax
  andl $-4, %eax                # columns in whole groups of four
  testl %eax, %eax
  jle 3f
2:
  movups (%r11,%r10,4), %xmm1
  movups (%rdx,%r10,4), %xmm2
  mulps %xmm2, %xmm1
  # and straight into the four totals. No folding, no waiting: this is the
  # single instruction the exact kernel cannot use.
  addps %xmm1, %xmm0
  addl $4, %r10d
  cmpl %eax, %r10d
  jl 2b
3:
  # combine the four, in the order written above
  movaps %xmm0, %xmm1
  shufps $0x0e, %xmm1, %xmm1    # lanes 2 and 3 down into 0 and 1
  addps %xmm1, %xmm0            # lane0 = a0+a2, lane1 = a1+a3
  movaps %xmm0, %xmm1
  shufps $0x01, %xmm1, %xmm1    # lane 1 down into lane 0
  addss %xmm1, %xmm0            # (a0+a2) + (a1+a3)

  cmpl %r8d, %r10d              # whatever did not fit in a group of four
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

  -- {{{ matrix_vector_quantised -- weights at four bits, unpacked as it goes
  --
  -- void matrix_vector_quantised(float *out, const unsigned char *matrix,
  --                              const float *input, int rows, int columns)
  --
  -- out rdi, matrix rsi, input rdx, rows ecx, columns r8d.
  --
  -- A FOURTH SPECIFICATION, not a smaller version of any of the three above.
  -- The weights it reads have already lost information and its answer is
  -- different on purpose, so it is never compared against the exact product.
  -- It is held to `123`, the readable specification, bit for bit -- and to
  -- the other two architectures, which is the same claim said twice.
  --
  -- THE SCALE IS UNPACKED IN WHOLE-NUMBER ARITHMETIC rather than by a
  -- conversion instruction, on all three architectures, and that is a
  -- deliberate choice rather than an oversight. This processor's half-float
  -- conversion is an optional extension that a given chip may not have; the
  -- third architecture's base instruction set has no half-precision at all.
  -- Borrowing an instruction here would make the engine refuse to run on
  -- machines it otherwise fits, and would make one architecture's answer
  -- depend on hardware the others do not have.
  --
  -- The unpacking, and it is the same three lines everywhere: shift the
  -- pattern up thirteen places so its mantissa lands where a single
  -- precision mantissa goes, add the difference between the two exponent
  -- biases, and -- only when the exponent field was zero -- take one step
  -- into the normal range and subtract it off again, which turns a
  -- subnormal into the number it stands for without any counting of leading
  -- zeroes. A scale is never negative and never infinite here, because the
  -- quantiser takes a magnitude and saturates, so neither case is written.
  --
  -- TWO WEIGHTS PER PASS, and not for speed. Choosing a half of a byte by
  -- testing the low bit of an index would put a branch in the innermost
  -- loop of the machine; taking the low half and then the high half needs no
  -- test at all, and the order it produces is exactly the order the
  -- specification names.
  matrix_vector_quantised = [[
  .globl matrix_vector_quantised
  .type matrix_vector_quantised, @function
matrix_vector_quantised:
  pushq %rbx
  pushq %r12
  testl %ecx, %ecx
  jle 9f                        # no rows: nothing to do, and not an error
  xorl %r9d, %r9d               # row = 0
1:
  xorps %xmm0, %xmm0            # running total for this row
  movl %r8d, %eax
  shrl $5, %eax                 # blocks in a row: columns / 32
  imull %r9d, %eax              # rows of blocks before this one
  imull $18, %eax               # and eighteen bytes to a block
  leaq (%rsi,%rax), %r11        # where this row's bytes begin
  xorl %r10d, %r10d             # column = 0
  testl %r8d, %r8d
  jle 5f                        # a row of no columns totals zero
2:
  # the scale, out of two bytes and into a single precision register
  movzwl (%r11), %eax
  shll $13, %eax
  movl %eax, %ebx
  andl $0x0f800000, %ebx        # the exponent field, where it now sits
  addl $0x38000000, %eax        # the two biases differ by this much
  testl %ebx, %ebx
  jnz 3f
  addl $0x00800000, %eax        # a step into the normal range
  movd %eax, %xmm1
  movl $0x38800000, %eax        # and the same step, taken back off
  movd %eax, %xmm2
  subss %xmm2, %xmm1
  jmp 4f
3:
  movd %eax, %xmm1
4:
  xorl %ebx, %ebx               # which byte of the sixteen
6:
  movzbl 2(%r11,%rbx), %eax     # two weights
  movl %eax, %r12d

  andl $15, %eax                # the earlier one is the low half
  subl $8, %eax                 # eight stands for nothing
  cvtsi2ssl %eax, %xmm2
  mulss %xmm1, %xmm2            # times the block's scale
  mulss (%rdx,%r10,4), %xmm2    # times what it meets
  addss %xmm2, %xmm0            # ascending order, as everywhere else
  incq %r10

  shrl $4, %r12d                # and the later one is the high half
  subl $8, %r12d
  cvtsi2ssl %r12d, %xmm2
  mulss %xmm1, %xmm2
  mulss (%rdx,%r10,4), %xmm2
  addss %xmm2, %xmm0
  incq %r10

  incl %ebx
  cmpl $16, %ebx
  jl 6b

  addq $18, %r11                # the next block
  cmpl %r8d, %r10d
  jl 2b
5:
  movss %xmm0, (%rdi,%r9,4)
  incl %r9d
  cmpl %ecx, %r9d
  jl 1b
9:
  popq %r12
  popq %rbx
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

-- {{{ the rest of a forward pass
--
-- Four small operations that together with the five above cover everything a
-- step does. None of them needs a specification of its own: they are
-- multiplication and addition, which agree everywhere.

-- void rotate(float *vec, const float *turns, int heads, int head_width)
--
-- Turn each pair of numbers in each head by the angle for this position,
-- reading the cosine and sine from the carried table rather than computing
-- them. `turns` points at the row for the position already.
M.x86_64.rotate = [[
  .globl rotate
  .type rotate, @function
rotate:
  testl %edx, %edx
  jle 9f
  testl %ecx, %ecx
  jle 9f
  pushq %rbx                    # one register short without it
  movl %ecx, %r9d
  shrl $1, %r9d                 # pairs per head
  testl %r9d, %r9d
  jle 8f
  xorl %r10d, %r10d             # head
1:
  movl %r10d, %eax
  imull %ecx, %eax              # head * head_width
  xorl %r11d, %r11d             # pair
2:
  movl %r11d, %ebx
  addl %ebx, %ebx               # pair * 2 -- where in the row of turns
  movl %ebx, %r8d
  addl %eax, %r8d               # ... and where in this head of the vector

  movss (%rdi,%r8,4), %xmm0     # x
  movss 4(%rdi,%r8,4), %xmm1    # y
  movss (%rsi,%rbx,4), %xmm2    # cosine
  movss 4(%rsi,%rbx,4), %xmm3   # sine

  movaps %xmm0, %xmm4
  mulss %xmm2, %xmm4            # x cos
  movaps %xmm1, %xmm5
  mulss %xmm3, %xmm5            # y sin
  subss %xmm5, %xmm4            # x cos - y sin

  movaps %xmm0, %xmm6
  mulss %xmm3, %xmm6            # x sin
  movaps %xmm1, %xmm7
  mulss %xmm2, %xmm7            # y cos
  addss %xmm7, %xmm6            # x sin + y cos

  movss %xmm4, (%rdi,%r8,4)
  movss %xmm6, 4(%rdi,%r8,4)

  incl %r11d
  cmpl %r9d, %r11d
  jl 2b
  incl %r10d
  cmpl %edx, %r10d
  jl 1b
8:
  popq %rbx
9:
  retq
]]

-- void attention_scores(float *scores, const float *query, const float *keys,
--                      int count, int width, int stride, float scale)
--
-- How well this token's question matches each earlier token's answer. The keys
-- live in the cache one position apart by `stride`, because every layer and
-- every key head shares that array.
M.x86_64.attention_scores = [[
  .globl attention_scores
  .type attention_scores, @function
attention_scores:
  testl %ecx, %ecx
  jle 9f
  xorl %r10d, %r10d             # which past position
1:
  movl %r10d, %eax
  imull %r9d, %eax              # position * stride
  leaq (%rdx,%rax,4), %r11      # that position's keys

  xorps %xmm1, %xmm1            # running total
  xorl %eax, %eax
2:
  cmpl %r8d, %eax
  jge 3f
  movss (%rsi,%rax,4), %xmm2
  mulss (%r11,%rax,4), %xmm2
  addss %xmm2, %xmm1
  incl %eax
  jmp 2b
3:
  mulss %xmm0, %xmm1            # times the scale
  movss %xmm1, (%rdi,%r10,4)
  incl %r10d
  cmpl %ecx, %r10d
  jl 1b
9:
  retq
]]

-- void attention_mix(float *out, const float *weights, const float *values,
--                   int count, int width, int stride)
--
-- What to carry forward: each earlier token's value, weighted by how well it
-- matched. Accumulated position by position in ascending order, which is the
-- order the reference uses and therefore part of the answer.
M.x86_64.attention_mix = [[
  .globl attention_mix
  .type attention_mix, @function
attention_mix:
  testl %r8d, %r8d
  jle 9f
  xorl %eax, %eax               # clear the destination first
1:
  cmpl %r8d, %eax
  jge 2f
  movl $0, (%rdi,%rax,4)
  incl %eax
  jmp 1b
2:
  testl %ecx, %ecx
  jle 9f
  xorl %r10d, %r10d             # which past position
3:
  movl %r10d, %eax
  imull %r9d, %eax
  leaq (%rdx,%rax,4), %r11      # that position's values
  movss (%rsi,%r10,4), %xmm0    # its weight

  xorl %eax, %eax
4:
  cmpl %r8d, %eax
  jge 5f
  movss (%r11,%rax,4), %xmm1
  mulss %xmm0, %xmm1
  addss (%rdi,%rax,4), %xmm1
  movss %xmm1, (%rdi,%rax,4)
  incl %eax
  jmp 4b
5:
  incl %r10d
  cmpl %ecx, %r10d
  jl 3b
9:
  retq
]]

-- void add_into(float *destination, const float *addend, int count)
--
-- What carries a token's meaning past a layer rather than through it.
M.x86_64.add_into = [[
  .globl add_into
  .type add_into, @function
add_into:
  testl %edx, %edx
  jle 9f
  xorl %eax, %eax
1:
  movss (%rdi,%rax,4), %xmm0
  addss (%rsi,%rax,4), %xmm0
  movss %xmm0, (%rdi,%rax,4)
  incl %eax
  cmpl %edx, %eax
  jl 1b
9:
  retq
]]
-- }}}

-- {{{ M.names -- what exists, so a test can ask rather than be told
M.names = {
  "matrix_vector_plain", "matrix_vector_wide", "matrix_vector_fast",
  "matrix_vector_quantised",
  "rms_normalise",
  "exp_one", "softmax", "swiglu",
  "rotate", "attention_scores", "attention_mix", "add_into",
}
-- }}}

-- {{{ M.READ_BY -- which kernel reads weights stored in which precision
-- The blob format (024) can DESCRIBE more precisions than the arithmetic can
-- read, and the gap is not obvious from either file alone. A planner deciding
-- whether a model fits in a currency the engine does not accept is answering a
-- question nobody asked, so the mapping is stated here, beside the kernels,
-- because this is the file that knows.
--
-- ASK THIS, DO NOT COPY IT. 046 held its own list saying the engine read f32
-- and nothing else. That was true when written and stayed on the page after
-- the quantised kernel landed on all three architectures, so every weight
-- figure in that report was scaled by a caveat that had stopped being true.
--
-- It is the same defect 401 paid for and named: a hand-kept table of what
-- exists, and a check that agreed with it because it was reading the same
-- stale copy. The remedy there was to ask the port what it has rather than
-- remember. Same remedy here.
--
-- A precision absent from this table is one the arithmetic cannot read. A
-- precision present but whose kernel is missing from M.names is also
-- unreadable, and is worked out rather than restated -- so deleting a kernel
-- withdraws the claim automatically.
M.READ_BY = {
  f32 = "matrix_vector_plain",
  q40 = "matrix_vector_quantised",
}
-- }}}

-- {{{ M.reads(precision)
-- Whether the arithmetic can read weights stored this way. Derived from the
-- kernel list rather than asserted, for the reason above.
function M.reads(precision)
  local kernel = M.READ_BY[precision]
  if not kernel then return false end
  for _, name in ipairs(M.names) do
    if name == kernel then return true end
  end
  return false
end
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
