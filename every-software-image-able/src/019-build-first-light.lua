#!/usr/bin/env luajit
-- 019-build-first-light.lua
--
-- Builds the first-light stubs: one tiny payload per architecture that
-- boots on its example board and says so over the console. They prove the
-- harness -- board description, launcher, emulator, console -- end to end.
-- They are scaffolding, not the seed; nothing in them ships.
--
-- For a general: this writes three very small programs, one per kind of
-- processor, whose whole job is to say "first light" out the serial wire
-- the moment a bare machine runs them. If that line appears, the whole
-- road from description to running computer is real.
--
-- The assembly is GENERATED from a message string rather than written by
-- hand. Each character becomes a load-immediate and a store, so the stubs
-- contain no data section and no relocations -- which is what lets them be
-- assembled and extracted with no linker at all (clang -c, then
-- llvm-objcopy -O binary). Never create things manually; create the tool
-- that creates them.
--
-- usage:
--   luajit 019-build-first-light.lua [--dir PROJECT_ROOT] [--arch NAME]

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
  io.stderr:write("019-build-first-light: ", text, "\n")
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

-- {{{ emit -- one assembly generator per architecture
--
-- Each takes the message and returns complete assembler text. The shape is
-- identical everywhere: point at the console, then for every character
-- load it as an immediate and store it out, then sleep forever. Numeric
-- character codes rather than quoted characters, so nothing depends on
-- assembler quoting rules.
local emit = {

  -- {{{ x86_64 = function(message)
  x86_64 = function(message)
    -- a BIOS boot sector: 16-bit code the firmware places at 0x7c00. The
    -- console is reached through x86's separate port address space -- the
    -- 'out' instruction -- which the other two architectures simply do
    -- not have (issue 401).
    local lines = {
      "  .code16",
      "  .globl _start",
      "_start:",
      "  cli",
      "  movw $0x3f8, %dx",
    }
    for index = 1, #message do
      lines[#lines + 1] = "  movb $" .. message:byte(index) .. ", %al"
      lines[#lines + 1] = "  outb %al, %dx"
    end
    lines[#lines + 1] = "sleep:"
    lines[#lines + 1] = "  hlt"
    lines[#lines + 1] = "  jmp sleep"
    -- the firmware only boots a sector ending in these two bytes.
    lines[#lines + 1] = "  .org 510"
    lines[#lines + 1] = "  .byte 0x55, 0xaa"
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
  end,
  -- }}}

  -- {{{ aarch64 = function(message)
  aarch64 = function(message)
    -- the PL011's data register sits at 0x09000000 on the virt board; a
    -- byte stored there leaves on the wire. movz builds the address in
    -- one instruction, so there is no literal pool and no relocation.
    local lines = {
      "  .globl _start",
      "_start:",
      "  movz x0, #0x0900, lsl #16",
    }
    for index = 1, #message do
      lines[#lines + 1] = "  movz w1, #" .. message:byte(index)
      lines[#lines + 1] = "  strb w1, [x0]"
    end
    lines[#lines + 1] = "sleep:"
    lines[#lines + 1] = "  wfi"
    lines[#lines + 1] = "  b sleep"
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
  end,
  -- }}}

  -- {{{ riscv64 = function(message)
  riscv64 = function(message)
    -- the same 16550 the x86 board talks to, but memory-mapped at
    -- 0x10000000 -- one device family, two ways of reaching it. li
    -- expands locally (lui+addi); still no relocations.
    local lines = {
      "  .globl _start",
      "_start:",
      "  li a0, 0x10000000",
    }
    for index = 1, #message do
      lines[#lines + 1] = "  li a1, " .. message:byte(index)
      lines[#lines + 1] = "  sb a1, 0(a0)"
    end
    lines[#lines + 1] = "sleep:"
    lines[#lines + 1] = "  wfi"
    lines[#lines + 1] = "  j sleep"
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
  end,
  -- }}}
}
-- }}}

-- {{{ clang_target -- the triple clang assembles each architecture under
local clang_target = {
  x86_64  = "x86_64-unknown-none",
  aarch64 = "aarch64-unknown-none",
  riscv64 = "riscv64-unknown-none",
}
-- }}}

-- {{{ local function build_one(arch, out_directory)
local function build_one(arch, out_directory)
  local message = "first light: " .. arch .. "\n"
  local asm_path = out_directory .. "/" .. arch .. ".s"
  local obj_path = out_directory .. "/" .. arch .. ".o"
  local bin_path = out_directory .. "/" .. arch .. ".bin"

  local handle = io.open(asm_path, "w")
  if not handle then die("cannot write " .. asm_path) end
  handle:write(emit[arch](message))
  handle:close()

  local assembled = run_one("clang --target=" .. clang_target[arch]
                            .. " -c " .. asm_path .. " -o " .. obj_path)
  if not assembled then die("assembly failed for " .. arch .. " (see " .. asm_path .. ")") end

  local extracted = run_one("llvm-objcopy -O binary " .. obj_path .. " " .. bin_path)
  if not extracted then die("extraction failed for " .. arch) end

  -- the x86 stub must be exactly one sector or the firmware refuses it.
  if arch == "x86_64" then
    local sector = io.open(bin_path, "r")
    local size = sector:seek("end")
    sector:close()
    if size ~= 512 then
      die("boot sector is " .. size .. " bytes, not 512 -- message too long?")
    end
  end

  say("built " .. bin_path)
  return bin_path
end
-- }}}

-- {{{ main
local only_arch = nil
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1
    DIR = arg[index] or die("missing value after --dir")
  elseif arg[index] == "--arch" then
    index = index + 1
    only_arch = arg[index] or die("missing value after --arch")
  else
    die("unknown option: " .. arg[index])
  end
  index = index + 1
end

-- compiled builds are artifacts, so they live on the RAM artifact tier.
run_one("mkdir -p /tmp/every-software-image-able")
run_one("mkdir -p /dev/shm/every-software-image-able")
run_one("ln -sfn /tmp/every-software-image-able " .. DIR .. "/tmp")
run_one("ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory")
local out_directory = DIR .. "/tmp/shared-memory/first-light"
run_one("mkdir -p " .. out_directory)

for _, arch in ipairs({ "x86_64", "aarch64", "riscv64" }) do
  if only_arch == nil or only_arch == arch then
    build_one(arch, out_directory)
  end
end
-- }}}
