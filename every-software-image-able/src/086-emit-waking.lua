-- 086-emit-waking.lua
--
-- What runs before the machine can think: find out what this processor
-- actually is, say so, and start the engine that matches. Issue 402.
--
-- For a general: the computer is switched on and this is the first thing of
-- ours that runs. It asks the processor what it can do, says the answer out
-- loud on the serial port, and hands over. If it does not recognise the
-- processor it says so and stops rather than guessing.
--
-- THE FIRMWARE ALREADY PICKED THE ARCHITECTURE. There is no code that runs
-- on all three, so nothing shared can identify a processor and dispatch --
-- machine code is not portable and the detector would need an architecture
-- of its own. Each firmware looks where its own convention says and finds
-- only its own payload (029, and the boot filenames in 030 through 032).
-- What is left for this file is the detection that IS possible: which vector
-- extensions this particular processor turned out to have, within an
-- architecture already chosen.
--
-- AND THE ENGINES ARE NEVER TRIED IN TURN. Running code for the wrong
-- architecture does not return garbage; it does not return. The processor
-- decodes the bytes as instructions and does whatever they happen to mean,
-- and there is nothing above it watching, because this project has nothing
-- above it. Trying in turn needs a supervisor, and the supervisor would need
-- an architecture of its own.
--
-- SAY IT BEFORE HANDING OVER. "Found this processor, starting this engine"
-- is the single most useful sentence a failing machine can produce, and at
-- this moment it is the only thing that can be said at all.

local M = {}

-- {{{ M.LEVELS -- the vector arrangements, per architecture, worst first
--
-- Each level names what a hot loop may assume. The engine carries one loop
-- per level it supports and this picks; a build that carries only the
-- baseline is smaller, slower, and correct everywhere, which is a real
-- choice rather than a lesser one.
M.LEVELS = {
  x86_64 = {
    { name = "baseline", how_wide = 4,
      note = "four numbers at a time. Guaranteed on every 64-bit processor "
          .. "of this kind; nothing needs to be asked." },
    { name = "wider", how_wide = 8,
      note = "eight at a time. Common but not universal.",
      ask = { leaf = 7, sub = 0, register = "b", bit = 5 } },
    { name = "widest", how_wide = 16,
      note = "sixteen at a time. Present on some server parts and absent "
          .. "from most others.",
      ask = { leaf = 7, sub = 0, register = "b", bit = 16 } },
  },
  aarch64 = {
    { name = "baseline", how_wide = 4,
      note = "four at a time. Part of the architecture itself on 64-bit ARM, "
          .. "so there is nothing to detect: a processor without it is not "
          .. "one of these." },
    { name = "scalable", how_wide = 0,
      note = "a vector length the processor chooses rather than one the "
          .. "program knows. Optional, and a different shape of loop rather "
          .. "than a wider one -- which is why it is a separate engine and "
          .. "not a wider setting.",
      ask = { hwcap = "sve" } },
  },
  riscv64 = {
    { name = "baseline", how_wide = 1,
      note = "one number at a time. The vector extension is OPTIONAL on this "
          .. "architecture -- not merely uncommon -- so the guaranteed "
          .. "arrangement has no vectors at all." },
    { name = "vector", how_wide = 0,
      note = "a vector length the processor chooses. Where it exists it is "
          .. "the whole difference between usable and not.",
      ask = { extension = "V" } },
  },
}
-- }}}

-- {{{ M.x86_64(options)
--
-- Asks the processor what it is, says so, and reports which engine it would
-- start. Boots as a UEFI application like everything else here.
--
-- options: engines (which levels this image actually carries)
function M.x86_64(options)
  local carried = options.engines or { "baseline" }
  local has = {}
  for _, name in ipairs(carried) do has[name] = true end

  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .code64")
  line("  .globl _start")
  line("_start:")
  line("here:")
  line("  subq $256, %rsp")
  line("  movq %rdx, %r14")
  line("  movq 64(%r14), %r15")

  -- {{{ saying things
  local said = 0
  local function say_text(text)
    said = said + 1
    local skip, label = "skip" .. said, "text" .. said
    line("  jmp " .. skip)
    line(label .. ":")
    for index = 1, #text do line("  .short " .. text:byte(index)) end
    line("  .short 0")
    line(skip .. ":")
    line("  leaq " .. label .. "(%rip), %rdx")
    line("  movq %r15, %rcx")
    line("  movq 8(%r15), %rax")
    line("  callq *%rax")
  end

  local converted = 0
  local function say_hex_r13(digits)
    converted = converted + 1
    local loop, digit, done = "hex" .. converted, "digit" .. converted,
                              "hexdone" .. converted
    line("  movq %r13, %rax")
    if digits < 16 then line("  shlq $" .. (64 - 4 * digits) .. ", %rax") end
    line("  leaq 64(%rsp), %r11")
    line("  movq $" .. digits .. ", %rcx")
    line(loop .. ":")
    line("  rolq $4, %rax")
    line("  movl %eax, %edx")
    line("  andl $15, %edx")
    line("  cmpl $10, %edx")
    line("  jl " .. digit)
    line("  addl $87, %edx")
    line("  jmp " .. done)
    line(digit .. ":")
    line("  addl $48, %edx")
    line(done .. ":")
    line("  movw %dx, (%r11)")
    line("  addq $2, %r11")
    line("  decq %rcx")
    line("  jnz " .. loop)
    line("  movw $0, (%r11)")
    line("  leaq 64(%rsp), %rdx")
    line("  movq %r15, %rcx")
    line("  movq 8(%r15), %rax")
    line("  callq *%rax")
  end
  -- }}}

  say_text("\r\nwaking up\r\n")

  -- {{{ what processor is this
  -- The maker's name comes back as twelve characters spread across three
  -- registers, in an order nobody would guess: b, then d, then c.
  line("  xorl %eax, %eax")
  line("  cpuid")
  line("  movl %ebx, 128(%rsp)")
  line("  movl %edx, 132(%rsp)")
  line("  movl %ecx, 136(%rsp)")
  line("  movb $0, 140(%rsp)")

  say_text("  made by   ")
  -- widen each byte to a halfword, since the firmware's console wants those
  line("  leaq 128(%rsp), %rsi")
  line("  leaq 160(%rsp), %rdi")
  line("  movq $12, %rcx")
  line("widen:")
  line("  movzbl (%rsi), %eax")
  line("  movw %ax, (%rdi)")
  line("  incq %rsi")
  line("  addq $2, %rdi")
  line("  decq %rcx")
  line("  jnz widen")
  line("  movw $0, (%rdi)")
  line("  leaq 160(%rsp), %rdx")
  line("  movq %r15, %rcx")
  line("  movq 8(%r15), %rax")
  line("  callq *%rax")
  say_text("\r\n")

  -- the family, model and stepping, as one number
  line("  movl $1, %eax")
  line("  cpuid")
  line("  movl %eax, %r13d")
  say_text("  part      ")
  say_hex_r13(8)
  say_text("\r\n")
  -- }}}

  -- {{{ which vector arrangement it has
  -- Asked, rather than assumed. The baseline needs no asking at all -- it is
  -- guaranteed by the architecture -- so only the wider ones are questions.
  line("  movl $7, %eax")
  line("  xorl %ecx, %ecx")
  line("  cpuid")
  line("  movl %ebx, %r12d")           -- kept: the answer about vectors

  say_text("  vectors   ")

  -- widest first, so the best available is the one reported
  line("  movl %r12d, %eax")
  line("  shrl $16, %eax")
  line("  andl $1, %eax")
  line("  jz not_widest")
  say_text("sixteen at a time\r\n")
  if has.widest then
    say_text("  starting the engine that reads sixteen at a time\r\n")
  else
    say_text("  this image does not carry that engine; using what it has\r\n")
  end
  line("  jmp chosen")
  line("not_widest:")

  line("  movl %r12d, %eax")
  line("  shrl $5, %eax")
  line("  andl $1, %eax")
  line("  jz not_wider")
  say_text("eight at a time\r\n")
  if has.wider then
    say_text("  starting the engine that reads eight at a time\r\n")
  else
    say_text("  this image does not carry that engine; using what it has\r\n")
  end
  line("  jmp chosen")
  line("not_wider:")

  say_text("four at a time, which every processor of this kind has\r\n")
  say_text("  starting the engine that reads four at a time\r\n")
  line("chosen:")
  -- }}}

  -- {{{ an unrecognised processor says so and stops
  -- The one case where guessing is worse than stopping: the maker's name is
  -- read, and a name nothing here knows means the vector answers cannot be
  -- trusted either, since the register they come back in is that maker's
  -- convention.
  line("  movl 128(%rsp), %eax")
  line("  cmpl $0x756e6547, %eax")          -- "Genu"
  line("  je recognised")
  line("  cmpl $0x68747541, %eax")          -- "Auth"
  line("  je recognised")
  say_text("  this maker is not one this image was built against. What it "
    .. "reports about its own vectors cannot be trusted, because the place "
    .. "those answers come back in is that maker's convention. Stopping "
    .. "rather than guessing.\r\n")
  line("  jmp halt")
  line("recognised:")
  say_text("  handing over\r\n")
  -- }}}

  line("halt:")
  line("  hlt")
  line("  jmp halt")
  line("")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.plan(architecture, carried)
-- What this image would do on a given architecture, as data -- so the image
-- builder (502) can lay out exactly the engines that will be looked for, and
-- so a person can read the decision without booting anything.
function M.plan(architecture, carried)
  local levels = M.LEVELS[architecture]
  if not levels then
    return nil, "nothing is known about '" .. tostring(architecture) .. "'"
  end
  carried = carried or { "baseline" }
  local has = {}
  for _, name in ipairs(carried) do has[name] = true end

  local out = {}
  for _, level in ipairs(levels) do
    out[#out + 1] = {
      name = level.name,
      carried = has[level.name] or false,
      detected = level.ask ~= nil,
      note = level.note,
    }
  end
  return out
end
-- }}}

return M
