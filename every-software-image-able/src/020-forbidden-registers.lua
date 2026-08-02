-- 020-forbidden-registers.lua
--
-- Where the landmines are. Data read by two tools that must never disagree:
-- the payload builder (019), which makes probes that write to these
-- addresses, and the trap runner (021), which arms watchpoints on them.
--
-- The five categories are the ones issue 003a names as unrecoverable -- the
-- writes that destroy silicon rather than crashing software. Their mechanisms
-- are recorded here rather than only in the document, because whoever reads
-- this file is the person about to decide whether an address belongs in it.
--
-- HONESTY ABOUT WHAT THESE ARE. Most of the addresses below are synthetic:
-- ordinary RAM on the example boards, standing in for register blocks that a
-- real device model would provide. That is enough to test the discipline,
-- which is what issue 702a is for -- a watchpoint fires the same way whether
-- the address belongs to a modelled device or to nothing. It is NOT enough to
-- test whether a machine can tell a destroyed part from a busy one; that is
-- 702b, and it needs device models rather than addresses.
--
-- The entries marked `real = true` are genuine: writing the fatal value there
-- really does end the machine.

local M = {}

-- {{{ M.categories -- the five kinds of write that cannot be taken back
M.categories = {
  "voltage",       -- raise the regulator past what the silicon tolerates
  "clock",         -- drive the part faster than it can be driven
  "thermal",       -- switch off the protection that would have caught the others
  "nonvolatile",   -- overwrite the identity or firmware; the part never answers again
  "pin-direction", -- drive a pin against something else driving it: a short
}
-- }}}

-- {{{ M.mechanism -- why each category is fatal, in one sentence
M.mechanism = {
  voltage = "raises the supply past what the silicon tolerates; damage in seconds",
  clock = "drives the part faster than it can run; the same damage by another road",
  thermal = "removes the shutdown that would have caught the other two",
  nonvolatile = "overwrites stored identity or firmware; the part never enumerates again",
  ["pin-direction"] = "drives a pin against an external driver: a short through the transistor",
}
-- }}}

-- {{{ M.boards -- hazard addresses per architecture
--
-- x86 addresses must sit below 0x10000: the probe runs as a BIOS boot sector
-- in 16-bit real mode, which cannot reach further. 0x0000-0x0500 is the
-- interrupt table and BIOS data area, so the synthetic block starts above it.
--
-- ARM and RISC-V addresses sit in DRAM above where the payload is loaded.
M.boards = {

  -- {{{ x86_64
  x86_64 = {
    synthetic_note = "free real-mode RAM above the BIOS data area",
    hazards = {
      { name = "regulator control",   category = "voltage",       address = 0x1000, fatal_value = 0xdead0001 },
      { name = "clock multiplier",    category = "clock",         address = 0x1010, fatal_value = 0xdead0002 },
      { name = "thermal shutdown",    category = "thermal",       address = 0x1020, fatal_value = 0xdead0003 },
      { name = "configuration flash", category = "nonvolatile",   address = 0x1030, fatal_value = 0xdead0004 },
      { name = "pin direction",       category = "pin-direction", address = 0x1040, fatal_value = 0xdead0005 },
    },
  },
  -- }}}

  -- {{{ aarch64
  aarch64 = {
    synthetic_note = "DRAM above the payload load address of 0x40100000",
    hazards = {
      { name = "regulator control",   category = "voltage",       address = 0x40200000, fatal_value = 0xdead0001 },
      { name = "clock multiplier",    category = "clock",         address = 0x40200010, fatal_value = 0xdead0002 },
      { name = "thermal shutdown",    category = "thermal",       address = 0x40200020, fatal_value = 0xdead0003 },
      { name = "configuration flash", category = "nonvolatile",   address = 0x40200030, fatal_value = 0xdead0004 },
      { name = "pin direction",       category = "pin-direction", address = 0x40200040, fatal_value = 0xdead0005 },
    },
  },
  -- }}}

  -- {{{ riscv64
  riscv64 = {
    synthetic_note = "DRAM above the payload load address of 0x80000000",
    hazards = {
      -- the first one is not synthetic. The virt board really does carry a
      -- device at 0x100000 that ends the machine when written: 0x5555 powers
      -- it off, 0x7777 resets it. It is here because a trap that only ever
      -- fires on invented addresses has not been shown to work on a real one.
      { name = "test finisher (REAL: powers the machine off)",
        category = "voltage", address = 0x100000, fatal_value = 0x5555, real = true },

      { name = "clock multiplier",    category = "clock",         address = 0x80200010, fatal_value = 0xdead0002 },
      { name = "thermal shutdown",    category = "thermal",       address = 0x80200020, fatal_value = 0xdead0003 },
      { name = "configuration flash", category = "nonvolatile",   address = 0x80200030, fatal_value = 0xdead0004 },
      { name = "pin direction",       category = "pin-direction", address = 0x80200040, fatal_value = 0xdead0005 },
    },
  },
  -- }}}
}
-- }}}

-- {{{ function M.by_category(arch, category)
-- Returns the hazard of a given category on a given architecture, or nil.
-- Nil means the caller asked for something not described, which is a real
-- error rather than a case to paper over -- callers are expected to say so.
function M.by_category(arch, category)
  local board = M.boards[arch]
  if not board then return nil end
  for _, hazard in ipairs(board.hazards) do
    if hazard.category == category then return hazard end
  end
  return nil
end
-- }}}

-- {{{ function M.all(arch)
-- Every hazard described for an architecture, in declaration order.
function M.all(arch)
  local board = M.boards[arch]
  if not board then return {} end
  return board.hazards
end
-- }}}

return M
