-- 069-emit-say.lua
--
-- Saying something on a machine with no operating system: drawing text into
-- the framebuffer the firmware hands over, and writing bytes to a serial
-- port. Issue 202, and everything that goes wrong after this ticket is
-- diagnosed through it.
--
-- For a general: a computer that cannot be heard is debugged by watching it
-- sit still. This gives a bare machine two voices -- one on the screen, one
-- on a wire -- and neither needs a driver, an operating system, or anything
-- the machine has to work out for itself.
--
-- THE FRAMEBUFFER COSTS NOTHING AND IS FIRST. The firmware already found the
-- display, drove it, and left behind an address, a geometry and a pixel
-- format. Writing bytes there changes pixels. That is the whole of it, and
-- it is why the design targets UEFI on all three architectures (notes/023):
-- a BIOS board has text memory rather than pixels, and a board with no
-- firmware has nothing at all until a driver, an enumeration and a command
-- queue exist.
--
-- THE PIXELS PER ROW IS NOT THE WIDTH. Firmware reports both, and the first
-- is usually larger, because rows are padded. Assuming otherwise produces a
-- picture that shears diagonally -- it looks like a broken drawing routine
-- and is a misread structure.
--
-- THE SERIAL PORT IS UNBUFFERED ON PURPOSE. Buffering loses exactly the last
-- thing said, which is precisely what anybody reads after a crash.

local M = {}

-- {{{ M.GRAPHICS_OUTPUT_GUID -- how firmware is asked for the display
--
-- The firmware's table of what it can do is keyed by these sixteen-byte
-- numbers. This one names the graphics output protocol: the thing that knows
-- where the screen's memory is.
--
-- 9042a9de-23dc-4a38-96fb-7aded080516a, in the mixed-endian arrangement the
-- specification uses -- first three fields little-endian, last two as bytes.
M.GRAPHICS_OUTPUT_GUID = {
  0xde, 0xa9, 0x42, 0x90, 0xdc, 0x23, 0x38, 0x4a,
  0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a,
}
-- }}}

-- {{{ offsets into the firmware's structures
--
-- Fixed by the specification, and the only numbers here that cannot be
-- derived from anything. Named rather than written inline, because a bare
-- number in the middle of assembly is the shape mistakes hide in.
M.OFFSETS = {
  system_table_console  = 64,    -- the text console protocol
  system_table_boot     = 96,    -- the boot services table
  boot_locate_protocol  = 320,   -- LocateProtocol, 40th function of boot services
  graphics_mode         = 24,    -- the protocol's current mode structure
  mode_info             = 8,     -- that structure's description of the mode
  mode_framebuffer      = 24,    -- where the pixels are
  mode_framebuffer_size = 32,    -- how many bytes of them
  info_width            = 4,     -- pixels across
  info_height           = 8,     -- pixels down
  -- INCLUDING the padding; see above. It sits past the four-word pixel
  -- bitmask, and putting it at 20 instead -- inside that bitmask -- read a
  -- zero and collapsed all eight rows of every letter onto the first
  -- scanline. One horizontal line of dashes, drawn confidently, with the
  -- serial port reporting success. The mode structure is:
  --   0 version, 4 width, 8 height, 12 pixel format,
  --   16..31 the pixel bitmask, four words of it, 32 pixels per row
  info_pixels_per_row   = 32,
}
-- }}}

-- {{{ M.x86_64(options)
--
-- A payload that asks firmware for the screen, draws a line of text into it
-- with the carried font, and says the same line on the console it was
-- started from -- so a board with no display still reports, and a board with
-- one shows the same words.
--
-- options: text (what to say), first_code (the code the carried font's first
-- glyph stands for), font_bytes (the font, contiguous from that code),
-- colour (packed pixel).
function M.x86_64(options)
  local font = options.font_bytes
  -- The font MUST be contiguous from here, because a glyph is found by
  -- subtracting rather than searching. A table of only the characters that
  -- happen to be drawn indexes wrong at every gap, and the result is real
  -- letterforms spelling something else -- which is what this drew before
  -- the tables were made contiguous.
  local first = options.first_code
  local at = M.OFFSETS
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .code64")
  line("  .globl _start")
  line("_start:")
  line("here:")
  line("  subq $256, %rsp")
  line("  movq %rdx, %r14")                    -- the firmware's table
  line("  movq " .. at.system_table_console .. "(%r14), %r15")

  -- {{{ say it on the console first
  -- Before anything is asked of the display, so a board whose graphics
  -- protocol is absent has already spoken. The console is the truth channel
  -- while anything is going wrong.
  local said = 0
  local function say_text(text)
    said = said + 1
    local skip, label = "skip" .. said, "text" .. said
    line("  jmp " .. skip)
    line(label .. ":")
    for index = 1, #text do
      line("  .short " .. text:byte(index))
    end
    line("  .short 0")
    line(skip .. ":")
    line("  leaq " .. label .. "(%rip), %rdx")
    line("  movq %r15, %rcx")
    line("  movq 8(%r15), %rax")
    line("  callq *%rax")
  end

  say_text("\r\n" .. options.text .. "\r\n")
  -- }}}

  -- {{{ ask firmware for the screen
  -- LocateProtocol(&guid, NULL, &interface). A refusal is reported and the
  -- payload stops rather than drawing into whatever address was left in a
  -- register -- which is the difference between a machine that says it has
  -- no display and a machine that writes over something at random.
  line("  jmp guid_done")
  line("guid:")
  for _, byte in ipairs(M.GRAPHICS_OUTPUT_GUID) do
    line("  .byte " .. byte)
  end
  line("guid_done:")
  line("  leaq guid(%rip), %rcx")
  line("  xorl %edx, %edx")
  line("  leaq 128(%rsp), %r8")
  line("  movq " .. at.system_table_boot .. "(%r14), %rax")
  line("  movq " .. at.boot_locate_protocol .. "(%rax), %rax")
  line("  callq *%rax")
  line("  testq %rax, %rax")
  line("  jnz no_display")
  -- }}}

  -- {{{ where the pixels are, and how they are arranged
  line("  movq 128(%rsp), %r13")              -- the protocol
  line("  movq " .. at.graphics_mode .. "(%r13), %r13")
  line("  movq " .. at.mode_info .. "(%r13), %r12")     -- the mode's description
  line("  movq " .. at.mode_framebuffer .. "(%r13), %r11")  -- the pixels
  line("  movl " .. at.info_pixels_per_row .. "(%r12), %r10d")
  -- }}}

  -- {{{ draw the text
  --
  -- Character by character, row by row, bit by bit. Every set bit is one
  -- four-byte pixel; the position is (row * pixels_per_row + column) * 4,
  -- and pixels_per_row rather than width is the whole point.
  --
  -- The font rides inline like every other constant here, because a payload
  -- with no linker has nowhere else to put it.
  line("  jmp font_done")
  line("font:")
  for index = 1, #font, 8 do
    local row = {}
    for offset = 0, 7 do row[#row + 1] = font[index + offset] or 0 end
    line("  .byte " .. table.concat(row, ", "))
  end
  line("font_done:")

  line("  jmp drawn_text_done")
  line("drawn_text:")
  for index = 1, #options.text do
    line("  .byte " .. options.text:byte(index))
  end
  line("  .byte 0")
  line("drawn_text_done:")

  line("  leaq drawn_text(%rip), %rsi")
  line("  xorl %r9d, %r9d")                   -- which character
  line("character_loop:")
  line("  movzbl (%rsi,%r9), %eax")
  line("  testl %eax, %eax")
  line("  jz drawing_done")

  -- the glyph: (character - first) * 8 bytes into the font
  line("  subl $" .. first .. ", %eax")
  line("  js next_character")                 -- below the font: nothing to draw
  line("  shll $3, %eax")
  line("  leaq font(%rip), %rdi")
  line("  addq %rax, %rdi")                   -- this glyph's eight rows

  line("  xorl %ecx, %ecx")                   -- which row
  line("row_loop:")
  line("  movzbl (%rdi,%rcx), %edx")          -- the row's eight bits
  line("  xorl %r8d, %r8d")                   -- which column
  line("column_loop:")
  -- the leftmost bit first: shift right by (7 - column) and test the low bit
  line("  movl $7, %eax")
  line("  subl %r8d, %eax")
  line("  movl %eax, %ebx")
  line("  movl %edx, %eax")
  line("  pushq %rcx")
  line("  movl %ebx, %ecx")
  line("  shrl %cl, %eax")
  line("  popq %rcx")
  line("  andl $1, %eax")
  line("  jz next_column")

  -- (row * pixels_per_row + character * 8 + column) * 4, from the top left
  line("  movl %ecx, %eax")
  line("  imull %r10d, %eax")
  line("  movl %r9d, %ebx")
  line("  shll $3, %ebx")
  line("  addl %ebx, %eax")
  line("  addl %r8d, %eax")
  line("  movl $" .. string.format("0x%x", options.colour or 0x00ff66)
    .. ", %ebx")
  line("  movl %ebx, (%r11,%rax,4)")

  line("next_column:")
  line("  incl %r8d")
  line("  cmpl $8, %r8d")
  line("  jl column_loop")
  line("  incl %ecx")
  line("  cmpl $8, %ecx")
  line("  jl row_loop")

  line("next_character:")
  line("  incq %r9")
  line("  jmp character_loop")
  line("drawing_done:")
  -- }}}

  say_text("drawn\r\n")
  line("  jmp halt")

  line("no_display:")
  say_text("this machine has no display the firmware can hand over\r\n")

  line("halt:")
  line("  hlt")
  line("  jmp halt")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
