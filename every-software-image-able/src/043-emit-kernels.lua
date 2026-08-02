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

local M = {}

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

-- {{{ M.names -- what exists, so a test can ask rather than be told
M.names = { "matrix_vector_plain", "matrix_vector_wide", "rms_normalise" }
-- }}}

-- {{{ M.source(arch)
-- Everything for one architecture, in one assembler file.
function M.source(arch)
  local kernels = M[arch]
  if not kernels then
    error("043-emit-kernels: no kernels written for " .. tostring(arch))
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
