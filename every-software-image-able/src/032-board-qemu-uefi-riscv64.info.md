# 032-board-qemu-uefi-riscv64 — info

An emulated RISC-V machine that starts through UEFI. The field schema is in 015-board-qemu-x86-64.info.md, and the reasoning for having UEFI boards at all is at the top of 030; this file records only what differs.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `032-board-qemu-uefi-riscv64.lua` and run the sweep again.*

## What it describes

| Field | Value | |
|---|---|---|
| `board_id` | `"qemu-uefi-riscv64"` |  |
| `arch` | `"riscv64"` |  |
| `emulator` | `"qemu-system-riscv64"` |  |
| `machine` | `"virt"` |  |
| `cpu` | `"rv64"` |  |
| `memory_sizes` | `{ small = "256M", plenty = "4G" }` |  |
| `console` | `a table below` |  |
| &nbsp;&nbsp;↳ `kind` | `"ns16550a"` |  |
| &nbsp;&nbsp;↳ `base` | `0x10000000` |  |
| &nbsp;&nbsp;↳ `note` | `"16550 at 0x10000000; the firmware narrates here before t...` |  |
| `framebuffer` | `a table below` |  |
| &nbsp;&nbsp;↳ `kind` | `"virtio-gpu-pci"` |  |
| &nbsp;&nbsp;↳ `note` | `"firmware drives it and hands over address, size and pixe...` |  |
| `storage` | `{ controller = "usb-storage" }` | USB, deliberately -- the most demanding of the three, and the one the firmware has to work hardest to read a boot fil... |
| `payload` | `a table below` |  |
| &nbsp;&nbsp;↳ `kind` | `"uefi-esp"` |  |
| &nbsp;&nbsp;↳ `boot_path` | `"EFI/BOOT/BOOTRISCV64.EFI"` | the third name, and the third half of issue 402's answer: an x86 firmware looks for BOOTX64, an ARM one for BOOTAA64,... |
| &nbsp;&nbsp;↳ `firmware_code` | `"/usr/share/qemu/edk2-riscv-code.fd"` | As flash chips, like the x86 board and unlike the ARM one. Handed over whole, this firmware asserts during its own st... |
| &nbsp;&nbsp;↳ `firmware_vars` | `"/usr/share/qemu/edk2-riscv-vars.fd"` |  |
| &nbsp;&nbsp;↳ `note` | `"firmware as two flash chips; it reads EFI/BOOT/BOOTRISCV...` |  |
| `verified_against` | `"qemu 'virt' machine with edk2 firmware; "` |  |

