-- 032-board-qemu-uefi-riscv64.lua
--
-- An emulated RISC-V machine that starts through UEFI. The field schema is in
-- 015-board-qemu-x86-64.info.md, and the reasoning for having UEFI boards at
-- all is at the top of 030; this file records only what differs.

return {
  board_id = "qemu-uefi-riscv64",

  arch = "riscv64",

  emulator = "qemu-system-riscv64",

  machine = "virt",
  cpu = "rv64",

  memory_sizes = { small = "256M", plenty = "4G" },

  console = {
    kind = "ns16550a",
    base = 0x10000000,
    note = "16550 at 0x10000000; the firmware narrates here before the payload",
  },

  framebuffer = {
    kind = "virtio-gpu-pci",
    note = "firmware drives it and hands over address, size and pixel format",
  },

  -- USB, deliberately -- the most demanding of the three, and the one the
  -- firmware has to work hardest to read a boot filesystem from.
  storage = { controller = "usb-storage" },

  payload = {
    kind = "uefi-esp",

    -- the third name, and the third half of issue 402's answer: an x86
    -- firmware looks for BOOTX64, an ARM one for BOOTAA64, this one for
    -- BOOTRISCV64, and none of them will ever open another's.
    boot_path = "EFI/BOOT/BOOTRISCV64.EFI",

    -- As flash chips, like the x86 board and unlike the ARM one. Handed over
    -- whole, this firmware asserts during its own startup before reaching
    -- anything of ours -- it looks for itself where a flash chip would be.
    -- Three architectures, three different ways of being given firmware, and
    -- none of them derivable from the other two.
    firmware_code = "/usr/share/qemu/edk2-riscv-code.fd",
    firmware_vars = "/usr/share/qemu/edk2-riscv-vars.fd",

    note = "firmware as two flash chips; it reads EFI/BOOT/BOOTRISCV64.EFI "
        .. "from a FAT filesystem",
  },

  verified_against = "qemu 'virt' machine with edk2 firmware; "
                  .. "confirmed empirically by the uefi-hello payload",
}
