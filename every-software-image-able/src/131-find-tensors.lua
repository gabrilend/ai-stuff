-- 131-find-tensors.lua
--
-- Locating every tensor in a packed model, on a bare machine, in all three
-- tongues. The first piece of the driver (issue 107).
--
-- For a general: the engine needs to be handed the address of every table of
-- weights before it can think. Hosted, a program asks the operating system to
-- map a file and gets pointers back. On a bare machine there is no operating
-- system, no file and no map -- there is a run of bytes somewhere in memory,
-- and this walks it.
--
-- WHY THIS IS THE PIECE TO WRITE FIRST. It is the one whose failure is
-- silence. An address computed slightly wrong does not produce an error: it
-- produces a number, which the arithmetic multiplies happily, and the machine
-- thinks something that means nothing. Or it points into the engine's own
-- instructions, and the next thing that writes there stops the machine
-- permanently. Nothing above it is watching, because this project has
-- nothing above it.
--
-- BY INDEX, NOT BY NAME. Every entry in the model carries a thirty-two byte
-- name, and matching those in assembly would mean string comparison in the
-- one routine that must not be clever. It is not needed: the packer writes
-- the tensors in a fixed order that `034` decides -- what a token means,
-- then the carried turns, then nine per layer, then the two at the end -- so
-- the third tensor of the fourth layer is at an index arithmetic can find.
--
-- That is a real dependency and it is worth stating plainly rather than
-- discovering: **if the packing order ever changes, this reads the wrong
-- tensors and says nothing.** The order is checked against the names in the
-- test rather than trusted, which is the only place the names are read at
-- all.
--
-- WHAT IT REFUSES. A model claiming fewer tensors than were asked for, and a
-- tensor whose bytes run past the end of the blob. Both are cheap to check
-- here and impossible to notice later: the first hands back an address that
-- was never written, and the second hands back one that is off the end of
-- everything.

-- WHY THE HEADER'S SIXTY-FOUR BIT FIELDS ARE READ IN HALVES. Three of them
-- sit at offsets that are not multiples of eight -- the header grew by
-- four-byte counts and eight-byte offsets in whatever order made sense to a
-- reader, and nothing ever needed them aligned before, because the host reads
-- them with a language that does not care.
--
-- A processor may or may not care, and that is the problem. The first
-- architecture loads an unaligned eight bytes without comment. The other two
-- are permitted to fault on it, and whether they do depends on a bit the
-- FIRMWARE sets before handing over -- so the same instructions can work on
-- one board and raise an exception with no handler on another of the same
-- kind. This project has met that shape of difference before and writes it
-- down rather than discovering it: `notes/023`.
--
-- Measured, so the claim is not louder than the evidence: the boards here
-- tolerate it, and this was changed on principle rather than after a fault.
-- Both halves are loaded as four bytes each and joined. It costs one
-- instruction and removes the dependency on what firmware decided.

local M = {}

-- {{{ M.HEADER_AT and M.ENTRY_AT -- computed from the format, not written
--
-- Asked rather than transcribed. The offsets below are the difference
-- between reading a model and reading noise, and a hand-copied number that
-- drifts by four produces a machine that thinks confidently about nothing.
function M.offsets(format)
  local header, at = {}, 0
  for _, field in ipairs(format.HEADER) do
    header[field.name] = at
    at = at + field.size
  end
  local entry, e = {}, 0
  for _, field in ipairs(format.TENSOR_ENTRY) do
    entry[field.name] = e
    e = e + field.size
  end
  return header, entry, format.tensor_entry_size()
end
-- }}}

-- {{{ M.x86_64(format)
--
-- int64_t find_tensors(const uint8_t *blob, const void **out, int64_t wanted)
--
-- blob rdi, out rsi, wanted rdx. Returns how many were written, or minus one
-- if the model holds fewer than were asked for, or minus two if any of them
-- claims bytes past the end of the blob.
--
-- The refusals are distinct numbers rather than one, because they mean
-- different things to whoever is reading a serial port: the first is a model
-- that does not match the engine, the second is a truncated one.
function M.x86_64(format)
  local header, entry, entry_size = M.offsets(format)
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl find_tensors")
  line("  .type find_tensors, @function")
  line("find_tensors:")
  line("  pushq %rbx")
  line("  pushq %r12")
  line("  pushq %r13")

  -- fewer tensors than asked for is a model that does not match the engine
  line("  movl " .. header.tensor_count .. "(%rdi), %eax")
  line("  cmpq %rdx, %rax")
  line("  jl ft_too_few")

  line("  movq " .. header.tensor_table .. "(%rdi), %r11")
  line("  addq %rdi, %r11")                 -- where the entries begin
  line("  movq " .. header.blob_bytes .. "(%rdi), %r12")
  line("  xorl %r10d, %r10d")               -- which tensor

  line("ft_loop:")
  line("  cmpq %rdx, %r10")
  line("  jge ft_done")
  line("  movq " .. entry.offset .. "(%r11), %rax")   -- blob-relative
  line("  movq " .. entry.bytes .. "(%r11), %rbx")
  -- a tensor claiming to run past the end is a truncated model, and every
  -- address after it is meaningless
  line("  movq %rax, %r13")
  line("  addq %rbx, %r13")
  line("  cmpq %r12, %r13")
  line("  ja ft_past_end")
  line("  addq %rdi, %rax")                 -- and now an address
  line("  movq %rax, (%rsi,%r10,8)")
  line("  addq $" .. entry_size .. ", %r11")
  line("  incq %r10")
  line("  jmp ft_loop")

  line("ft_too_few:")
  line("  movq $-1, %rax")
  line("  jmp ft_return")
  line("ft_past_end:")
  line("  movq $-2, %rax")
  line("  jmp ft_return")
  line("ft_done:")
  line("  movq %r10, %rax")
  line("ft_return:")
  line("  popq %r13")
  line("  popq %r12")
  line("  popq %rbx")
  line("  retq")
  line("")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.aarch64(format)
--
-- blob x0, out x1, wanted x2. Same returns.
function M.aarch64(format)
  local header, entry, entry_size = M.offsets(format)
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl find_tensors")
  line("  .type find_tensors, @function")
  line("find_tensors:")
  line("  ldr w3, [x0, #" .. header.tensor_count .. "]")
  line("  cmp x3, x2")
  line("  b.lt ft_too_few")

  line("  ldr w4, [x0, #" .. header.tensor_table .. "]")
  line("  ldr w9, [x0, #" .. (header.tensor_table + 4) .. "]")
  line("  orr x4, x4, x9, lsl #32")         -- in halves; see the header
  line("  add x4, x4, x0")                  -- where the entries begin
  line("  ldr w5, [x0, #" .. header.blob_bytes .. "]")
  line("  ldr w9, [x0, #" .. (header.blob_bytes + 4) .. "]")
  line("  orr x5, x5, x9, lsl #32")
  line("  mov x6, xzr")                     -- which tensor

  line("ft_loop:")
  line("  cmp x6, x2")
  line("  b.ge ft_done")
  line("  ldr x7, [x4, #" .. entry.offset .. "]")
  line("  ldr x8, [x4, #" .. entry.bytes .. "]")
  line("  add x9, x7, x8")
  line("  cmp x9, x5")
  line("  b.hi ft_past_end")                -- unsigned: an offset is never
  line("  add x7, x7, x0")                  -- negative and a wrapped one
  line("  str x7, [x1, x6, lsl #3]")        -- must not read as small
  line("  add x4, x4, #" .. entry_size)
  line("  add x6, x6, #1")
  line("  b ft_loop")

  line("ft_too_few:")
  line("  mov x0, #-1")
  line("  ret")
  line("ft_past_end:")
  line("  mov x0, #-2")
  line("  ret")
  line("ft_done:")
  line("  mov x0, x6")
  line("  ret")
  line("")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.riscv64(p, format)
--
-- blob a0, out a1, wanted a2. Same returns.
--
-- Emitted into a counted program, because this assembler leaves a note for a
-- linker on a branch to a label in its own file and there is none to answer
-- it (054).
function M.riscv64(p, format)
  local header, entry, entry_size = M.offsets(format)

  p:label("find_tensors")
  p:op("lwu t0, " .. header.tensor_count .. "(a0)")
  p:branch("blt", "t0", "a2", "ft_too_few")

  p:op("lwu t1, " .. header.tensor_table .. "(a0)")
  p:op("lwu t5, " .. (header.tensor_table + 4) .. "(a0)")
  p:op("slli t5, t5, 32")
  p:op("or t1, t1, t5")                     -- in halves; see the header
  p:op("add t1, t1, a0")                    -- where the entries begin
  p:op("lwu t2, " .. header.blob_bytes .. "(a0)")
  p:op("lwu t5, " .. (header.blob_bytes + 4) .. "(a0)")
  p:op("slli t5, t5, 32")
  p:op("or t2, t2, t5")
  p:op("mv t3, zero")                       -- which tensor

  p:label("ft_loop")
  p:branch("bge", "t3", "a2", "ft_done")
  p:op("ld t4, " .. entry.offset .. "(t1)")
  p:op("ld t5, " .. entry.bytes .. "(t1)")
  p:op("add t6, t4, t5")
  -- unsigned, for the same reason as elsewhere: an offset is never negative,
  -- and one that has wrapped must not compare as small
  p:branch("bltu", "t2", "t6", "ft_past_end")
  p:op("add t4, t4, a0")                    -- and now an address
  p:op("slli t6, t3, 3")
  p:op("add t6, a1, t6")
  p:op("sd t4, 0(t6)")
  p:op("addi t1, t1, " .. entry_size)
  p:op("addi t3, t3, 1")
  p:jump("ft_loop")

  p:label("ft_too_few")
  p:op("addi a0, zero, -1")
  p:op("jalr zero, 0(ra)")
  p:label("ft_past_end")
  p:op("addi a0, zero, -2")
  p:op("jalr zero, 0(ra)")
  p:label("ft_done")
  p:op("mv a0, t3")
  p:op("jalr zero, 0(ra)")
end
-- }}}

-- {{{ M.expected_order(shape, shapes_module)
-- The order the packer writes tensors in, as names, so a test can check that
-- walking by index lands where walking by name would.
--
-- This is the dependency the routines above rest on, made checkable. It
-- returns what `034` decides rather than a second opinion about it.
function M.expected_order(shape, shapes_module)
  local names = {}
  for _, tensor in ipairs(shapes_module.tensors(shape)) do
    names[#names + 1] = tensor.name
  end
  return names
end
-- }}}

return M
