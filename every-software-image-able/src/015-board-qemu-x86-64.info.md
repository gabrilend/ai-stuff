# 015-board-qemu-x86-64 — info

A board description: pure data, no functions. The launcher (018) reads it and
generates the emulator command. This file also carries the field schema for
all board descriptions; 016 and 017 differ only in values and point here.

## The fields

| Field | Type | Meaning |
|---|---|---|
| `board_id` | string | stable name; also names the serial log |
| `arch` | string | which assembly language a payload must be written in |
| `emulator` | string | the program that becomes this machine |
| `machine` | string | the emulator's machine model |
| `cpu` | string | the processor model within it |
| `memory_sizes` | table | named sizes, `{small, plenty}` — small exists to force the ratchet in issue 102 |
| `console` | table | `{kind, base, note}` — where a byte goes to leave on the wire |
| `framebuffer` | table | `{kind, note}` — what display device the board has or gets plugged in |
| `storage` | table | `{controller}` — one of `ahci`, `nvme`, `usb-storage`; deliberately different per board |
| `payload` | table | how the firmware finds something to boot — the load-bearing field (issue 501) |
| `verified_against` | string | what this description was transcribed from |

## The payload table

| Field | Type | Meaning |
|---|---|---|
| `kind` | string | dispatch key in the launcher: `boot-sector` or `loader-device` |
| `load_addr` | integer | where raw bytes are placed (loader-device only) |
| `set_pc` | boolean | whether a second loader entry must point the processor there |
| `bios` | string | firmware override, e.g. `"none"` (loader-device only) |

## This board's values

The BIOS machine: firmware reads sector zero into `0x7c00` and jumps, so the
payload is a 512-byte sector ending in `0x55 0xaa`. Console is the 16550 behind
port `0x3f8`, reached through x86's separate port address space — the hand the
other two architectures do not have. Storage is the SATA path.
