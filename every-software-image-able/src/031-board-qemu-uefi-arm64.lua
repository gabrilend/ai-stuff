-- 031-board-qemu-uefi-arm64.lua
--
-- An emulated 64-bit ARM machine that starts through UEFI. The field schema is
-- in 015-board-qemu-x86-64.info.md, and the reasoning for having UEFI boards at
-- all is at the top of 030; this file records only what differs.

return {
  board_id = "qemu-uefi-arm64",

  arch = "aarch64",

  emulator = "qemu-system-aarch64",

  machine = "virt",
  cpu = "cortex-a72",

  memory_sizes = { small = "256M", plenty = "4G" },

  console = {
    kind = "pl011",
    base = 0x09000000,
    note = "PL011; the firmware narrates here before the payload does",
  },

  framebuffer = {
    kind = "virtio-gpu-pci",
    -- The difference this board makes. On the firmware-less ARM board a
    -- payload has nowhere to draw until it has written a driver; here the
    -- firmware has already done that work and hands over the result.
    note = "firmware drives it and hands over address, size and pixel format",
  },

  storage = { controller = "nvme" },

  payload = {
    kind = "uefi-esp",

    -- The name is the selection mechanism (issue 402). An x86 firmware looks
    -- for BOOTX64 and will never find this; this one looks for BOOTAA64 and
    -- will never find that. Nothing detects anything.
    boot_path = "EFI/BOOT/BOOTAA64.EFI",

    -- ARM firmware images are padded to a fixed flash size and this build is
    -- not, so it is handed over whole rather than as a flash chip.
    firmware = "/usr/share/qemu/edk2-aarch64-code.fd",

    note = "firmware reads EFI/BOOT/BOOTAA64.EFI from a FAT filesystem",
  },

  verified_against = "qemu 'virt' machine with edk2 firmware; "
                  .. "confirmed empirically by the uefi-hello payload",
}
