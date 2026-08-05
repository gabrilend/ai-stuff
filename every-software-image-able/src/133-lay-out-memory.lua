-- 133-lay-out-memory.lua
--
-- Deciding where everything a thought needs will sit, on a bare machine,
-- with no allocator. The second piece of the driver (issue 107).
--
-- For a general: running a model needs somewhere to put the cache of
-- everything thought so far and eight working vectors. Hosted, a program
-- asks for memory and is given some. Here there is nothing to ask. There is
-- a run of memory the firmware said was usable, and this divides it up.
--
-- WHY IT IS A ROUTINE AND NOT A TABLE OF CONSTANTS. The sizes depend on the
-- model, and the model is not known until the machine reads its own header.
-- A layout compiled in would mean an image that carries one model, and the
-- whole shape of this project is that the model is the operator's choice at
-- build time.
--
-- WHAT GOES WRONG WHEN THIS IS WRONG, and it is the reason this belongs in
-- the seed rather than being left to the machine: two regions that overlap
-- do not fault. The attention writes over the cache, the cache reads back
-- what attention left, and the machine thinks something that is not wrong so
-- much as unrelated. Nothing is reported, because nothing failed.
--
-- SO IT REFUSES RATHER THAN TRIMS. A machine given less room than the model
-- needs is told the number it was short by, and stops. The alternative --
-- quietly using a shorter context, or overlapping two things that are rarely
-- both live -- is how a machine ends up subtly wrong in a way that only
-- appears under load.
--
-- EVERY REGION STARTS ON A SIXTEEN-BYTE BOUNDARY. Not for speed: the vector
-- loads in the fast arithmetic read sixteen bytes at a time, and on some
-- processors an unaligned one of those faults rather than being slow. That
-- is a difference between machines this project has already written down
-- (`notes/023`) and it is cheaper to satisfy everywhere than to remember
-- where it matters.

local M = {}

-- {{{ M.REGIONS -- what a thought needs, and how large each is
--
-- Order is layout. The sizes are expressions over the model's shape rather
-- than numbers, because the shape is read at run time -- and they are
-- written here once so that the host's answer and the machine's come from
-- one description.
--
-- `numbers` is how many single-precision values the region holds, given the
-- counts the header carries.
M.REGIONS = {
  { name = "state",        numbers = function(s) return s.hidden end },
  { name = "normalised",   numbers = function(s) return s.hidden end },
  { name = "query",        numbers = function(s) return s.heads * s.head_width end },
  { name = "attended",     numbers = function(s) return s.heads * s.head_width end },
  { name = "projected",    numbers = function(s) return s.hidden end },
  { name = "gate",         numbers = function(s) return s.feedforward end },
  { name = "up",           numbers = function(s) return s.feedforward end },
  { name = "scores",       numbers = function(s) return s.context end },
  -- the two that grow with the length of a thought, and therefore dominate
  { name = "cache_keys",   numbers = function(s)
      return s.layers * s.context * s.kv_heads * s.head_width end },
  { name = "cache_values", numbers = function(s)
      return s.layers * s.context * s.kv_heads * s.head_width end },
}
-- }}}

-- {{{ M.expected(shape)
-- Where each region lands and how much room the lot needs, worked out on the
-- host. This is what the assembly is held to.
function M.expected(shape)
  local at, places = 0, {}
  for _, region in ipairs(M.REGIONS) do
    places[region.name] = at
    local bytes = region.numbers(shape) * 4
    at = at + bytes
    if at % 16 ~= 0 then at = at + (16 - at % 16) end
  end
  return places, at
end
-- }}}

-- {{{ M.header_offsets(format)
function M.header_offsets(format)
  local at, offsets = 0, {}
  for _, field in ipairs(format.HEADER) do
    offsets[field.name] = at
    at = at + field.size
  end
  return offsets
end
-- }}}

-- {{{ shared shape of the routine, described once
--
-- int64_t lay_out(const uint8_t *blob, void *room, int64_t bytes,
--                 void **out)
--
-- Reads the model's counts out of the blob's header, divides `room` into the
-- ten regions above, writes each one's address into `out` in the order
-- `M.REGIONS` names, and returns how many bytes were used -- or minus the
-- shortfall if `bytes` was not enough.
--
-- A NEGATIVE RETURN IS THE SHORTFALL, not a code. "Needs 4096 more bytes than
-- this board has" is something a person can act on; "failed" is not, and a
-- machine that cannot fit its own model is exactly the case where the number
-- is the whole of the diagnosis.
-- }}}

-- {{{ M.x86_64(format)
-- blob rdi, room rsi, bytes rdx, out rcx.
function M.x86_64(format)
  local header = M.header_offsets(format)
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl lay_out")
  line("  .type lay_out, @function")
  line("lay_out:")
  line("  pushq %rbx")
  line("  pushq %rbp")
  line("  pushq %r12")
  line("  pushq %r13")
  line("  pushq %r14")
  line("  pushq %r15")

  -- the counts this needs, read once
  line("  movl " .. header.hidden .. "(%rdi), %r8d")
  line("  movl " .. header.heads .. "(%rdi), %r9d")
  line("  movl " .. header.head_width .. "(%rdi), %r10d")
  line("  movl " .. header.feedforward .. "(%rdi), %r11d")
  line("  movl " .. header.context .. "(%rdi), %r12d")
  line("  movl " .. header.layers .. "(%rdi), %r13d")
  line("  movl " .. header.kv_heads .. "(%rdi), %r14d")

  line("  xorl %ebx, %ebx")                 -- how far in, so far

  -- each region in turn. The sizes are emitted rather than looped, because
  -- there are ten of them and a table of sizes would be a second description
  -- of what M.REGIONS already says.
  local sizes = {
    "%r8",                                  -- state: hidden
    "%r8",                                  -- normalised
    "query", "query",                       -- query, attended
    "%r8",                                  -- projected
    "%r11", "%r11",                         -- gate, up
    "%r12",                                 -- scores: context
    "cache", "cache",                       -- keys, values
  }

  -- the two computed widths, worked out once
  line("  movq %r9, %r15")
  line("  imulq %r10, %r15")                -- query width: heads * head_width
  line("  movq %r13, %rax")
  line("  imulq %r12, %rax")                -- layers * context
  line("  imulq %r14, %rax")                -- * kv_heads
  line("  imulq %r10, %rax")                -- * head_width
  -- the cache's count, kept in a register rather than below the stack
  -- pointer. That region is legal for a routine that calls nothing, and this
  -- calls nothing -- but "legal as long as nobody adds a call" is exactly the
  -- kind of condition that stops being true quietly.
  line("  movq %rax, %rbp")

  for index, size in ipairs(sizes) do
    -- the address this region begins at
    line("  movq %rsi, %rax")
    line("  addq %rbx, %rax")
    line("  movq %rax, " .. ((index - 1) * 8) .. "(%rcx)")
    -- and how far that carries us
    if size == "query" then
      line("  movq %r15, %rax")
    elseif size == "cache" then
      line("  movq %rbp, %rax")
    else
      line("  movq " .. size .. ", %rax")
    end
    line("  shlq $2, %rax")                 -- four bytes a number
    line("  addq %rax, %rbx")
    -- onto a sixteen-byte boundary
    line("  addq $15, %rbx")
    line("  andq $-16, %rbx")
  end

  -- does it fit
  line("  cmpq %rdx, %rbx")
  line("  jg lo_short")
  line("  movq %rbx, %rax")
  line("  jmp lo_return")
  line("lo_short:")
  line("  movq %rdx, %rax")
  line("  subq %rbx, %rax")                 -- negative: the shortfall
  line("lo_return:")
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

-- {{{ M.aarch64(format)
-- blob x0, room x1, bytes x2, out x3.
function M.aarch64(format)
  local header = M.header_offsets(format)
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl lay_out")
  line("  .type lay_out, @function")
  line("lay_out:")
  line("  ldr w4, [x0, #" .. header.hidden .. "]")
  line("  ldr w5, [x0, #" .. header.heads .. "]")
  line("  ldr w6, [x0, #" .. header.head_width .. "]")
  line("  ldr w7, [x0, #" .. header.feedforward .. "]")
  line("  ldr w9, [x0, #" .. header.context .. "]")
  line("  ldr w10, [x0, #" .. header.layers .. "]")
  line("  ldr w11, [x0, #" .. header.kv_heads .. "]")

  line("  mul x12, x5, x6")                 -- query width
  line("  mul x13, x10, x9")                -- layers * context
  line("  mul x13, x13, x11")               -- * kv_heads
  line("  mul x13, x13, x6")                -- * head_width, the cache's count

  line("  mov x14, xzr")                    -- how far in, so far

  local sizes = { "x4", "x4", "x12", "x12", "x4", "x7", "x7", "x9",
                  "x13", "x13" }
  for index, size in ipairs(sizes) do
    line("  add x15, x1, x14")
    line("  str x15, [x3, #" .. ((index - 1) * 8) .. "]")
    line("  lsl x15, " .. size .. ", #2")   -- four bytes a number
    line("  add x14, x14, x15")
    line("  add x14, x14, #15")
    line("  and x14, x14, #-16")
  end

  line("  cmp x14, x2")
  line("  b.gt lo_short")
  line("  mov x0, x14")
  line("  ret")
  line("lo_short:")
  line("  sub x0, x2, x14")                 -- negative: the shortfall
  line("  ret")
  line("")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.riscv64(p, format)
-- blob a0, room a1, bytes a2, out a3.
function M.riscv64(p, format)
  local header = M.header_offsets(format)

  p:label("lay_out")
  p:op("lwu t0, " .. header.hidden .. "(a0)")
  p:op("lwu t1, " .. header.heads .. "(a0)")
  p:op("lwu t2, " .. header.head_width .. "(a0)")
  p:op("lwu t3, " .. header.feedforward .. "(a0)")
  p:op("lwu t4, " .. header.context .. "(a0)")
  p:op("lwu t5, " .. header.layers .. "(a0)")
  p:op("lwu t6, " .. header.kv_heads .. "(a0)")

  p:op("mul a4, t1, t2")                    -- query width
  p:op("mul a5, t5, t4")                    -- layers * context
  p:op("mul a5, a5, t6")                    -- * kv_heads
  p:op("mul a5, a5, t2")                    -- * head_width, the cache's count

  p:op("mv a6, zero")                       -- how far in, so far
  p:load_constant("a7", -16)                -- the alignment mask, built once

  local sizes = { "t0", "t0", "a4", "a4", "t0", "t3", "t3", "t4",
                  "a5", "a5" }
  for index, size in ipairs(sizes) do
    p:op("add t1, a1, a6")
    p:op("sd t1, " .. ((index - 1) * 8) .. "(a3)")
    p:op("slli t1, " .. size .. ", 2")      -- four bytes a number
    p:op("add a6, a6, t1")
    p:op("addi a6, a6, 15")
    p:op("and a6, a6, a7")
  end

  p:branch("blt", "a2", "a6", "lo_short")
  p:op("mv a0, a6")
  p:op("jalr zero, 0(ra)")
  p:label("lo_short")
  p:op("sub a0, a2, a6")                    -- negative: the shortfall
  p:op("jalr zero, 0(ra)")
end
-- }}}

return M
