-- 128-say-elsewhere.lua
--
-- Saying something, as a routine anything can call, on all three machines.
-- Issue 403.
--
-- For a general: a computer that cannot be heard is debugged by watching it
-- sit still. Every payload this project has booted says things, but each one
-- spells its own words out inline as it emits them -- which works for a
-- payload that knows at build time what it will say, and is no use at all to
-- an engine that will say whatever a model produces.
--
-- So this is the same capability made callable: hand it some bytes and a
-- length and it says them.
--
-- WHY IT IS WANTED BEFORE ANYTHING ELSE THE DRIVER DOES. Every silence this
-- project has debugged was diagnosed by the last thing printed before it --
-- a call whose offset was zero, a payload entered with the firmware's
-- registers, a binary truncated at four thousand and ninety-six bytes. On a
-- machine with nothing above it, the only difference between a fault and a
-- mystery is whether something was said first.
--
-- THE FIRMWARE WANTS WIDE CHARACTERS. Its console takes two bytes per
-- character and stops at a zero, so ordinary bytes have to be widened and
-- terminated before they can be handed over. That is the whole of the work,
-- and the reason this cannot simply be a store to a port.
--
-- IT CHUNKS RATHER THAN ASSUMING ROOM. The caller says how large the scratch
-- is; anything longer is said in as many pieces as it takes. A routine that
-- assumed the buffer was big enough would write past it on exactly the long
-- message somebody was trying to read after a crash.
--
-- ONE ARCHITECTURE HAS TO SHUFFLE ITS ARGUMENTS AND TWO DO NOT, and that is
-- worth knowing before reading the first of them. Firmware on the first
-- architecture is called by a different convention than the rest of that
-- architecture's code uses -- arguments in c, d, r8, r9 rather than di, si,
-- d, c -- so calling into it means moving things first, and leaving it room
-- on the stack it never uses but expects to exist. On the other two,
-- firmware is called exactly the way everything else is.

local M = {}

-- {{{ M.CONSOLE_OUTPUT_STRING -- where the firmware keeps the routine
--
-- The console protocol's second function, eight bytes in: reset is first,
-- output is second. Named rather than written inline, because a bare number
-- in the middle of assembly is the shape mistakes hide in -- the same
-- reasoning `069` gives for its own table of offsets.
M.CONSOLE_OUTPUT_STRING = 8
-- }}}

-- {{{ M.x86_64()
--
-- void console_say(void *console, const uint8_t *bytes, int64_t length,
--                  uint16_t *scratch, int64_t capacity)
--
-- console rdi, bytes rsi, length rdx, scratch rcx, capacity r8.
--
-- THE FORTY BYTES TAKEN OFF THE STACK ARE NOT SCRATCH. Firmware here is
-- called by a convention that requires the caller to leave thirty-two bytes
-- below the return address which the callee may use for its own arguments,
-- and to have the stack sixteen-byte aligned at the call. The routine never
-- reads those bytes. Not leaving them is the kind of fault that appears on
-- one firmware and not another.
function M.x86_64()
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl console_say")
  line("  .type console_say, @function")
  line("console_say:")
  line("  pushq %rbx")
  line("  pushq %rbp")
  line("  pushq %r12")
  line("  pushq %r13")
  line("  pushq %r14")
  line("  pushq %r15")
  line("  subq $40, %rsp")            -- what firmware expects to exist
  line("  movq %rdi, %r12")           -- the console
  line("  movq %rsi, %r13")           -- the bytes
  line("  movq %rdx, %r14")           -- how many
  line("  movq %rcx, %r15")           -- somewhere to widen them into
  line("  movq %r8, %rbx")            -- and how much room that is
  line("  xorl %ebp, %ebp")           -- how many have been said

  line("say_chunk:")
  line("  cmpq %r14, %rbp")
  line("  jge say_done")
  line("  xorl %eax, %eax")           -- how many in this chunk
  line("say_fill:")
  line("  cmpq %r14, %rbp")
  line("  jge say_fill_done")
  line("  leaq -1(%rbx), %r9")        -- one short, for the ending zero
  line("  cmpq %r9, %rax")
  line("  jge say_fill_done")
  line("  movzbl (%r13,%rbp), %r10d")
  line("  movw %r10w, (%r15,%rax,2)")
  line("  incq %rbp")
  line("  incq %rax")
  line("  jmp say_fill")
  line("say_fill_done:")
  line("  movw $0, (%r15,%rax,2)")    -- firmware stops at a zero
  line("  movq %r12, %rcx")           -- and wants its arguments elsewhere
  line("  movq %r15, %rdx")
  line("  movq " .. M.CONSOLE_OUTPUT_STRING .. "(%r12), %rax")
  line("  callq *%rax")
  line("  jmp say_chunk")

  line("say_done:")
  line("  addq $40, %rsp")
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

-- {{{ M.aarch64()
--
-- void console_say(void *console, const uint8_t *bytes, int64_t length,
--                  uint16_t *scratch, int64_t capacity)
--
-- console x0, bytes x1, length x2, scratch x3, capacity x4.
--
-- Firmware here is called the same way everything else is, so there is no
-- shuffling and no room to leave. What there is instead is the return
-- address, which must be saved because this routine calls something -- and
-- losing it is not a wrong answer but a machine that never comes back.
function M.aarch64()
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl console_say")
  line("  .type console_say, @function")
  line("console_say:")
  line("  stp x29, x30, [sp, #-64]!")
  line("  mov x29, sp")
  line("  stp x19, x20, [sp, #16]")
  line("  stp x21, x22, [sp, #32]")
  line("  stp x23, x24, [sp, #48]")
  line("  mov x19, x0")               -- the console
  line("  mov x20, x1")               -- the bytes
  line("  mov x21, x2")               -- how many
  line("  mov x22, x3")               -- somewhere to widen them into
  line("  mov x23, x4")               -- and how much room that is
  line("  mov x24, xzr")              -- how many have been said

  line("say_chunk:")
  line("  cmp x24, x21")
  line("  b.ge say_done")
  line("  mov x5, xzr")               -- how many in this chunk
  line("say_fill:")
  line("  cmp x24, x21")
  line("  b.ge say_fill_done")
  line("  sub x6, x23, #1")           -- one short, for the ending zero
  line("  cmp x5, x6")
  line("  b.ge say_fill_done")
  line("  ldrb w7, [x20, x24]")
  line("  strh w7, [x22, x5, lsl #1]")
  line("  add x24, x24, #1")
  line("  add x5, x5, #1")
  line("  b say_fill")
  line("say_fill_done:")
  line("  strh wzr, [x22, x5, lsl #1]")   -- firmware stops at a zero
  line("  mov x0, x19")
  line("  mov x1, x22")
  line("  ldr x8, [x19, #" .. M.CONSOLE_OUTPUT_STRING .. "]")
  line("  blr x8")
  line("  b say_chunk")

  line("say_done:")
  line("  ldp x19, x20, [sp, #16]")
  line("  ldp x21, x22, [sp, #32]")
  line("  ldp x23, x24, [sp, #48]")
  line("  ldp x29, x30, [sp], #64")
  line("  ret")
  line("")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.riscv64(p)
--
-- void console_say(void *console, const uint8_t *bytes, int64_t length,
--                  uint16_t *scratch, int64_t capacity)
--
-- console a0, bytes a1, length a2, scratch a3, capacity a4.
--
-- Emitted into a counted program rather than returned as text, because this
-- assembler leaves a relocation on a branch to a label in its own file and
-- there is no linker to answer it -- so every loop here would be a silent
-- infinite one, which is a particularly unkind way for the routine that
-- exists to break silences to fail (054).
function M.riscv64(p)
  p:label("console_say")
  p:op("addi sp, sp, -64")
  p:op("sd ra, 0(sp)")
  for index = 0, 5 do
    p:op("sd s" .. index .. ", " .. (8 + index * 8) .. "(sp)")
  end
  p:op("mv s0, a0")                   -- the console
  p:op("mv s1, a1")                   -- the bytes
  p:op("mv s2, a2")                   -- how many
  p:op("mv s3, a3")                   -- somewhere to widen them into
  p:op("mv s4, a4")                   -- and how much room that is
  p:op("mv s5, zero")                 -- how many have been said

  p:label("say_chunk")
  p:branch("bge", "s5", "s2", "say_done")
  p:op("mv t0, zero")                 -- how many in this chunk
  p:label("say_fill")
  p:branch("bge", "s5", "s2", "say_fill_done")
  p:op("addi t1, s4, -1")             -- one short, for the ending zero
  p:branch("bge", "t0", "t1", "say_fill_done")
  p:op("add t2, s1, s5")
  p:op("lbu t2, 0(t2)")
  p:op("slli t3, t0, 1")
  p:op("add t3, s3, t3")
  p:op("sh t2, 0(t3)")
  p:op("addi s5, s5, 1")
  p:op("addi t0, t0, 1")
  p:jump("say_fill")
  p:label("say_fill_done")
  p:op("slli t3, t0, 1")
  p:op("add t3, s3, t3")
  p:op("sh zero, 0(t3)")              -- firmware stops at a zero
  p:op("mv a0, s0")
  p:op("mv a1, s3")
  p:op("ld t0, " .. M.CONSOLE_OUTPUT_STRING .. "(s0)")
  p:op("jalr ra, 0(t0)")
  p:jump("say_chunk")

  p:label("say_done")
  p:op("ld ra, 0(sp)")
  for index = 0, 5 do
    p:op("ld s" .. index .. ", " .. (8 + index * 8) .. "(sp)")
  end
  p:op("addi sp, sp, 64")
  p:op("jalr zero, 0(ra)")
end
-- }}}

return M
