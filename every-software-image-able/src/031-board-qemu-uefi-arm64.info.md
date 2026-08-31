# 031-board-qemu-uefi-arm64 — info

An emulated 64-bit ARM machine that starts through UEFI. The field schema is in 015-board-qemu-x86-64.info.md, and the reasoning for having UEFI boards at all is at the top of 030; this file records only what differs.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `031-board-qemu-uefi-arm64.lua` and run the sweep again.*

## What it describes

| Field | Value | |
|---|---|---|
| `board_id` | `"qemu-uefi-arm64"` |  |
| `arch` | `"aarch64"` |  |
| `emulator` | `"qemu-system-aarch64"` |  |
| `machine` | `"virt"` |  |
| `cpu` | `"cortex-a72"` |  |
| `memory_sizes` | `{ small = "256M", plenty = "4G" }` |  |
| `console` | `a table below` |  |
| &nbsp;&nbsp;↳ `kind` | `"pl011"` |  |
| &nbsp;&nbsp;↳ `base` | `0x09000000` |  |
| &nbsp;&nbsp;↳ `note` | `"PL011; the firmware narrates here before the payload does"` |  |
| `framebuffer` | `a table below` |  |
| &nbsp;&nbsp;↳ `kind` | `"virtio-gpu-pci"` |  |
| &nbsp;&nbsp;↳ `note` | `"firmware drives it and hands over address, size and pixe...` | The difference this board makes. On the firmware-less ARM board a payload has nowhere to draw until it has written a ... |
| `storage` | `{ controller = "nvme" }` |  |
| `payload` | `a table below` |  |
| &nbsp;&nbsp;↳ `kind` | `"uefi-esp"` |  |
| &nbsp;&nbsp;↳ `boot_path` | `"EFI/BOOT/BOOTAA64.EFI"` | The name is the selection mechanism (issue 402). An x86 firmware looks for BOOTX64 and will never find this; this one... |
| &nbsp;&nbsp;↳ `firmware` | `"/usr/share/qemu/edk2-aarch64-code.fd"` | ARM firmware images are padded to a fixed flash size and this build is not, so it is handed over whole rather than as... |
| &nbsp;&nbsp;↳ `note` | `"firmware reads EFI/BOOT/BOOTAA64.EFI from a FAT filesystem"` |  |
| `verified_against` | `"qemu 'virt' machine with edk2 firmware; "` |  |

