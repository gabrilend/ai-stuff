-- 015-board-qemu-x86-64.lua
--
-- A board description for an emulated x86-64 machine. This is data, not
-- code: the launcher (018) reads it and generates the emulator command from
-- it, the same way the image builder will read descriptions of real boards.
-- An emulated machine is a board like any other (issue 701).
--
-- Nothing in here names a part of the seed, and nothing in the seed names
-- this board. That separation is the whole portability story (issue 501).

return {
  board_id = "qemu-pc-x86-64",

  -- which assembly language the payload must be written in
  arch = "x86_64",

  emulator = "qemu-system-x86_64",

  -- the classic BIOS machine. Chosen over the modern UEFI one because its
  -- firmware path is the simplest that exists: read sector zero, place it
  -- at 0x7c00, jump. The seed meets UEFI later, on real boards.
  machine = "pc",
  cpu = "max",

  -- more than one size on purpose: the ratchet in issue 102 is only a test
  -- if some board is small enough to force the slower rungs.
  memory_sizes = { small = "256M", plenty = "4G" },

  console = {
    kind = "com1-port",
    base = 0x3f8,
    -- x86 reaches this through its separate port address space with its own
    -- instructions (out dx, al). The other two boards have nothing like it;
    -- the catalogue of hands differs per architecture (issue 401).
    note = "16550 at port 0x3f8; a byte written to base leaves on the wire",
  },

  framebuffer = {
    kind = "vga",
    note = "BIOS text memory at 0xb8000 exists before any real framebuffer",
  },

  -- each example board carries a different storage controller so all of
  -- them get exercised (issue 701); this one takes the SATA path.
  storage = { controller = "ahci" },

  -- where the firmware looks -- the load-bearing field (issue 501).
  payload = {
    kind = "boot-sector",
    note = "firmware reads sector zero into 0x7c00 and jumps; "
        .. "510 bytes of code, then 0x55 0xaa",
  },

  verified_against = "qemu 'pc' machine type; confirmed empirically by the 019 stub",
}
