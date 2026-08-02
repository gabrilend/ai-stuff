-- 033-emit-blob-report.lua
--
-- Generates a payload that finds the packed model riding inside its own image
-- and reads its header aloud. This is issue 102 in the small: locating the
-- weights with no filesystem, no allocator and no operating system, then
-- proving it by saying what was found.
--
-- For a general: the model travels inside the program that will run it. The
-- program works out where it is standing, counts forward a known distance, and
-- finds the model there -- no directory, no file name, nothing to ask.
--
-- WHY MEASURING FROM ITSELF. Firmware may place the image anywhere, so no
-- absolute address can be written down in advance. But the distance from the
-- code to what was appended to it is fixed at build time (029), and a program
-- can always find out where it is standing. Where it is plus how far it is
-- gives an answer that is correct wherever it was put.
--
-- Only x86-64 for now. The other two need the same routine written again in
-- their own instructions, and the RISC-V one must be written without a single
-- symbol reference -- see notes/023.

local M = {}

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

-- {{{ M.x86_64(blob_offset, offsets)
function M.x86_64(blob_offset, offsets)
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .code64")
  line("  .globl _start")
  line("_start:")
  -- A LOCAL label beside the global one, and everything below measures from
  -- this rather than from `_start`.
  --
  -- A reference to a global symbol is a relocation -- a note for a linker --
  -- even on an architecture whose assembler resolves local references itself.
  -- With no linker the note is dropped and a zero is left, so `leaq
  -- _start(%rip)` assembled to `leaq (%rip)`: the address of the *next*
  -- instruction rather than the start of the program. Everything read
  -- afterwards was offset by a couple of dozen bytes and came back as
  -- plausible nonsense.
  --
  -- This is the same trap that cost an hour on RISC-V, wearing different
  -- clothes. There it was every symbol; here it is only the exported ones.
  line("here:")

  -- Firmware hands the image handle in rcx and its own table in rdx, and
  -- expects thirty-two bytes of scratch above the return address before any
  -- call. The extra keeps the stack aligned and gives room to build strings.
  line("  subq $256, %rsp")
  line("  movq %rdx, %r14")                  -- the firmware's table, kept
  line("  movq 64(%r14), %r15")              -- its console, kept

  -- where we are standing, plus how far the model is: its address.
  line("  leaq here(%rip), %r13")
  line("  addq $" .. string.format("0x%x", blob_offset) .. ", %r13")

  -- {{{ say the fixed labels and the numbers between them
  --
  -- Each announcement is a jump over an inline string, so no data section is
  -- needed and nothing has to be linked. The string sits in the middle of the
  -- code, which is unusual to read and costs nothing to run.
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
  -- }}}

  -- {{{ local function say_hex(offset)
  -- Prints the thirty-two bit number at a distance into the model as eight
  -- hexadecimal characters. Built on the stack a character at a time, because
  -- there is nowhere else to put it and nothing to convert it with.
  local converted = 0
  local function say_hex(offset)
    converted = converted + 1
    local loop = "hex" .. converted
    local digit = "digit" .. converted
    local done = "hexdone" .. converted

    line("  movl " .. offset .. "(%r13), %eax")   -- the number
    line("  leaq 64(%rsp), %rdi")                 -- somewhere to build it
    line("  movq $8, %rcx")                       -- eight characters
    line(loop .. ":")
    line("  roll $4, %eax")                       -- highest four bits down
    line("  movl %eax, %edx")
    line("  andl $15, %edx")                      -- just those four
    line("  cmpl $10, %edx")
    line("  jl " .. digit)
    line("  addl $87, %edx")                      -- ten becomes 'a'
    line("  jmp " .. done)
    line(digit .. ":")
    line("  addl $48, %edx")                      -- zero becomes '0'
    line(done .. ":")
    line("  movw %dx, (%rdi)")                    -- sixteen bits per character
    line("  addq $2, %rdi")
    line("  decq %rcx")
    line("  jnz " .. loop)
    line("  movw $0, (%rdi)")                     -- and a nothing to end it

    line("  leaq 64(%rsp), %rdx")
    line("  movq %r15, %rcx")
    line("  movq 8(%r15), %rax")
    line("  callq *%rax")
  end
  -- }}}

  say_text("\r\nfound a packed model inside myself\r\n")

  -- what to read out, and where each one lives -- the where taken from the
  -- format description so nothing here can be off by a field.
  local report = {
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

  for _, entry in ipairs(report) do
    local label, field = entry[1], entry[2]
    local at = offsets[field]
    if at == nil then
      error("033-emit-blob-report: the format has no field called '" .. field .. "'")
    end
    say_text("  " .. label)
    say_hex(at)
    say_text("\r\n")
  end

  line("wait:")
  line("  hlt")
  line("  jmp wait")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
