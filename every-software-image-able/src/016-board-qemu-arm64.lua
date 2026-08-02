-- 016-board-qemu-arm64.lua
--
-- A board description for an emulated 64-bit ARM machine. Read by the
-- launcher (018), which generates the emulator command from it. See the
-- notes at the top of 015 -- the same rules apply.

return {
  board_id = "qemu-virt-arm64",

  arch = "aarch64",

  emulator = "qemu-system-aarch64",

  -- 'virt' is the plain machine qemu invented for exactly this use: no
  -- vendor quirks, devices where its handover structures say they are.
  -- Real ARM boards are messier, which belongs on the 705 list, not here.
  machine = "virt",
  cpu = "cortex-a72",

  memory_sizes = { small = "256M", plenty = "4G" },

  console = {
    kind = "pl011",
    base = 0x09000000,
    -- memory-mapped: a byte stored at base leaves on the wire. Under qemu
    -- no setup is needed at all, which is a tidiness real PL011s do not
    -- promise -- another entry for the 705 list.
    note = "PL011; strb to base transmits under qemu without initialisation",
  },

  framebuffer = {
    kind = "virtio-gpu-pci",
    note = "virt has no display until one is plugged in; the launcher adds it",
  },

  -- different controller per board on purpose; this one takes the NVMe path.
  storage = { controller = "nvme" },

  payload = {
    kind = "loader-device",
    -- DRAM begins at 0x40000000 on virt; the payload sits above it and a
    -- second loader entry points the processor at it.
    load_addr = 0x40100000,
    set_pc = true,
    note = "generic loader places the raw binary; a second entry sets the PC",
  },

  verified_against = "qemu 'virt' machine type; confirmed empirically by the 019 stub",
}
