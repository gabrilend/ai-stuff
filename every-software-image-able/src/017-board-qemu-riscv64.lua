-- 017-board-qemu-riscv64.lua
--
-- A board description for an emulated RISC-V machine. Read by the launcher
-- (018), which generates the emulator command from it. See the notes at the
-- top of 015 -- the same rules apply.

return {
  board_id = "qemu-virt-riscv64",

  arch = "riscv64",

  emulator = "qemu-system-riscv64",

  machine = "virt",
  cpu = "rv64",

  memory_sizes = { small = "256M", plenty = "4G" },

  console = {
    kind = "ns16550a",
    base = 0x10000000,
    -- the same 16550 the x86 board has, but memory-mapped rather than
    -- behind port instructions -- one device family, two ways of reaching
    -- it, which is the 401 point about hands differing in shape.
    note = "16550 at 0x10000000; sb to base transmits under qemu",
  },

  framebuffer = {
    kind = "virtio-gpu-pci",
    note = "virt has no display until one is plugged in; the launcher adds it",
  },

  -- different controller per board on purpose; this one takes the USB path,
  -- which is by far the most demanding of the three (issue 202 explains why
  -- USB is a stack, not a port).
  storage = { controller = "usb-storage" },

  payload = {
    kind = "loader-device",
    -- with no firmware at all (-bios none), the reset vector at 0x1000
    -- ends in a jump to the start of DRAM at 0x80000000. The payload goes
    -- exactly there.
    load_addr = 0x80000000,
    set_pc = false,
    bios = "none",
    note = "no firmware; reset vector jumps to DRAM start where the payload sits",
  },

  verified_against = "qemu 'virt' machine type; confirmed empirically by the 019 stub",
}
