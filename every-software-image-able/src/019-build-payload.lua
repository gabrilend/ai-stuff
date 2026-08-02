#!/usr/bin/env luajit
-- 019-build-payload.lua
--
-- Builds small payloads that run on a bare emulated board. One tool, several
-- payloads: a first-light stub that only says hello, and hazard probes that
-- deliberately write where they should not, so the traps in 021 have
-- something to catch.
--
-- For a general: this writes very small programs for bare machines, from a
-- list of things the program should do. It knows three kinds of processor and
-- two kinds of instruction -- say something, and poke an address.
--
-- The assembly is GENERATED rather than written by hand. Each step becomes a
-- few load-immediates and stores, so a payload has no data section and no
-- relocations -- which is what lets the whole build be an assembler and an
-- extractor, with no linker on the machine at all. Never create things
-- manually; create the tool that creates them.
--
-- Was 019-build-first-light: generalised when the trap work needed a second
-- kind of payload, rather than copying the generator into a second tool.
--
-- usage:
--   luajit 019-build-payload.lua [--payload NAME] [--arch NAME] [--dir ROOT]
--
--   --payload defaults to every known payload, --arch to all three.

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
end
-- }}}

-- {{{ local function die(text)
local function die(text)
  io.stderr:write("019-build-payload: ", text, "\n")
  os.exit(1)
end
-- }}}

-- {{{ local function run_one(command)
local function run_one(command)
  -- one command per call, no chains, no pipes.
  local ok, _, code = os.execute(command)
  return ok == true or ok == 0, code
end
-- }}}

-- {{{ CONSOLE -- where a byte goes to leave on the wire, per architecture
--
-- Duplicated from the board descriptions on purpose, and marked as such: a
-- payload is built for an architecture, not for a board, so the builder has
-- no board to read this from. If a second board per architecture ever appears
-- with a different console, this becomes a lie and the builder should start
-- taking a board rather than an architecture.
local CONSOLE = {
  x86_64  = { kind = "port", address = 0x3f8 },
  aarch64 = { kind = "mmio", address = 0x09000000 },
  riscv64 = { kind = "mmio", address = 0x10000000 },
}
-- }}}

-- {{{ emit -- one instruction generator per architecture
--
-- Each table knows how to do the two things a payload can do. Adding an
-- architecture is adding a table; adding an instruction is adding a row to
-- each. A dispatch table rather than a chain of questions about which
-- processor we are standing on.
local emit = {

  -- {{{ x86_64
  x86_64 = {
    prologue = function()
      -- a BIOS boot sector: 16-bit code the firmware places at 0x7c00.
      return { "  .code16", "  .globl _start", "_start:", "  cli" }
    end,

    say = function(text)
      -- x86 reaches its console through a separate port address space with
      -- its own instruction. The other two architectures have nothing like
      -- it (issue 401 -- the hands differ in shape, not only in detail).
      local out = { "  movw $" .. CONSOLE.x86_64.address .. ", %dx" }
      for index = 1, #text do
        out[#out + 1] = "  movb $" .. text:byte(index) .. ", %al"
        out[#out + 1] = "  outb %al, %dx"
      end
      return out
    end,

    poke = function(address, value)
      -- a 32-bit store to a physical address. This is 16-bit real mode, so
      -- the reachable range is small; hazard addresses for this board are
      -- chosen to sit inside it.
      return {
        "  movw $" .. string.format("0x%x", address) .. ", %bx",
        "  movl $" .. string.format("0x%x", value) .. ", %eax",
        "  movl %eax, (%bx)",
      }
    end,

    draw = function(text)
      -- VGA text memory, which on this board exists the moment the machine
      -- starts -- no driver, no enumeration, no knowledge of a part. Each
      -- cell is two bytes: the character, then its colour.
      --
      -- It lives at 0xb8000, which a 16-bit register cannot reach on its own,
      -- so the address is split: segment 0xb800 in the extra segment
      -- register, offset counted from there.
      local out = {
        "  movw $0xb800, %ax",
        "  movw %ax, %es",
        "  xorw %bx, %bx",
      }
      for index = 1, #text do
        out[#out + 1] = "  movb $" .. text:byte(index) .. ", %al"
        out[#out + 1] = "  movb %al, %es:(%bx)"
        out[#out + 1] = "  incw %bx"
        out[#out + 1] = "  movb $0x0a, %al"     -- bright green on black
        out[#out + 1] = "  movb %al, %es:(%bx)"
        out[#out + 1] = "  incw %bx"
      end
      return out
    end,

    epilogue = function()
      -- a boot sector must be exactly one sector and end in these two bytes.
      return { "sleep:", "  hlt", "  jmp sleep", "  .org 510", "  .byte 0x55, 0xaa", "" }
    end,
  },
  -- }}}

  -- {{{ aarch64
  aarch64 = {
    prologue = function()
      return { "  .globl _start", "_start:" }
    end,

    say = function(text)
      -- the PL011's data register is memory-mapped; a byte stored there
      -- leaves on the wire. movz builds the address in one instruction, so
      -- there is no literal pool and therefore no relocation.
      local out = { "  movz x0, #0x0900, lsl #16" }
      for index = 1, #text do
        out[#out + 1] = "  movz w1, #" .. text:byte(index)
        out[#out + 1] = "  strb w1, [x0]"
      end
      return out
    end,

    poke = function(address, value)
      -- built halfword by halfword: movz sets one and clears the rest, movk
      -- sets one and keeps the rest. No constant pool, no relocation.
      local out = {
        "  movz x2, #" .. string.format("0x%x", address % 0x10000),
        "  movk x2, #" .. string.format("0x%x", math.floor(address / 0x10000) % 0x10000) .. ", lsl #16",
        "  movz w3, #" .. string.format("0x%x", value % 0x10000),
      }
      if value >= 0x10000 then
        out[#out + 1] = "  movk w3, #"
          .. string.format("0x%x", math.floor(value / 0x10000) % 0x10000) .. ", lsl #16"
      end
      out[#out + 1] = "  str w3, [x2]"
      return out
    end,

    -- No draw. THIS IS THE FINDING, not an omission.
    --
    -- Issue 202 says the firmware hands over a linear framebuffer, so the
    -- machine can draw from its first instant with no driver. That is true of
    -- UEFI, which provides one. It is NOT true of this board, which boots
    -- with a generic loader and no firmware at all -- its display device is a
    -- virtio GPU that needs a driver, enumeration and a command queue before
    -- a single pixel moves.
    --
    -- Refusing here rather than pretending keeps the gap visible in the code
    -- rather than buried in a document. It is recorded in
    -- notes/023-what-the-emulator-lies-about.md, and the way out is a UEFI
    -- board description -- the firmware for it exists.

    epilogue = function()
      return { "sleep:", "  wfi", "  b sleep", "" }
    end,
  },
  -- }}}

  -- {{{ riscv64
  riscv64 = {
    prologue = function()
      return { "  .globl _start", "_start:" }
    end,

    say = function(text)
      -- the same 16550 family the x86 board talks to, but memory-mapped
      -- rather than behind port instructions. li expands locally to
      -- lui+addi; still no relocations.
      local out = { "  li a0, " .. string.format("0x%x", CONSOLE.riscv64.address) }
      for index = 1, #text do
        out[#out + 1] = "  li a1, " .. text:byte(index)
        out[#out + 1] = "  sb a1, 0(a0)"
      end
      return out
    end,

    poke = function(address, value)
      return {
        "  li a2, " .. string.format("0x%x", address),
        "  li a3, " .. string.format("0x%x", value),
        "  sw a3, 0(a2)",
      }
    end,

    epilogue = function()
      return { "sleep:", "  wfi", "  j sleep", "" }
    end,
  },
  -- }}}
}
-- }}}

-- {{{ local function assemble(arch, steps, name, out_directory)
local clang_target = {
  x86_64  = "x86_64-unknown-none",
  aarch64 = "aarch64-unknown-none",
  riscv64 = "riscv64-unknown-none",
}

local function assemble(arch, steps, name, out_directory)
  local generator = emit[arch] or die("no generator for architecture " .. arch)
  local lines = generator.prologue()

  -- one handler per kind of step, so a payload description stays data and
  -- the builder never asks what kind of thing it is holding.
  local handle_step = {
    say  = function(step) return generator.say(step.text) end,
    poke = function(step) return generator.poke(step.address, step.value) end,
    draw = function(step)
      -- refuse rather than silently skipping. A payload that quietly does not
      -- draw would come back looking like a machine that drew nothing, which
      -- is the same shape as the false-clean the trap runner already had to
      -- learn about.
      if not generator.draw then
        die("this architecture has nowhere to draw at boot.\n"
            .. "  Only the BIOS board has a display that exists before any driver.\n"
            .. "  The linear framebuffer issue 202 relies on comes from UEFI, and\n"
            .. "  these boards do not use it yet. See notes/023.")
      end
      return generator.draw(step.text)
    end,
  }

  for _, step in ipairs(steps) do
    local handler = handle_step[step.kind] or die("unknown payload step: " .. tostring(step.kind))
    for _, line in ipairs(handler(step)) do
      lines[#lines + 1] = line
    end
  end

  for _, line in ipairs(generator.epilogue()) do
    lines[#lines + 1] = line
  end

  local base = out_directory .. "/" .. name .. "-" .. arch
  local asm_path, obj_path, bin_path = base .. ".s", base .. ".o", base .. ".bin"

  local handle = io.open(asm_path, "w")
  if not handle then die("cannot write " .. asm_path) end
  handle:write(table.concat(lines, "\n"))
  handle:close()

  local assembled = run_one("clang --target=" .. clang_target[arch]
                            .. " -c " .. asm_path .. " -o " .. obj_path)
  if not assembled then die("assembly failed for " .. name .. "/" .. arch .. " (see " .. asm_path .. ")") end

  local extracted = run_one("llvm-objcopy -O binary " .. obj_path .. " " .. bin_path)
  if not extracted then die("extraction failed for " .. name .. "/" .. arch) end

  if arch == "x86_64" then
    local sector = io.open(bin_path, "r")
    local size = sector:seek("end")
    sector:close()
    if size ~= 512 then
      die("boot sector for " .. name .. " is " .. size .. " bytes, not 512 -- payload too long?")
    end
  end

  say("built " .. bin_path)
  return bin_path
end
-- }}}

-- {{{ payloads -- what each named payload does, as data
--
-- The hazard addresses come from the forbidden register map (020) so that a
-- probe and a trap cannot disagree about where the landmine is.
local hazards = dofile(DIR .. "/src/020-forbidden-registers.lua")

-- {{{ local function payload_steps(name, arch)
local function payload_steps(name, arch)
  if name == "first-light" then
    return { { kind = "say", text = "first light: " .. arch .. "\n" } }
  end

  -- proves the machine can put something on a screen before it can do
  -- anything else -- the claim issue 202 rests on. Only buildable where a
  -- display exists at boot; elsewhere it refuses, on purpose.
  if name == "draw-something" then
    return {
      { kind = "say",  text = "drawing\n" },
      { kind = "draw", text = "first light, drawn" },
    }
  end

  -- a probe named "hazard-<category>" says what it is about to do, then does
  -- it. Saying first matters: when the trap halts the machine, the console
  -- already carries the confession, and the last line before silence is the
  -- diagnosis.
  local category = name:match("^hazard%-(.+)$")
  if category then
    local hazard = hazards.by_category(arch, category)
      or die("no " .. category .. " hazard described for " .. arch)
    return {
      { kind = "say",  text = "about to write " .. hazard.name .. "\n" },
      { kind = "poke", address = hazard.address, value = hazard.fatal_value },
      { kind = "say",  text = "still here -- the trap did not fire\n" },
    }
  end

  die("unknown payload: " .. name)
end
-- }}}

-- {{{ local function known_payloads()
local function known_payloads()
  local names = { "first-light", "draw-something" }
  for _, category in ipairs(hazards.categories) do
    names[#names + 1] = "hazard-" .. category
  end
  return names
end
-- }}}

-- {{{ local function buildable(name, arch)
-- Whether a payload can exist for an architecture at all. Only "draw-something"
-- is limited, and only because a board with no firmware has no display until
-- somebody writes a driver for one. Building everything by default would then
-- stop at the first refusal, so the loop asks first.
local function buildable(name, arch)
  if name == "draw-something" then return arch == "x86_64" end
  return true
end
-- }}}
-- }}}

-- {{{ main
local only_arch, only_payload = nil, nil
local index = 1
while index <= #arg do
  local word = arg[index]
  if word == "--dir" then
    index = index + 1
    DIR = arg[index] or die("missing value after --dir")
  elseif word == "--arch" then
    index = index + 1
    only_arch = arg[index] or die("missing value after --arch")
  elseif word == "--payload" then
    index = index + 1
    only_payload = arg[index] or die("missing value after --payload")
  else
    die("unknown option: " .. word)
  end
  index = index + 1
end

-- compiled builds are artifacts, so they live on the RAM artifact tier.
run_one("mkdir -p /tmp/every-software-image-able")
run_one("mkdir -p /dev/shm/every-software-image-able")
run_one("ln -sfn /tmp/every-software-image-able " .. DIR .. "/tmp")
run_one("ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory")
local out_directory = DIR .. "/tmp/shared-memory/payloads"
run_one("mkdir -p " .. out_directory)

for _, name in ipairs(known_payloads()) do
  if only_payload == nil or only_payload == name then
    for _, arch in ipairs({ "x86_64", "aarch64", "riscv64" }) do
      if only_arch == nil or only_arch == arch then
        if buildable(name, arch) then
          assemble(arch, payload_steps(name, arch), name, out_directory)
        elseif only_payload and only_arch then
          -- asked for precisely this one, so say why it cannot exist rather
          -- than saying nothing and letting it look built.
          say("skipped " .. name .. " for " .. arch
              .. ": no display exists on that board before a driver does")
        end
      end
    end
  end
end
-- }}}
