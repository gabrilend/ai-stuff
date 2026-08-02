# 016-board-qemu-arm64 — info

A board description: pure data, no functions. The field schema lives in
`015-board-qemu-x86-64.info.md`; this file records only what differs.

## This board's values

The `virt` machine — the plain board qemu invented for exactly this use, with
devices where its handover structures say they are. Console is a PL011 mapped
at `0x09000000`; under qemu a byte stored there transmits with no setup, a
tidiness real PL011s do not promise (705's list). Storage is the NVMe path.

The payload path, confirmed empirically by the 019 stub: the generic loader
places raw bytes at `0x40100000` (DRAM begins at `0x40000000`), and a second
loader entry points processor zero at them. Without that second entry the
machine sits at reset forever.
