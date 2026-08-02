# 017-board-qemu-riscv64 — info

A board description: pure data, no functions. The field schema lives in
`015-board-qemu-x86-64.info.md`; this file records only what differs.

## This board's values

The `virt` machine again, on the third architecture. Console is a 16550 — the
same device family the x86 board talks to — but memory-mapped at `0x10000000`
rather than behind port instructions: one device, two ways of reaching it
(issue 401's point about hands differing in shape). Storage is the USB path,
deliberately the most demanding of the three.

The payload path, confirmed empirically by the 019 stub: with `-bios none`
there is no firmware at all, and the reset vector at `0x1000` ends in a jump
to the start of DRAM at `0x80000000`. The raw bytes sit exactly there; no
PC-setting entry is needed.
