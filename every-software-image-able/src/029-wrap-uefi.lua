#!/usr/bin/env luajit
-- 029-wrap-uefi.lua
--
-- Wraps a raw binary in the executable format UEFI firmware will load, so a
-- payload can be started by real firmware rather than by a loader trick.
--
-- For a general: firmware will only start a program that arrives in a
-- particular envelope, with the machine it was built for written on the
-- outside. This writes that envelope. The firmware reads the label, and a
-- machine of the wrong kind is never opened -- which is exactly how the seed
-- is meant to carry three engines and have each computer run only its own.
--
-- WHY THIS EXISTS RATHER THAN A LINKER. There is no linker on this machine
-- that produces this format. There does not need to be one: the envelope is a
-- fixed arrangement of numbers, and generating it is less work than acquiring
-- a tool that would. Never create things manually; create the tool that
-- creates them.
--
-- The envelope is a PE file -- the same shape Windows uses, which UEFI adopted.
-- It opens with a stub from an older era that says the program cannot run
-- under DOS, kept only because the format never dropped it.
--
-- usage:
--   luajit 029-wrap-uefi.lua --from RAW --to APP --arch NAME [--entry N]

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
end
-- }}}

-- {{{ local function die(text)
local function die(text)
  io.stderr:write("029-wrap-uefi: ", text, "\n")
  os.exit(1)
end
-- }}}

-- {{{ writing primitives -- little-endian, fixed width
local function u16(value)
  value = math.floor(value) % 65536
  return string.char(value % 256, math.floor(value / 256))
end

local function u32(value)
  value = math.floor(value)
  return string.char(value % 256,
                     math.floor(value / 256) % 256,
                     math.floor(value / 65536) % 256,
                     math.floor(value / 16777216) % 256)
end

local function u64(value)
  return u32(value % 4294967296) .. u32(math.floor(value / 4294967296))
end
-- }}}

-- {{{ MACHINE -- what the firmware reads to decide whether this is for it
--
-- This single number is the whole of issue 402's answer. Nothing detects a
-- processor and dispatches; each firmware simply declines to open an envelope
-- addressed to somebody else.
local MACHINE = {
  x86_64  = 0x8664,
  aarch64 = 0xaa64,
  riscv64 = 0x5064,
}
-- }}}

-- {{{ layout constants
local DOS_STUB_BYTES = 64        -- the old-era header, minimum size
local PE_SIGNATURE = "PE\0\0"
local COFF_HEADER_BYTES = 20
local OPTIONAL_HEADER_BYTES = 240  -- PE32+ with all sixteen directory slots
local SECTION_HEADER_BYTES = 40

local FILE_ALIGNMENT = 0x200     -- how sections are spaced in the file
local SECTION_ALIGNMENT = 0x1000 -- how they are spaced once loaded
local IMAGE_BASE = 0x400000

local SUBSYSTEM_EFI_APPLICATION = 10

-- Executable, and nothing else.
--
-- It is tempting to also mark the image as carrying no relocation table,
-- since it genuinely carries none. Do not. Firmware reads that mark as "this
-- must be loaded at the address written below or not at all", and an address
-- that is ordinary memory on one machine is nowhere on another -- the base
-- x86 accepted without comment is outside RAM entirely on the ARM board,
-- which refused with `failed to find range 400000`.
--
-- Leaving the mark off lets the firmware put the image wherever it likes.
-- Nothing needs fixing up afterwards because the code refers to itself
-- relative to where it is standing rather than by absolute address, which is
-- the same property that let it be built without a linker.
local CHARACTERISTICS = 0x0002

-- code, executable, readable
local TEXT_CHARACTERISTICS = 0x60000020
-- }}}

-- {{{ local function align_up(value, to)
local function align_up(value, to)
  local remainder = value % to
  if remainder == 0 then return value end
  return value + (to - remainder)
end
-- }}}

-- {{{ local function wrap(code, machine, entry_offset)
local function wrap(code, machine, entry_offset)
  local headers_bytes = DOS_STUB_BYTES + #PE_SIGNATURE + COFF_HEADER_BYTES
    + OPTIONAL_HEADER_BYTES + SECTION_HEADER_BYTES
  local headers_on_disk = align_up(headers_bytes, FILE_ALIGNMENT)

  local text_rva = SECTION_ALIGNMENT
  local text_on_disk = align_up(#code, FILE_ALIGNMENT)
  local image_bytes = align_up(text_rva + #code, SECTION_ALIGNMENT)

  local parts = {}

  -- {{{ the old-era stub
  -- "MZ", then zeros, then at offset 0x3c the place the real header starts.
  -- Nothing reads the rest; it is here because the format never let it go.
  local stub = { "MZ" }
  for _ = 3, 0x3c do stub[#stub + 1] = "\0" end
  stub[#stub + 1] = u32(DOS_STUB_BYTES)
  parts[#parts + 1] = table.concat(stub)
  -- }}}

  -- {{{ the COFF header -- who this is for, and how it is arranged
  parts[#parts + 1] = PE_SIGNATURE
  parts[#parts + 1] = u16(machine)
  parts[#parts + 1] = u16(1)                       -- one section
  parts[#parts + 1] = u32(0)                       -- no timestamp: same input, same bytes
  parts[#parts + 1] = u32(0)                       -- no symbol table
  parts[#parts + 1] = u32(0)                       -- and none to count
  parts[#parts + 1] = u16(OPTIONAL_HEADER_BYTES)
  parts[#parts + 1] = u16(CHARACTERISTICS)
  -- }}}

  -- {{{ the optional header -- where to start, and how much to map
  parts[#parts + 1] = u16(0x20b)                   -- 64-bit form
  parts[#parts + 1] = string.char(0, 0)            -- linker version: there was no linker
  parts[#parts + 1] = u32(text_on_disk)            -- size of code
  parts[#parts + 1] = u32(0)                       -- initialised data
  parts[#parts + 1] = u32(0)                       -- uninitialised data
  parts[#parts + 1] = u32(text_rva + entry_offset) -- where to begin
  parts[#parts + 1] = u32(text_rva)                -- where the code starts
  parts[#parts + 1] = u64(IMAGE_BASE)
  parts[#parts + 1] = u32(SECTION_ALIGNMENT)
  parts[#parts + 1] = u32(FILE_ALIGNMENT)
  parts[#parts + 1] = u16(0) .. u16(0)             -- operating system version
  parts[#parts + 1] = u16(0) .. u16(0)             -- image version
  parts[#parts + 1] = u16(0) .. u16(0)             -- subsystem version
  parts[#parts + 1] = u32(0)                       -- reserved
  parts[#parts + 1] = u32(image_bytes)
  parts[#parts + 1] = u32(headers_on_disk)
  parts[#parts + 1] = u32(0)                       -- checksum: firmware does not require one
  parts[#parts + 1] = u16(SUBSYSTEM_EFI_APPLICATION)
  parts[#parts + 1] = u16(0)                       -- no special loading rules
  parts[#parts + 1] = u64(0x10000) .. u64(0x10000) -- stack reserved, committed
  parts[#parts + 1] = u64(0x10000) .. u64(0x10000) -- heap reserved, committed
  parts[#parts + 1] = u32(0)                       -- loader flags
  parts[#parts + 1] = u32(16)                      -- directory slots that follow
  for _ = 1, 16 do parts[#parts + 1] = u32(0) .. u32(0) end
  -- }}}

  -- {{{ the section header -- one section, all of it code
  parts[#parts + 1] = ".text\0\0\0"
  parts[#parts + 1] = u32(#code)                   -- size once loaded
  parts[#parts + 1] = u32(text_rva)
  parts[#parts + 1] = u32(text_on_disk)            -- size on disk
  parts[#parts + 1] = u32(headers_on_disk)         -- where on disk
  parts[#parts + 1] = u32(0) .. u32(0)             -- no relocations, no line numbers
  parts[#parts + 1] = u16(0) .. u16(0)             -- and none to count
  parts[#parts + 1] = u32(TEXT_CHARACTERISTICS)
  -- }}}

  -- {{{ padding to where the section says it starts, then the code
  local written = #table.concat(parts)
  if written > headers_on_disk then
    die("the headers came to " .. written .. " bytes, past the "
        .. headers_on_disk .. " the section header promised")
  end
  parts[#parts + 1] = string.rep("\0", headers_on_disk - written)
  parts[#parts + 1] = code
  parts[#parts + 1] = string.rep("\0", text_on_disk - #code)
  -- }}}

  return table.concat(parts), image_bytes
end
-- }}}

-- {{{ main
local from_path, to_path, arch, entry_offset = nil, nil, nil, 0
local index = 1
while index <= #arg do
  local word = arg[index]
  if word == "--from" then
    index = index + 1 ; from_path = arg[index] or die("missing value after --from")
  elseif word == "--to" then
    index = index + 1 ; to_path = arg[index] or die("missing value after --to")
  elseif word == "--arch" then
    index = index + 1 ; arch = arg[index] or die("missing value after --arch")
  elseif word == "--entry" then
    index = index + 1 ; entry_offset = tonumber(arg[index]) or die("--entry wants a number")
  else
    die("unknown option: " .. word)
  end
  index = index + 1
end

if not from_path then die("no --from given; there is nothing to wrap") end
if not to_path then die("no --to given; there is nowhere to put it") end
if not arch then die("no --arch given; the envelope must say who it is for") end

local machine = MACHINE[arch] or die("no machine number known for " .. arch)

local handle = io.open(from_path, "rb") or die("cannot open " .. from_path)
local code = handle:read("*a")
handle:close()
if #code == 0 then die(from_path .. " is empty") end

local application, image_bytes = wrap(code, machine, entry_offset)

local out = io.open(to_path, "wb") or die("cannot write " .. to_path)
out:write(application)
out:close()

say("wrapped " .. to_path)
say(string.format("  for %s (machine 0x%x), %d bytes of code, %d once loaded",
                  arch, machine, #code, image_bytes))
-- }}}
