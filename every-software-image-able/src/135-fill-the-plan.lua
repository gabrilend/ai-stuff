-- 135-fill-the-plan.lua
--
-- Telling the conducting where everything is, on a bare machine, in all
-- three tongues. The third piece of the driver (issue 107).
--
-- For a general: the conducting reaches nothing by name -- on bare metal
-- there are no names -- so it asks only "what is at this offset of the
-- plan". Something has to write that plan, and hosted, a readable program
-- does it with a page of assignments. This is that page, in the processor's
-- own instructions, filled from what the previous two pieces found out.
--
-- WHAT IT TIES TOGETHER. The counts come out of the model's own header. The
-- tensor addresses come from `131`, which walked the model. The workspace
-- addresses come from `133`, which divided the memory. The kernel addresses
-- come from the caller, which is the only thing that knows where it put its
-- own routines. Nothing here is a constant except the two the specification
-- fixes.
--
-- WHERE BEING WRONG IS SILENT, and it is nearly everywhere in this routine.
-- A slot written one place along is not an error: the conducting reads it,
-- gets an address that is something else's, and the arithmetic proceeds. A
-- layer table filled with the wrong stride gives every layer the layer
-- before's weights and produces a perfectly well-formed answer to a question
-- nobody asked.
--
-- THE ONE REFUSAL, and it is worth more than it looks. Query heads are
-- walked in groups, one group per key head, and the walk counts up rather
-- than dividing -- so a model whose heads do not divide evenly among its key
-- heads would walk off the end of the group and read a key head that does
-- not exist. That cannot be discovered later: it is a wrong answer, not a
-- fault. So it is refused here, where there is still something to say it to.
--
-- THE TWO FLOATING NUMBERS ARE THE ONLY ARITHMETIC IN THE SETUP. The
-- conducting deliberately has none -- every number it touches is a count or
-- an address -- and the attention scale has to come from somewhere. It is
-- computed once here, at startup, as one over the square root of the head
-- width, ROUNDED THROUGH SINGLE PRECISION, because that rounding is part of
-- the specification and not an accident of where it was worked out (`035`).

local M = {}

-- {{{ M.EPSILON_BITS -- the normalisation constant, as a pattern
--
-- Carried as bits rather than computed, for the same reason every other
-- constant in the assembly is: there is no way to say "one hundred
-- thousandth" in a processor's instructions, and a decimal that has to be
-- parsed back is a rounding this would then be measuring.
M.EPSILON = 1e-5
-- }}}

-- {{{ M.header_offsets(format) and M.plan_offsets(conductor)
function M.header_offsets(format)
  local at, offsets = 0, {}
  for _, field in ipairs(format.HEADER) do
    offsets[field.name] = at
    at = at + field.size
  end
  return offsets
end
-- }}}

-- {{{ shared shape, described once
--
-- int64_t fill_plan(void *plan, const uint8_t *blob,
--                   const void **tensors, void **regions,
--                   const void **kernels, void **layer_table)
--
-- `tensors` is what `131` produced: every tensor of the model, in the order
-- the packer wrote them. `regions` is what `133` produced, in the order it
-- names them. `kernels` is eight addresses in the order the plan holds them.
-- `layer_table` is room for nine addresses per layer, which this fills and
-- then points the plan at.
--
-- Returns zero, or minus one if the model's heads do not divide evenly among
-- its key heads.
--
-- WHERE THE TENSORS SIT IN THAT LIST is decided by `034` and repeated here
-- as arithmetic: what a token means, then the carried turns, then nine per
-- layer, then the two at the end. Walking by index rather than by name is
-- the same choice `131` made, and rests on the same dependency.
-- }}}

-- {{{ M.x86_64(format, conductor, float_bits)
-- plan rdi, blob rsi, tensors rdx, regions rcx, kernels r8, layer_table r9.
function M.x86_64(format, conductor, float_bits)
  local header = M.header_offsets(format)
  local at = conductor.offsets()
  local layer_names = conductor.LAYER_ORDER
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl fill_plan")
  line("  .type fill_plan, @function")
  line("fill_plan:")
  line("  pushq %rbx")
  line("  pushq %rbp")
  line("  pushq %r12")
  line("  pushq %r13")
  line("  pushq %r14")
  line("  pushq %r15")

  -- THE ARGUMENTS MOVE SOMEWHERE SAFE FIRST, and this is not tidiness. The
  -- division below needs one particular pair of registers, and one of them
  -- is where the tensor list arrives -- so dividing destroys it, and every
  -- tensor address after that point is read from whatever the remainder
  -- happened to be. That is a fault if you are lucky and a wrong weight if
  -- you are not.
  line("  movq %rdx, %r10")                 -- the tensors
  line("  movq %rcx, %r11")                 -- the regions
  line("  movq %r8, %rbp")                  -- the kernels
  line("  movq %r9, %rbx")                  -- the layer table

  -- {{{ the counts the header carries, widened and stored
  for _, name in ipairs({ "layers", "hidden", "heads", "head_width",
                          "kv_heads", "feedforward", "vocabulary",
                          "context" }) do
    line("  movl " .. header[name] .. "(%rsi), %eax")
    line("  movq %rax, " .. at[name] .. "(%rdi)")
  end
  -- }}}

  -- {{{ the three the header does not carry
  line("  movq " .. at.heads .. "(%rdi), %rax")
  line("  movq " .. at.kv_heads .. "(%rdi), %r14")
  line("  testq %r14, %r14")
  line("  jz fp_uneven")                    -- no key heads at all
  line("  xorl %edx, %edx")
  line("  divq %r14")                       -- rax = groups, rdx = what is left
  line("  testq %rdx, %rdx")
  line("  jnz fp_uneven")                   -- heads that do not divide evenly
  line("  movq %rax, " .. at.heads_per_kv .. "(%rdi)")

  line("  movq " .. at.kv_heads .. "(%rdi), %rax")
  line("  imulq " .. at.head_width .. "(%rdi), %rax")
  line("  movq %rax, " .. at.kv_width .. "(%rdi)")
  line("  movq " .. at.heads .. "(%rdi), %rax")
  line("  imulq " .. at.head_width .. "(%rdi), %rax")
  line("  movq %rax, " .. at.query_width .. "(%rdi)")
  -- }}}

  -- {{{ the two the specification fixes
  -- one over the square root of the head width, rounded through single
  -- precision -- the rounding is the specification, not an accident of where
  -- this was worked out
  line("  cvtsi2ssq " .. at.head_width .. "(%rdi), %xmm0")
  line("  sqrtss %xmm0, %xmm0")
  line("  movl $0x3f800000, %eax")          -- one
  line("  movd %eax, %xmm1")
  line("  divss %xmm0, %xmm1")
  line("  movss %xmm1, " .. at.scale .. "(%rdi)")
  line(string.format("  movl $0x%08x, %%eax", float_bits.of(M.EPSILON)))
  line("  movl %eax, " .. at.epsilon .. "(%rdi)")
  -- }}}

  -- {{{ the eight kernels, in the order the plan holds them
  local kernels = { "multiply", "k_rms_normalise", "k_rotate",
                    "k_attention_scores", "k_softmax", "k_attention_mix",
                    "k_swiglu", "k_add_into" }
  for index, name in ipairs(kernels) do
    line("  movq " .. ((index - 1) * 8) .. "(%rbp), %rax")
    line("  movq %rax, " .. at[name] .. "(%rdi)")
  end
  -- }}}

  -- {{{ the ten places, in the order 133 named them
  local regions = { "state", "normalised", "query", "attended", "projected",
                    "gate", "up", "scores", "cache_keys", "cache_values" }
  for index, name in ipairs(regions) do
    line("  movq " .. ((index - 1) * 8) .. "(%r11), %rax")
    line("  movq %rax, " .. at[name] .. "(%rdi)")
  end
  -- }}}

  -- {{{ the four fixed tensors, and the per-layer table
  -- what a token means, then the carried turns, then nine per layer, then
  -- the two at the end -- the order 034 decides
  line("  movq 0(%r10), %rax")
  line("  movq %rax, " .. at.token_embedding .. "(%rdi)")
  line("  movq 8(%r10), %rax")
  line("  movq %rax, " .. at.rotation .. "(%rdi)")

  line("  movq " .. at.layers .. "(%rdi), %r12")
  line("  movq %r12, %rax")
  line("  imulq $" .. #layer_names .. ", %rax")
  line("  addq $2, %rax")                   -- past the two at the front
  line("  movq (%r10,%rax,8), %rcx")
  line("  movq %rcx, " .. at.output_norm .. "(%rdi)")
  line("  movq 8(%r10,%rax,8), %rcx")
  line("  movq %rcx, " .. at.output .. "(%rdi)")

  line("  movq %rbx, " .. at.layer_table .. "(%rdi)")
  line("  xorl %r13d, %r13d")               -- which layer
  line("fp_layer:")
  line("  cmpq %r12, %r13")
  line("  jge fp_done")
  line("  xorl %r14d, %r14d")               -- which of the nine
  line("fp_slot:")
  line("  cmpq $" .. #layer_names .. ", %r14")
  line("  jge fp_layer_next")
  -- where it sits among the tensors, and where it goes in the table
  line("  movq %r13, %rax")
  line("  imulq $" .. #layer_names .. ", %rax")
  line("  addq %r14, %rax")
  line("  movq %rax, %r15")                 -- the place in the table
  line("  addq $2, %rax")                   -- and the tensor's index
  line("  movq (%r10,%rax,8), %rcx")
  line("  movq %rcx, (%rbx,%r15,8)")
  line("  incq %r14")
  line("  jmp fp_slot")
  line("fp_layer_next:")
  line("  incq %r13")
  line("  jmp fp_layer")
  -- }}}

  line("fp_uneven:")
  line("  movq $-1, %rax")
  line("  jmp fp_return")
  line("fp_done:")
  line("  xorl %eax, %eax")
  line("fp_return:")
  line("  popq %r15")
  line("  popq %r14")
  line("  popq %r13")
  line("  popq %r12")
  line("  popq %rbp")
  line("  popq %rbx")
  line("  retq")
  line("")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.aarch64(format, conductor, float_bits)
-- plan x0, blob x1, tensors x2, regions x3, kernels x4, layer_table x5.
function M.aarch64(format, conductor, float_bits)
  local header = M.header_offsets(format)
  local at = conductor.offsets()
  local layer_names = conductor.LAYER_ORDER
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl fill_plan")
  line("  .type fill_plan, @function")
  line("fill_plan:")

  for _, name in ipairs({ "layers", "hidden", "heads", "head_width",
                          "kv_heads", "feedforward", "vocabulary",
                          "context" }) do
    line("  ldr w6, [x1, #" .. header[name] .. "]")
    line("  str x6, [x0, #" .. at[name] .. "]")
  end

  line("  ldr x6, [x0, #" .. at.heads .. "]")
  line("  ldr x7, [x0, #" .. at.kv_heads .. "]")
  line("  cbz x7, fp_uneven")
  line("  udiv x8, x6, x7")
  line("  msub x9, x8, x7, x6")             -- what the division left over
  line("  cbnz x9, fp_uneven")
  line("  str x8, [x0, #" .. at.heads_per_kv .. "]")

  line("  ldr x9, [x0, #" .. at.head_width .. "]")
  line("  mul x10, x7, x9")
  line("  str x10, [x0, #" .. at.kv_width .. "]")
  line("  mul x10, x6, x9")
  line("  str x10, [x0, #" .. at.query_width .. "]")

  -- one over the square root of the head width, rounded through single
  line("  scvtf s0, x9")
  line("  fsqrt s0, s0")
  line("  movz w11, #0x0000")
  line("  movk w11, #0x3f80, lsl #16")      -- one
  line("  fmov s1, w11")
  line("  fdiv s1, s1, s0")
  line("  str s1, [x0, #" .. at.scale .. "]")
  local eps = float_bits.of(M.EPSILON)
  line(string.format("  movz w11, #0x%x", eps % 0x10000))
  line(string.format("  movk w11, #0x%x, lsl #16", math.floor(eps / 0x10000)))
  line("  str w11, [x0, #" .. at.epsilon .. "]")

  local kernels = { "multiply", "k_rms_normalise", "k_rotate",
                    "k_attention_scores", "k_softmax", "k_attention_mix",
                    "k_swiglu", "k_add_into" }
  for index, name in ipairs(kernels) do
    line("  ldr x6, [x4, #" .. ((index - 1) * 8) .. "]")
    line("  str x6, [x0, #" .. at[name] .. "]")
  end

  local regions = { "state", "normalised", "query", "attended", "projected",
                    "gate", "up", "scores", "cache_keys", "cache_values" }
  for index, name in ipairs(regions) do
    line("  ldr x6, [x3, #" .. ((index - 1) * 8) .. "]")
    line("  str x6, [x0, #" .. at[name] .. "]")
  end

  line("  ldr x6, [x2]")
  line("  str x6, [x0, #" .. at.token_embedding .. "]")
  line("  ldr x6, [x2, #8]")
  line("  str x6, [x0, #" .. at.rotation .. "]")

  line("  ldr x12, [x0, #" .. at.layers .. "]")
  line("  mov x13, #" .. #layer_names)
  line("  mul x6, x12, x13")
  line("  add x6, x6, #2")                  -- past the two at the front
  line("  ldr x7, [x2, x6, lsl #3]")
  line("  str x7, [x0, #" .. at.output_norm .. "]")
  line("  add x6, x6, #1")
  line("  ldr x7, [x2, x6, lsl #3]")
  line("  str x7, [x0, #" .. at.output .. "]")

  line("  str x5, [x0, #" .. at.layer_table .. "]")
  line("  mov x14, xzr")                    -- which layer
  line("fp_layer:")
  line("  cmp x14, x12")
  line("  b.ge fp_done")
  line("  mov x15, xzr")                    -- which of the nine
  line("fp_slot:")
  line("  cmp x15, x13")
  line("  b.ge fp_layer_next")
  line("  mul x6, x14, x13")
  line("  add x6, x6, x15")                 -- the place in the table
  line("  add x7, x6, #2")                  -- and the tensor's index
  line("  ldr x7, [x2, x7, lsl #3]")
  line("  str x7, [x5, x6, lsl #3]")
  line("  add x15, x15, #1")
  line("  b fp_slot")
  line("fp_layer_next:")
  line("  add x14, x14, #1")
  line("  b fp_layer")

  line("fp_uneven:")
  line("  mov x0, #-1")
  line("  ret")
  line("fp_done:")
  line("  mov x0, xzr")
  line("  ret")
  line("")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.riscv64(p, format, conductor, float_bits)
-- plan a0, blob a1, tensors a2, regions a3, kernels a4, layer_table a5.
function M.riscv64(p, format, conductor, float_bits)
  local header = M.header_offsets(format)
  local at = conductor.offsets()
  local layer_names = conductor.LAYER_ORDER

  p:label("fill_plan")

  for _, name in ipairs({ "layers", "hidden", "heads", "head_width",
                          "kv_heads", "feedforward", "vocabulary",
                          "context" }) do
    p:op("lwu t0, " .. header[name] .. "(a1)")
    p:op("sd t0, " .. at[name] .. "(a0)")
  end

  p:op("ld t0, " .. at.heads .. "(a0)")
  p:op("ld t1, " .. at.kv_heads .. "(a0)")
  p:branch("beq", "t1", "zero", "fp_uneven")
  p:op("divu t2, t0, t1")
  p:op("mul t3, t2, t1")
  p:op("sub t3, t0, t3")                    -- what the division left over
  p:branch("bne", "t3", "zero", "fp_uneven")
  p:op("sd t2, " .. at.heads_per_kv .. "(a0)")

  p:op("ld t3, " .. at.head_width .. "(a0)")
  p:op("mul t4, t1, t3")
  p:op("sd t4, " .. at.kv_width .. "(a0)")
  p:op("mul t4, t0, t3")
  p:op("sd t4, " .. at.query_width .. "(a0)")

  -- one over the square root of the head width, rounded through single
  p:op("fcvt.s.l ft0, t3, rne")
  p:op("fsqrt.s ft0, ft0")
  p:load_constant("t5", 0x3f800000)         -- one
  p:op("fmv.w.x ft1, t5")
  p:op("fdiv.s ft1, ft1, ft0")
  p:op("fsw ft1, " .. at.scale .. "(a0)")
  local eps = float_bits.of(M.EPSILON)
  if eps > 2147483647 then eps = eps - 4294967296 end
  p:load_constant("t5", eps)
  p:op("sw t5, " .. at.epsilon .. "(a0)")

  local kernels = { "multiply", "k_rms_normalise", "k_rotate",
                    "k_attention_scores", "k_softmax", "k_attention_mix",
                    "k_swiglu", "k_add_into" }
  for index, name in ipairs(kernels) do
    p:op("ld t0, " .. ((index - 1) * 8) .. "(a4)")
    p:op("sd t0, " .. at[name] .. "(a0)")
  end

  local regions = { "state", "normalised", "query", "attended", "projected",
                    "gate", "up", "scores", "cache_keys", "cache_values" }
  for index, name in ipairs(regions) do
    p:op("ld t0, " .. ((index - 1) * 8) .. "(a3)")
    p:op("sd t0, " .. at[name] .. "(a0)")
  end

  p:op("ld t0, 0(a2)")
  p:op("sd t0, " .. at.token_embedding .. "(a0)")
  p:op("ld t0, 8(a2)")
  p:op("sd t0, " .. at.rotation .. "(a0)")

  p:op("ld t1, " .. at.layers .. "(a0)")
  p:load_constant("t2", #layer_names)
  p:op("mul t0, t1, t2")
  p:op("addi t0, t0, 2")                    -- past the two at the front
  p:op("slli t3, t0, 3")
  p:op("add t3, a2, t3")
  p:op("ld t4, 0(t3)")
  p:op("sd t4, " .. at.output_norm .. "(a0)")
  p:op("ld t4, 8(t3)")
  p:op("sd t4, " .. at.output .. "(a0)")

  p:op("sd a5, " .. at.layer_table .. "(a0)")
  p:op("mv t5, zero")                       -- which layer
  p:label("fp_layer")
  p:branch("bge", "t5", "t1", "fp_done")
  p:op("mv t6, zero")                       -- which of the nine
  p:label("fp_slot")
  p:branch("bge", "t6", "t2", "fp_layer_next")
  p:op("mul t0, t5, t2")
  p:op("add t0, t0, t6")                    -- the place in the table
  p:op("addi t3, t0, 2")                    -- and the tensor's index
  p:op("slli t3, t3, 3")
  p:op("add t3, a2, t3")
  p:op("ld t4, 0(t3)")
  p:op("slli t0, t0, 3")
  p:op("add t0, a5, t0")
  p:op("sd t4, 0(t0)")
  p:op("addi t6, t6, 1")
  p:jump("fp_slot")
  p:label("fp_layer_next")
  p:op("addi t5, t5, 1")
  p:jump("fp_layer")

  p:label("fp_uneven")
  p:op("addi a0, zero, -1")
  p:op("jalr zero, 0(ra)")
  p:label("fp_done")
  p:op("mv a0, zero")
  p:op("jalr zero, 0(ra)")
end
-- }}}

return M
