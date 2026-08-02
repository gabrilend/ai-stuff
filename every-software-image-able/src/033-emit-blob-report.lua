-- 033-emit-blob-report.lua
--
-- Generates a payload that finds the packed model riding inside its own image,
-- reads its header aloud, reads the memory map the firmware leaves behind, and
-- computes -- before touching anything -- which memory strategy the machine can
-- afford. This is issue 102 whole: locating the weights with no filesystem, no
-- allocator and no operating system, knowing how much room exists to think in,
-- and choosing a rung of the ratchet out loud.
--
-- For a general: the model travels inside the program that will run it. The
-- program works out where it is standing, counts forward a known distance, and
-- finds the model there. Then it asks the firmware for the map of memory,
-- adds up the ranges marked usable, checks that its own body sits outside
-- them, and says which of four arrangements of itself it can pay for --
-- fastest first, refusal last.
--
-- WHY MEASURING FROM ITSELF. Firmware may place the image anywhere, so no
-- absolute address can be written down in advance. But the distance from the
-- code to what was appended to it is fixed at build time (029), and a program
-- can always find out where it is standing. Where it is plus how far it is
-- gives an answer that is correct wherever it was put.
--
-- WHY THE RATCHET IS COMPUTED HERE AND ALSO IN 045. Two implementations of one
-- specification, on purpose -- the same reason the assembly kernels have a
-- reference (043/044). The host-side arithmetic in 045 is what the image
-- builder trusts; this payload is what the machine itself will trust; and the
-- test that boots this payload (055) requires the two to agree at the same
-- inputs. A seam checked by a test instead of discovered at first light.
--
-- All three architectures. The x86-64 and ARM assemblers finish their own
-- label arithmetic, so those two are written as ordinary assembly text. The
-- RISC-V assembler leaves every branch as a note for a linker that does not
-- exist, so that one is laid out and encoded by 054 instead.

local M = {}

-- {{{ M.MAP_BUFFER_BYTES -- room set aside for the firmware's memory map
--
-- On the emulated boards the map is a few kilobytes. Twenty-four covers it
-- several times over; if it ever does not, the payload says so and halts
-- rather than reading a truncated map as if it were whole.
M.MAP_BUFFER_BYTES = 24576
-- }}}

-- {{{ M.WORDING -- every string the payload prints, in one place
--
-- The test that boots this payload (055) parses the console against these
-- exact strings, so they live here rather than twice. The rung names match
-- 045's strategy names for the same reason: one wording, two implementations,
-- and anything that drifts is caught by comparison rather than by a reader.
M.WORDING = {
  found = "found a packed model inside myself",
  map_heading = "the memory map, as firmware tells it",
  map_failed = "the map did not fit in the space set aside for it",
  outside = "the image outside every usable range: ",
  outside_ok = "ok",
  outside_no = "NO",
  ratchet_heading = "the ratchet, computed before anything moves",
  rung = "rung: ",
  rungs = {
    "everything in memory",
    "the hot parts in memory, the rest read in place",
    "everything read in place",
  },
  refuse_before = "does not fit -- needs ",
  refuse_after = " with no weights at all",
}
-- }}}

-- {{{ local function utf16_shorts(text)
-- The firmware's console takes sixteen bits per character, so a message is
-- emitted as halfwords rather than bytes.
local function utf16_shorts(text)
  local out = {}
  for index = 1, #text do
    out[#out + 1] = "  .short " .. text:byte(index)
  end
  out[#out + 1] = "  .short 0"
  return out
end
-- }}}

-- {{{ local function value_label(name)
-- "  total      " -- the fixed-width label a value line opens with, shared
-- with the header report's style so the console reads as one table.
local function value_label(name)
  return string.format("  %-11s", name)
end
-- }}}

-- {{{ M.field_offsets(format)
-- Where each header field sits, computed from the layout description rather
-- than counted by hand. Counting by hand is how this payload first reported a
-- model with a hundred and seventy-six word vocabulary and a size of zero --
-- two offsets off by a field, producing numbers that looked like numbers.
--
-- The packer, the reader and this payload now all measure from one source, so
-- they cannot drift apart.
function M.field_offsets(format)
  local at, offsets = 0, {}
  for _, field in ipairs(format.HEADER) do
    offsets[field.name] = at
    at = at + field.size
  end
  return offsets
end
-- }}}

-- {{{ HEADER_REPORT -- what the first section reads out, and from which field
local HEADER_REPORT = {
  { "magic      ", "magic" },
  { "version    ", "version" },
  { "layers     ", "layers" },
  { "hidden     ", "hidden" },
  { "heads      ", "heads" },
  { "vocabulary ", "vocabulary" },
  { "context    ", "context" },
  { "tensors    ", "tensor_count" },
  { "tokens     ", "token_count" },
  { "bytes      ", "blob_bytes" },
}
-- }}}

-- {{{ local function field_at(offsets, name)
local function field_at(offsets, name)
  local at = offsets[name]
  if at == nil then
    error("033-emit-blob-report: the format has no field called '" .. name .. "'")
  end
  return at
end
-- }}}

-- {{{ M.x86_64(geometry, offsets)
--
-- Firmware hands the image handle in rcx and its own table in rdx, and every
-- call into it wants thirty-two bytes of scratch above the return address.
-- Values that must survive those calls live in the registers the firmware is
-- obliged to give back: r12 the code base, r13 the blob, r14 the system
-- table, r15 the console, rbp the usable total, rbx the weights, rdi the
-- cache cost, rsi the working cost.
function M.x86_64(geometry, offsets)
  local blob_offset = geometry.blob_offset
  local engine_bytes = geometry.text_rva + blob_offset
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .code64")
  line("  .globl _start")
  line("_start:")
  -- A LOCAL label beside the global one, and everything below measures from
  -- this rather than from `_start`. A reference to a global symbol is a
  -- relocation -- a note for a linker -- and with no linker the note is
  -- dropped and a zero is left, so `leaq _start(%rip)` assembled to the
  -- address of the *next* instruction. Everything measured from it was two
  -- dozen bytes out, and the payload printed plausible nonsense.
  line("here:")

  -- The stack, laid out once:
  --   0x00..0x3f   scratch the firmware's calls are owed, and the fifth
  --                argument slot for the one call that has five
  --   0x40..0x67   where hexadecimal is spelled out before printing
  --   0x68..0x87   what GetMemoryMap fills in: size, key, stride, version
  --   0x88, 0x90   where this image begins and ends in memory
  --   0x98         whether the image sits outside every usable range
  --   0x100..      the map itself
  -- The total keeps rsp sixteen-aligned at every call site.
  line("  subq $" .. (M.MAP_BUFFER_BYTES + 0x100 + 8) .. ", %rsp")
  line("  movq %rdx, %r14")                  -- the firmware's table, kept
  line("  movq 64(%r14), %r15")              -- its console, kept

  -- where we are standing, plus how far the model is: its address.
  line("  leaq here(%rip), %r12")
  line("  leaq " .. string.format("0x%x", blob_offset) .. "(%r12), %r13")

  -- {{{ say_text and the hexadecimal printers
  local said = 0
  local function say_text(text)
    said = said + 1
    local skip = "skip" .. said
    local label = "text" .. said
    -- the jump comes first. A string laid down in the middle of the
    -- instruction stream is perfectly good data and perfectly terrible
    -- instructions, so nothing must be allowed to fall into it.
    line("  jmp " .. skip)
    line(label .. ":")
    for _, entry in ipairs(utf16_shorts(text)) do line(entry) end
    line(skip .. ":")
    line("  leaq " .. label .. "(%rip), %rdx")
    line("  movq %r15, %rcx")
    line("  movq 8(%r15), %rax")
    line("  callq *%rax")
  end

  -- Spells the value in rax as hexadecimal on the stack, highest four bits
  -- first, then prints it. Built a character at a time because there is
  -- nowhere else to put it and nothing to convert it with.
  local converted = 0
  local function say_hex_rax(digits)
    converted = converted + 1
    local loop = "hex" .. converted
    local digit = "digit" .. converted
    local done = "hexdone" .. converted

    if digits < 16 then
      -- fewer digits: pre-shift so the rotation's first nibble down is the
      -- highest one the caller cares about, not the zeros above it.
      line("  shlq $" .. (64 - 4 * digits) .. ", %rax")
    end
    line("  leaq 64(%rsp), %r11")
    line("  movq $" .. digits .. ", %rcx")
    line(loop .. ":")
    line("  rolq $4, %rax")               -- highest four bits down
    line("  movl %eax, %edx")
    line("  andl $15, %edx")              -- just those four
    line("  cmpl $10, %edx")
    line("  jl " .. digit)
    line("  addl $87, %edx")              -- ten becomes 'a'
    line("  jmp " .. done)
    line(digit .. ":")
    line("  addl $48, %edx")              -- zero becomes '0'
    line(done .. ":")
    line("  movw %dx, (%r11)")            -- sixteen bits per character
    line("  addq $2, %r11")
    line("  decq %rcx")
    line("  jnz " .. loop)
    line("  movw $0, (%r11)")             -- and a nothing to end it

    line("  leaq 64(%rsp), %rdx")
    line("  movq %r15, %rcx")
    line("  movq 8(%r15), %rax")
    line("  callq *%rax")
  end

  local function say_hex_field(name)
    -- the thirty-two bit number at a distance into the blob, as eight
    -- characters. Header numbers are all held in thirty-two bits except the
    -- section offsets, and the report prints the half that is ever nonzero.
    line("  movl " .. field_at(offsets, name) .. "(%r13), %eax")
    say_hex_rax(8)
  end
  -- }}}

  -- {{{ the header, read aloud
  say_text("\r\n" .. M.WORDING.found .. "\r\n")
  for _, entry in ipairs(HEADER_REPORT) do
    say_text("  " .. entry[1])
    say_hex_field(entry[2])
    say_text("\r\n")
  end
  -- }}}

  -- {{{ the memory map, asked for and walked
  say_text("\r\n" .. M.WORDING.map_heading .. "\r\n")

  -- the whole weight of the blob, this time as the full sixty-four bits,
  -- because the arithmetic below carries it rather than displaying it.
  line("  movq " .. field_at(offsets, "blob_bytes") .. "(%r13), %rbx")

  -- where this image begins and ends: the headers sit one page below the
  -- code, and the end is rounded up to the page the loader will have used.
  line("  leaq -" .. string.format("0x%x", geometry.text_rva) .. "(%r12), %rax")
  line("  movq %rax, 0x88(%rsp)")
  line("  leaq " .. string.format("0x%x", blob_offset) .. "(%r12,%rbx), %rax")
  line("  addq $4095, %rax")
  line("  andq $-4096, %rax")
  line("  movq %rax, 0x90(%rsp)")
  line("  movq $1, 0x98(%rsp)")           -- outside every usable range, until seen otherwise

  -- GetMemoryMap(&size, map, &key, &stride, &version) -- five arguments, so
  -- the fifth rides on the stack above the scratch the firmware is owed.
  line("  movq $" .. M.MAP_BUFFER_BYTES .. ", 0x68(%rsp)")
  line("  leaq 0x68(%rsp), %rcx")
  line("  leaq 0x100(%rsp), %rdx")
  line("  leaq 0x70(%rsp), %r8")
  line("  leaq 0x78(%rsp), %r9")
  line("  leaq 0x80(%rsp), %rax")
  line("  movq %rax, 0x20(%rsp)")
  line("  movq 96(%r14), %rax")           -- the boot services table
  line("  movq 56(%rax), %rax")           -- its GetMemoryMap
  line("  callq *%rax")
  line("  testq %rax, %rax")
  line("  jnz map_failed")

  -- Walk the descriptors: type 7 is conventional memory, the only kind that
  -- may be touched. Anything else -- firmware, loader allocations, the holes
  -- a board keeps for itself -- is somebody's and is passed over.
  line("  leaq 0x100(%rsp), %r8")         -- the cursor
  line("  movq 0x68(%rsp), %r9")
  line("  addq %r8, %r9")                 -- one past the last descriptor
  line("  movq 0x78(%rsp), %r10")         -- the stride the firmware chose
  line("  xorl %ebp, %ebp")               -- usable, summed
  line("walk:")
  line("  cmpq %r9, %r8")
  line("  jae walk_done")
  line("  movl (%r8), %eax")
  line("  cmpl $7, %eax")
  line("  jne walk_next")
  line("  movq 8(%r8), %rax")             -- where the range begins
  line("  movq 24(%r8), %rdx")            -- how many pages
  line("  shlq $12, %rdx")
  line("  addq %rdx, %rbp")
  -- Does this usable range touch the image? It begins below the image's end
  -- and ends above the image's beginning only if something is wrong -- the
  -- loader's own allocation should have carved the image out already. The
  -- check is the point: the rule that nothing may hand out the engine or the
  -- weights is verified against the firmware rather than assumed of it.
  line("  cmpq 0x90(%rsp), %rax")
  line("  jae walk_next")
  line("  addq %rax, %rdx")               -- rdx again: one past the range
  line("  cmpq 0x88(%rsp), %rdx")
  line("  jbe walk_next")
  line("  movq $0, 0x98(%rsp)")
  line("walk_next:")
  line("  addq %r10, %r8")
  line("  jmp walk")
  line("walk_done:")
  -- }}}

  -- {{{ what thinking will cost, from the header's own numbers
  --
  -- The same two formulas as 045, one for one: the cache is keys and values
  -- for every layer, key head, and position, four bytes each; the working
  -- set is the vectors one step holds while it happens.
  line("  movl " .. field_at(offsets, "layers") .. "(%r13), %eax")
  line("  movl " .. field_at(offsets, "kv_heads") .. "(%r13), %edx")
  line("  imulq %rdx, %rax")
  line("  movl " .. field_at(offsets, "head_width") .. "(%r13), %edx")
  line("  imulq %rdx, %rax")
  line("  movl " .. field_at(offsets, "context") .. "(%r13), %edx")
  line("  imulq %rdx, %rax")
  line("  shlq $3, %rax")                 -- times two tables, times four bytes
  line("  movq %rax, %rdi")               -- the cache, kept

  line("  movl " .. field_at(offsets, "hidden") .. "(%r13), %eax")
  line("  leaq (%rax,%rax,2), %rax")      -- state, normalised, projected
  line("  movl " .. field_at(offsets, "heads") .. "(%r13), %edx")
  line("  movl " .. field_at(offsets, "head_width") .. "(%r13), %ecx")
  line("  imulq %rcx, %rdx")
  line("  leaq (%rax,%rdx,2), %rax")      -- queries, attended
  line("  movl " .. field_at(offsets, "feedforward") .. "(%r13), %edx")
  line("  leaq (%rax,%rdx,2), %rax")      -- gate, up
  line("  movl " .. field_at(offsets, "vocabulary") .. "(%r13), %edx")
  line("  addq %rdx, %rax")               -- the scores
  line("  movl " .. field_at(offsets, "context") .. "(%r13), %edx")
  line("  addq %rdx, %rax")               -- attention over the past
  line("  shlq $2, %rax")                 -- four bytes per number
  line("  movq %rax, %rsi")               -- the working set, kept
  -- }}}

  -- {{{ the report
  say_text(value_label("total"))
  line("  leaq " .. string.format("0x%x", engine_bytes) .. "(%rbp,%rbx), %rax")
  say_hex_rax(16)
  say_text("\r\n")

  say_text(value_label("engine"))
  line("  movl $" .. string.format("0x%x", engine_bytes) .. ", %eax")
  say_hex_rax(16)
  say_text("\r\n")

  say_text(value_label("weights"))
  line("  movq %rbx, %rax")
  say_hex_rax(16)
  say_text("\r\n")

  say_text(value_label("free"))
  line("  movq %rbp, %rax")
  say_hex_rax(16)
  say_text("\r\n")

  say_text("  " .. M.WORDING.outside)
  line("  cmpq $0, 0x98(%rsp)")
  line("  jne flag_ok")
  say_text(M.WORDING.outside_no .. "\r\n")
  line("  jmp flag_done")
  line("flag_ok:")
  say_text(M.WORDING.outside_ok .. "\r\n")
  line("flag_done:")

  say_text(M.WORDING.ratchet_heading .. "\r\n")
  say_text(value_label("cache"))
  line("  movq %rdi, %rax")
  say_hex_rax(16)
  say_text("\r\n")
  say_text(value_label("working"))
  line("  movq %rsi, %rax")
  say_hex_rax(16)
  say_text("\r\n")
  -- }}}

  -- {{{ the ratchet -- fastest that fits, refusal last
  say_text("  " .. M.WORDING.rung)

  line("  leaq (%rdi,%rsi), %rax")        -- what thinking needs regardless
  line("  addq %rbx, %rax")               -- plus all of the weights
  line("  cmpq %rbp, %rax")
  line("  jbe rung1")
  line("  movq %rbx, %rax")               -- a quarter of the weights: the
  line("  shrq $2, %rax")                 -- parts touched every step
  line("  addq %rdi, %rax")
  line("  addq %rsi, %rax")
  line("  cmpq %rbp, %rax")
  line("  jbe rung2")
  line("  leaq (%rdi,%rsi), %rax")        -- none of the weights resident
  line("  cmpq %rbp, %rax")
  line("  jbe rung3")

  -- The last rung is a refusal rather than a fallback: say which number was
  -- too large and stop, rather than run unusably and let somebody guess.
  say_text(M.WORDING.refuse_before)
  line("  leaq (%rdi,%rsi), %rax")
  say_hex_rax(16)
  say_text(M.WORDING.refuse_after .. "\r\n")
  line("  jmp halt")

  line("rung1:")
  say_text(M.WORDING.rungs[1] .. "\r\n")
  line("  jmp halt")
  line("rung2:")
  say_text(M.WORDING.rungs[2] .. "\r\n")
  line("  jmp halt")
  line("rung3:")
  say_text(M.WORDING.rungs[3] .. "\r\n")
  line("  jmp halt")

  line("map_failed:")
  say_text("  " .. M.WORDING.map_failed .. "\r\n")

  line("halt:")
  line("  hlt")
  line("  jmp halt")
  line("")
  -- }}}

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.aarch64(geometry, offsets)
--
-- The same routine in the second tongue. The handle arrives in x0 and the
-- table in x1; values that must survive firmware calls live in the registers
-- the convention preserves: x19 the system table, x20 the console, x21 the
-- code base, x22 the blob, x23 the usable total, x24 the weights, x25 the
-- cache cost, x26 the working cost.
function M.aarch64(geometry, offsets)
  local blob_offset = geometry.blob_offset
  local engine_bytes = geometry.text_rva + blob_offset
  local out = {}
  local function line(text) out[#out + 1] = text end

  -- {{{ local function mov64(register, value)
  -- A constant built sixteen bits at a time: movz sets one quarter and
  -- clears the rest, movk sets one and keeps the rest. No constant pool, no
  -- relocation.
  local function mov64(register, value)
    local emitted = false
    for quarter = 0, 3 do
      local chunk = math.floor(value / 2 ^ (16 * quarter)) % 0x10000
      if chunk ~= 0 then
        local op = emitted and "movk" or "movz"
        line("  " .. op .. " " .. register .. ", #" .. string.format("0x%x", chunk)
          .. (quarter > 0 and (", lsl #" .. 16 * quarter) or ""))
        emitted = true
      end
    end
    if not emitted then
      line("  movz " .. register .. ", #0")
    end
  end
  -- }}}

  line("  .globl _start")
  line("_start:")
  line("here:")
  line("  sub sp, sp, #" .. M.MAP_BUFFER_BYTES)
  line("  sub sp, sp, #512")
  line("  mov x19, x1")                   -- the firmware's table, kept
  line("  ldr x20, [x19, #64]")           -- its console, kept
  line("  adr x21, here")                 -- where we are standing
  mov64("x9", blob_offset)
  line("  add x22, x21, x9")              -- plus how far: the model

  -- {{{ say_text and the hexadecimal printers
  local said = 0
  local function say_text(text)
    said = said + 1
    local skip = "skip" .. said
    local label = "text" .. said
    line("  b " .. skip)
    line(label .. ":")
    for _, entry in ipairs(utf16_shorts(text)) do line(entry) end
    -- instructions must land on four-byte boundaries, and a string of
    -- halfwords can leave the stream on two.
    line("  .balign 4")
    line(skip .. ":")
    line("  adr x1, " .. label)
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end

  -- Spells x9 as hexadecimal at sp+0x40, highest four bits first, prints it.
  local converted = 0
  local function say_hex_x9(digits)
    converted = converted + 1
    local loop = "hex" .. converted
    local digit = "digit" .. converted
    local done = "hexdone" .. converted

    if digits < 16 then
      -- fewer digits: pre-shift so the first nibble out is the highest one
      -- the caller cares about.
      line("  lsl x9, x9, #" .. (64 - 4 * digits))
    end
    line("  add x10, sp, #0x40")
    line("  mov w11, #" .. digits)
    line(loop .. ":")
    line("  lsr x12, x9, #60")            -- highest four bits down
    line("  lsl x9, x9, #4")
    line("  cmp w12, #10")
    line("  b.lt " .. digit)
    line("  add w12, w12, #87")           -- ten becomes 'a'
    line("  b " .. done)
    line(digit .. ":")
    line("  add w12, w12, #48")           -- zero becomes '0'
    line(done .. ":")
    line("  strh w12, [x10], #2")         -- sixteen bits per character
    line("  subs w11, w11, #1")
    line("  b.ne " .. loop)
    line("  strh wzr, [x10]")             -- and a nothing to end it

    line("  add x1, sp, #0x40")
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end

  local function say_hex_field(name)
    line("  ldr w9, [x22, #" .. field_at(offsets, name) .. "]")
    say_hex_x9(8)
  end
  -- }}}

  -- {{{ the header, read aloud
  say_text("\r\n" .. M.WORDING.found .. "\r\n")
  for _, entry in ipairs(HEADER_REPORT) do
    say_text("  " .. entry[1])
    say_hex_field(entry[2])
    say_text("\r\n")
  end
  -- }}}

  -- {{{ the memory map, asked for and walked
  say_text("\r\n" .. M.WORDING.map_heading .. "\r\n")

  -- the blob's whole size. The field sits four-aligned rather than eight;
  -- an unaligned doubleword load from ordinary memory is architectural here.
  line("  ldr x24, [x22, #" .. field_at(offsets, "blob_bytes") .. "]")

  line("  sub x27, x21, #" .. geometry.text_rva)   -- where the image begins
  mov64("x9", blob_offset)
  line("  add x28, x21, x9")
  line("  add x28, x28, x24")
  line("  add x28, x28, #4095")
  line("  and x28, x28, #0xfffffffffffff000")      -- and past its last page
  line("  mov w9, #1")
  line("  str w9, [sp, #0x98]")           -- outside every usable range, until seen otherwise

  mov64("x8", M.MAP_BUFFER_BYTES)
  line("  str x8, [sp, #0x68]")
  line("  ldr x8, [x19, #96]")            -- the boot services table
  line("  ldr x8, [x8, #56]")             -- its GetMemoryMap
  line("  add x0, sp, #0x68")
  line("  add x1, sp, #0x200")
  line("  add x2, sp, #0x70")
  line("  add x3, sp, #0x78")
  line("  add x4, sp, #0x80")
  line("  blr x8")
  line("  cbnz x0, map_failed")

  line("  add x9, sp, #0x200")            -- the cursor
  line("  ldr x10, [sp, #0x68]")
  line("  add x10, x10, x9")              -- one past the last descriptor
  line("  ldr x11, [sp, #0x78]")          -- the stride the firmware chose
  line("  mov x23, xzr")                  -- usable, summed
  line("walk:")
  line("  cmp x9, x10")
  line("  b.hs walk_done")
  line("  ldr w12, [x9]")
  line("  cmp w12, #7")                   -- conventional memory, nothing else
  line("  b.ne walk_next")
  line("  ldr x13, [x9, #8]")             -- where the range begins
  line("  ldr x14, [x9, #24]")            -- how many pages
  line("  lsl x14, x14, #12")
  line("  add x23, x23, x14")
  line("  cmp x13, x28")                  -- a usable range touching the image
  line("  b.hs walk_next")                -- would mean the loader lied
  line("  add x15, x13, x14")
  line("  cmp x15, x27")
  line("  b.ls walk_next")
  line("  str wzr, [sp, #0x98]")
  line("walk_next:")
  line("  add x9, x9, x11")
  line("  b walk")
  line("walk_done:")
  -- }}}

  -- {{{ what thinking will cost, from the header's own numbers -- 045's two
  -- formulas, one for one
  line("  ldr w9, [x22, #" .. field_at(offsets, "layers") .. "]")
  line("  ldr w10, [x22, #" .. field_at(offsets, "kv_heads") .. "]")
  line("  mul x9, x9, x10")
  line("  ldr w10, [x22, #" .. field_at(offsets, "head_width") .. "]")
  line("  mul x9, x9, x10")
  line("  ldr w10, [x22, #" .. field_at(offsets, "context") .. "]")
  line("  mul x9, x9, x10")
  line("  lsl x25, x9, #3")               -- times two tables, times four bytes

  line("  ldr w9, [x22, #" .. field_at(offsets, "hidden") .. "]")
  line("  add x9, x9, x9, lsl #1")        -- state, normalised, projected
  line("  ldr w10, [x22, #" .. field_at(offsets, "heads") .. "]")
  line("  ldr w11, [x22, #" .. field_at(offsets, "head_width") .. "]")
  line("  mul x10, x10, x11")
  line("  add x9, x9, x10, lsl #1")       -- queries, attended
  line("  ldr w10, [x22, #" .. field_at(offsets, "feedforward") .. "]")
  line("  add x9, x9, x10, lsl #1")       -- gate, up
  line("  ldr w10, [x22, #" .. field_at(offsets, "vocabulary") .. "]")
  line("  add x9, x9, x10")               -- the scores
  line("  ldr w10, [x22, #" .. field_at(offsets, "context") .. "]")
  line("  add x9, x9, x10")               -- attention over the past
  line("  lsl x26, x9, #2")               -- four bytes per number
  -- }}}

  -- {{{ the report
  say_text(value_label("total"))
  line("  add x9, x23, x24")
  mov64("x10", engine_bytes)
  line("  add x9, x9, x10")
  say_hex_x9(16)
  say_text("\r\n")

  say_text(value_label("engine"))
  mov64("x9", engine_bytes)
  say_hex_x9(16)
  say_text("\r\n")

  say_text(value_label("weights"))
  line("  mov x9, x24")
  say_hex_x9(16)
  say_text("\r\n")

  say_text(value_label("free"))
  line("  mov x9, x23")
  say_hex_x9(16)
  say_text("\r\n")

  say_text("  " .. M.WORDING.outside)
  line("  ldr w9, [sp, #0x98]")
  line("  cbnz w9, flag_ok")
  say_text(M.WORDING.outside_no .. "\r\n")
  line("  b flag_done")
  line("flag_ok:")
  say_text(M.WORDING.outside_ok .. "\r\n")
  line("flag_done:")

  say_text(M.WORDING.ratchet_heading .. "\r\n")
  say_text(value_label("cache"))
  line("  mov x9, x25")
  say_hex_x9(16)
  say_text("\r\n")
  say_text(value_label("working"))
  line("  mov x9, x26")
  say_hex_x9(16)
  say_text("\r\n")
  -- }}}

  -- {{{ the ratchet -- fastest that fits, refusal last
  say_text("  " .. M.WORDING.rung)

  line("  add x9, x25, x26")              -- what thinking needs regardless
  line("  add x10, x9, x24")              -- plus all of the weights
  line("  cmp x10, x23")
  line("  b.ls rung1")
  line("  lsr x10, x24, #2")              -- a quarter: the parts touched
  line("  add x10, x10, x9")              -- every step
  line("  cmp x10, x23")
  line("  b.ls rung2")
  line("  cmp x9, x23")                   -- none of the weights resident
  line("  b.ls rung3")

  say_text(M.WORDING.refuse_before)
  line("  add x9, x25, x26")
  say_hex_x9(16)
  say_text(M.WORDING.refuse_after .. "\r\n")
  line("  b halt")

  line("rung1:")
  say_text(M.WORDING.rungs[1] .. "\r\n")
  line("  b halt")
  line("rung2:")
  say_text(M.WORDING.rungs[2] .. "\r\n")
  line("  b halt")
  line("rung3:")
  say_text(M.WORDING.rungs[3] .. "\r\n")
  line("  b halt")

  line("map_failed:")
  say_text("  " .. M.WORDING.map_failed .. "\r\n")

  line("halt:")
  line("  wfi")
  line("  b halt")
  line("")
  -- }}}

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.riscv64(geometry, offsets)
--
-- The third tongue, laid out by 054 because this assembler finishes no label
-- arithmetic of its own. Strings live in a pool at the end rather than inline,
-- addressed as the code base plus a counted offset; every branch is a raw
-- word with the distance already inside it.
--
-- Values that must survive firmware calls live in the registers the
-- convention preserves: s1 the code base, s2 the blob, s3 the system table,
-- s4 the console, s5 the usable total, s6 the weights, s7 the cache cost,
-- s8 the working cost, s9 whether the image sits outside every usable range.
function M.riscv64(geometry, offsets)
  local words = dofile((geometry.dir or ".") .. "/src/054-riscv-words.lua")
  local p = words.new()
  local blob_offset = geometry.blob_offset
  local engine_bytes = geometry.text_rva + blob_offset

  -- {{{ the string pool -- one label per distinct text, placed at the end
  local pool, pool_order = {}, {}
  local function pooled(text)
    if not pool[text] then
      pool[text] = "string" .. (#pool_order + 1)
      pool_order[#pool_order + 1] = text
    end
    return pool[text]
  end
  -- }}}

  -- {{{ say_text and the hexadecimal printers
  local function say_text(text)
    p:address("a1", pooled(text), "s1")
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr t1")
  end

  -- Spells t0 as hexadecimal at sp+0x40, highest four bits first, prints it.
  -- The digit is converted without a branch: 39 is the distance from the
  -- character after '9' to 'a', paid only when the digit is ten or more.
  local converted = 0
  local function say_hex_t0(digits)
    converted = converted + 1
    local loop = "hexloop" .. converted

    if digits < 16 then
      p:op("slli t0, t0, " .. (64 - 4 * digits))
    end
    p:op("addi t1, sp, 0x40")
    p:op("addi t2, zero, " .. digits)
    p:op("addi a6, zero, 39")
    p:label(loop)
    p:op("srli t3, t0, 60")               -- highest four bits down
    p:op("slli t0, t0, 4")
    p:op("sltiu t4, t3, 10")              -- one when the digit is 0..9
    p:op("xori t4, t4, 1")                -- one when it is not
    p:op("mul t4, t4, a6")
    p:op("addi t5, t3, 48")               -- zero becomes '0'
    p:op("add t5, t5, t4")                -- and ten becomes 'a'
    p:op("sh t5, 0(t1)")                  -- sixteen bits per character
    p:op("addi t1, t1, 2")
    p:op("addi t2, t2, -1")
    p:branch("bne", "t2", "zero", loop)
    p:op("sh zero, 0(t1)")                -- and a nothing to end it

    p:op("addi a1, sp, 0x40")
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr t1")
  end

  local function say_hex_field(name)
    p:op("lwu t0, " .. field_at(offsets, name) .. "(s2)")
    say_hex_t0(8)
  end
  -- }}}

  -- {{{ the prologue -- the anchor must be the first instruction, because
  -- every address in the pool is measured from offset zero
  p:op("auipc s1, 0")                     -- where we are standing
  p:op("mv s3, a1")                       -- the firmware's table, kept
  p:op("ld s4, 64(s3)")                   -- its console, kept
  p:load_constant("t0", M.MAP_BUFFER_BYTES + 512)
  p:op("sub sp, sp, t0")
  p:load_constant("t0", blob_offset)
  p:op("add s2, s1, t0")                  -- plus how far: the model
  -- }}}

  -- {{{ the header, read aloud
  say_text("\r\n" .. M.WORDING.found .. "\r\n")
  for _, entry in ipairs(HEADER_REPORT) do
    say_text("  " .. entry[1])
    say_hex_field(entry[2])
    say_text("\r\n")
  end
  -- }}}

  -- {{{ the memory map, asked for and walked
  say_text("\r\n" .. M.WORDING.map_heading .. "\r\n")

  -- the blob's whole size, in two aligned halves because the field sits
  -- four-aligned and this architecture is allowed to mind.
  local blob_bytes_at = field_at(offsets, "blob_bytes")
  p:op("lwu t0, " .. blob_bytes_at .. "(s2)")
  p:op("lwu t1, " .. (blob_bytes_at + 4) .. "(s2)")
  p:op("slli t1, t1, 32")
  p:op("or s6, t0, t1")

  p:load_constant("t0", -geometry.text_rva)
  p:op("add s10, s1, t0")                 -- where the image begins
  p:load_constant("t0", blob_offset)
  p:op("add s11, s1, t0")
  p:op("add s11, s11, s6")
  -- 4095 in three steps: an addi immediate stops at 2047.
  p:op("addi s11, s11, 2047")
  p:op("addi s11, s11, 2047")
  p:op("addi s11, s11, 1")
  p:load_constant("t0", -4096)
  p:op("and s11, s11, t0")                -- and past its last page
  p:op("addi s9, zero, 1")                -- outside every usable range, until seen otherwise

  p:load_constant("t0", M.MAP_BUFFER_BYTES)
  p:op("sd t0, 0x68(sp)")
  p:op("ld t1, 96(s3)")                   -- the boot services table
  p:op("ld t1, 56(t1)")                   -- its GetMemoryMap
  p:op("addi a0, sp, 0x68")
  p:op("addi a1, sp, 512")
  p:op("addi a2, sp, 0x70")
  p:op("addi a3, sp, 0x78")
  p:op("addi a4, sp, 0x80")
  p:op("jalr t1")
  -- a conditional branch reaches four kilobytes and the refusal sits past
  -- the whole report, so the branch guards a jump instead of taking it.
  p:branch("beq", "a0", "zero", "map_ok")
  p:jump("map_failed")
  p:label("map_ok")

  p:op("addi t0, sp, 512")                -- the cursor
  p:op("ld t1, 0x68(sp)")
  p:op("add t1, t1, t0")                  -- one past the last descriptor
  p:op("ld t2, 0x78(sp)")                 -- the stride the firmware chose
  p:op("mv s5, zero")                     -- usable, summed
  p:label("walk")
  p:branch("bgeu", "t0", "t1", "walk_done")
  p:op("lwu t3, 0(t0)")
  p:op("addi t4, zero, 7")                -- conventional memory, nothing else
  p:branch("bne", "t3", "t4", "walk_next")
  p:op("ld t5, 8(t0)")                    -- where the range begins
  p:op("ld t6, 24(t0)")                   -- how many pages
  p:op("slli t6, t6, 12")
  p:op("add s5, s5, t6")
  -- a usable range touching the image would mean the loader lied.
  p:branch("bgeu", "t5", "s11", "walk_next")
  p:op("add a5, t5, t6")
  p:branch("bgeu", "s10", "a5", "walk_next")
  p:op("addi s9, zero, 0")
  p:label("walk_next")
  p:op("add t0, t0, t2")
  p:jump("walk")
  p:label("walk_done")
  -- }}}

  -- {{{ what thinking will cost, from the header's own numbers -- 045's two
  -- formulas, one for one
  p:op("lwu t0, " .. field_at(offsets, "layers") .. "(s2)")
  p:op("lwu t1, " .. field_at(offsets, "kv_heads") .. "(s2)")
  p:op("mul t0, t0, t1")
  p:op("lwu t1, " .. field_at(offsets, "head_width") .. "(s2)")
  p:op("mul t0, t0, t1")
  p:op("lwu t1, " .. field_at(offsets, "context") .. "(s2)")
  p:op("mul t0, t0, t1")
  p:op("slli s7, t0, 3")                  -- times two tables, times four bytes

  p:op("lwu t0, " .. field_at(offsets, "hidden") .. "(s2)")
  p:op("slli t1, t0, 1")
  p:op("add t0, t0, t1")                  -- state, normalised, projected
  p:op("lwu t1, " .. field_at(offsets, "heads") .. "(s2)")
  p:op("lwu t2, " .. field_at(offsets, "head_width") .. "(s2)")
  p:op("mul t1, t1, t2")
  p:op("slli t1, t1, 1")
  p:op("add t0, t0, t1")                  -- queries, attended
  p:op("lwu t1, " .. field_at(offsets, "feedforward") .. "(s2)")
  p:op("slli t1, t1, 1")
  p:op("add t0, t0, t1")                  -- gate, up
  p:op("lwu t1, " .. field_at(offsets, "vocabulary") .. "(s2)")
  p:op("add t0, t0, t1")                  -- the scores
  p:op("lwu t1, " .. field_at(offsets, "context") .. "(s2)")
  p:op("add t0, t0, t1")                  -- attention over the past
  p:op("slli s8, t0, 2")                  -- four bytes per number
  -- }}}

  -- {{{ the report
  say_text(value_label("total"))
  p:load_constant("t0", engine_bytes)
  p:op("add t0, t0, s5")
  p:op("add t0, t0, s6")
  say_hex_t0(16)
  say_text("\r\n")

  say_text(value_label("engine"))
  p:load_constant("t0", engine_bytes)
  say_hex_t0(16)
  say_text("\r\n")

  say_text(value_label("weights"))
  p:op("mv t0, s6")
  say_hex_t0(16)
  say_text("\r\n")

  say_text(value_label("free"))
  p:op("mv t0, s5")
  say_hex_t0(16)
  say_text("\r\n")

  say_text("  " .. M.WORDING.outside)
  p:branch("bne", "s9", "zero", "flag_ok")
  say_text(M.WORDING.outside_no .. "\r\n")
  p:jump("flag_done")
  p:label("flag_ok")
  say_text(M.WORDING.outside_ok .. "\r\n")
  p:label("flag_done")

  say_text(M.WORDING.ratchet_heading .. "\r\n")
  say_text(value_label("cache"))
  p:op("mv t0, s7")
  say_hex_t0(16)
  say_text("\r\n")
  say_text(value_label("working"))
  p:op("mv t0, s8")
  say_hex_t0(16)
  say_text("\r\n")
  -- }}}

  -- {{{ the ratchet -- fastest that fits, refusal last
  say_text("  " .. M.WORDING.rung)

  p:op("add t0, s7, s8")                  -- what thinking needs regardless
  p:op("add t1, t0, s6")                  -- plus all of the weights
  p:branch("bgeu", "s5", "t1", "rung1")
  p:op("srli t2, s6, 2")                  -- a quarter: the parts touched
  p:op("add t1, t0, t2")                  -- every step
  p:branch("bgeu", "s5", "t1", "rung2")
  p:branch("bgeu", "s5", "t0", "rung3")

  say_text(M.WORDING.refuse_before)
  p:op("add t0, s7, s8")
  say_hex_t0(16)
  say_text(M.WORDING.refuse_after .. "\r\n")
  p:jump("halt")

  p:label("rung1")
  say_text(M.WORDING.rungs[1] .. "\r\n")
  p:jump("halt")
  p:label("rung2")
  say_text(M.WORDING.rungs[2] .. "\r\n")
  p:jump("halt")
  p:label("rung3")
  say_text(M.WORDING.rungs[3] .. "\r\n")
  p:jump("halt")

  p:label("map_failed")
  say_text("  " .. M.WORDING.map_failed .. "\r\n")

  p:label("halt")
  p:op("wfi")
  p:jump("halt")
  -- }}}

  -- {{{ the pool itself
  for _, text in ipairs(pool_order) do
    p:label(pool[text])
    p:shorts(text)
  end
  -- }}}

  local text = p:resolve()
  return text
end
-- }}}

return M
