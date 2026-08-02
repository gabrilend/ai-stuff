-- 030-board-qemu-uefi-x86-64.lua
--
-- An emulated x86-64 machine that starts the way the design assumes: with UEFI
-- firmware rather than a BIOS. The field schema is in
-- 015-board-qemu-x86-64.info.md; this file records only what differs and why
-- it matters.
--
-- WHY A SECOND x86 BOARD RATHER THAN A FLAG ON THE FIRST. A machine that boots
-- through UEFI is a different board from one that boots through a BIOS -- it
-- hands over different things, looks for its payload in a different place, and
-- offers a display where the other offers only text memory. Two boards, two
-- descriptions; adding one is adding a file.
--
-- WHAT THIS BOARD BUYS. Two things the BIOS board cannot give:
--
--   The framebuffer. Issue 202 says firmware hands over an address and a
--   geometry so a machine can draw from its first instant with no driver.
--   That handover is UEFI's alone.
--
--   The selection. Issue 402 says nothing detects a processor and dispatches,
--   because each firmware finds only its own payload. The label it reads is
--   written on a UEFI application's envelope (029), so this is where that
--   claim becomes testable.

return {
  board_id = "qemu-uefi-x86-64",

  arch = "x86_64",

  emulator = "qemu-system-x86_64",

  -- the modern machine rather than the classic one: it has the buses and the
  -- firmware interface a current computer has.
  machine = "q35",
  cpu = "max",

  memory_sizes = { small = "256M", plenty = "4G" },

  console = {
    kind = "com1-port",
    base = 0x3f8,
    -- still here, and still the truth channel while anything is going wrong.
    -- The firmware writes its own progress here too, which is the first time
    -- this project has had something other than its own payload to read.
    note = "16550 at port 0x3f8; firmware narrates here before we do",
  },

  framebuffer = {
    kind = "vga",
    -- and this time it is a real one: the firmware hands over its address,
    -- its size and its pixel format, and a payload can write pixels without
    -- knowing anything about the device underneath.
    note = "handed over by firmware with the memory map; pixels, not characters",
  },

  storage = { controller = "ahci" },

  payload = {
    kind = "uefi-esp",
    -- Firmware looks in one place on a FAT filesystem, under a name that
    -- says which architecture the program is for. That name IS the selection
    -- mechanism of issue 402 -- a machine of the wrong kind never opens it.
    boot_path = "EFI/BOOT/BOOTX64.EFI",

    -- On this machine the firmware is not handed over as a lump; it is
    -- presented as flash chips, the way a real board carries it. Two of
    -- them: the code, which never changes, and the variables, which the
    -- firmware writes to and therefore must be a copy nobody else is using.
    firmware_code = "/usr/share/qemu/edk2-x86_64-code.fd",
    firmware_vars = "/usr/share/qemu/edk2-i386-vars.fd",

    note = "firmware as two flash chips; it reads EFI/BOOT/BOOTX64.EFI "
        .. "from a FAT filesystem",
  },

  verified_against = "qemu 'q35' machine with edk2 firmware; "
                  .. "confirmed empirically by the uefi-hello payload",
}
