# 705 — What the emulator lies about

## Current behavior

Passing every emulated test is treated as meaning the seed works. It does not
mean that, and the places where it does not are currently discovered one at a
time, painfully, at first light.

**This ticket does not close.** It is a list that grows every time the board
disagrees with the emulator, and marking it done would mean claiming the
disagreements had stopped. It is in its correct state when it is current, not
when it is finished.

**The list is at `notes/023-what-the-emulator-lies-about.md`**, each entry with a
price beside it, plus a section of expected-but-unpaid ones written down before
being met. A list of differences is interesting; a list of differences with costs
attached is the argument for how often to stop developing against emulation and
go put something on a card. That argument gets made on feeling otherwise.

**The count is not written here**, because it was written here twice and was
wrong both times — it said fifteen on 2026-08-08 while the file held seventeen,
having drifted every time somebody added an entry without coming back. Count the
`###` headings under "Paid for already" if the number is wanted. A ticket that
states a total it does not own will always eventually lie about it.

What has been added since the ticket was written, all paid for rather than
predicted: no framebuffer without UEFI; three firmwares handed over three
different ways; an image base that is memory on one machine and nowhere on
another; every symbol reference becoming a silent zero with no linker;
offsets counted by hand producing numbers that look like numbers; a fixture
with an unstated precision; the two RAM tiers; a transcribed constant; the
stack pointer's small region; where a rounding happens; the one failure that
was loud; that **the emulated processor is not the host's processor**, which
cost a test written on a wrong premise and returned a better test than the
original; and — most recently — that **the emulator fabricates the filesystem
the firmware reads**.

That last one is the largest so far and the only one found before it was paid
for. The boards are handed a host directory which the emulator synthesises into
a FAT filesystem on demand, so no disk image exists at any point in a run that
boots real firmware to first light. What it concealed was not a subtle
difference in behaviour but a missing component: **the image `502` builds has no
partition table and no filesystem, and therefore cannot be booted by anything**,
and six boards across three architectures reached first light without that ever
mattering.

It is the strongest argument this file contains for its own existence, and it
sharpens what the file is for. The other entries are differences between a real
board and an emulated one. This one is a difference between the *road* to the
machine and the road a card takes — the payload was delivered by a mechanism no
card has — and a road that is not the real road can carry a machine all the way
to working while a required piece is simply absent.

The three the ticket was seeded with, paid for during `701` and `702a`:

| Difference | What it cost |
|---|---|
| Traps cover only addresses somebody wrote down; a real board is full of devices nobody described | Not yet paid. A machine exploring an undescribed device passes the whole matrix while destroying hardware. |
| A write that ends the machine cannot be reported by a watchpoint — the connection dies with it | One run. Found immediately because the real RISC-V hazard was in the map beside the synthetic ones. |
| The debugger must be told the *processor's* architecture, not the mode the code runs in | One run, and it reported a false clean while connected to nothing. |

The middle one is worth keeping as an argument as much as a fact: it was found
only because one genuine fatal register sat in a map otherwise full of
invented ones. A map of purely synthetic hazards would have passed everything
and taught nothing.

## Intended behavior

A maintained list of every known difference between the emulated machine and real
hardware, kept current as differences are found, and a hardware loop that runs
often enough to keep finding them.

## Suggested implementation steps

1. Start the list with what is already known. Emulated memory maps are tidier than
   real ones. Emulated firmware hands over in a cleaner state. Devices answer
   faster and more predictably. Nothing dies. Timing is meaningless, so any
   initialisation sequence whose waits are wrong will pass in emulation and fail
   on the board.
2. Add to it every time first light fails for a reason emulation did not catch,
   **and record what each one cost** — how long it took to find, and how far into
   the work it surfaced. A list of differences is interesting; a list of
   differences with prices attached is the argument for how often to run on real
   hardware, and that argument will otherwise be made on feeling.
3. Start it with the one `702a` cannot help: traps only cover devices somebody
   modelled, and a real board is full of devices nobody did. A clean run means the
   machine behaved on the hardware we imagined.
3. Keep the speed numbers separate and clearly marked. Emulated
   tokens-per-second is not slow-but-indicative, it is meaningless, and putting
   the two in one table invites somebody to compare them.
4. Run on real hardware on a schedule rather than when something feels ready.
   The gap between the two loops grows silently, and the cost of closing it grows
   with it.
5. Where a difference can be emulated, emulate it — a deliberately hostile memory
   map with holes in awkward places costs little and catches a class of bug that
   otherwise waits for the board.

## Blocks

Nothing. It is the reason `601` will take less time than it otherwise would.

## Blocked by

`701`.

## Related documents

`docs/012-datapath-the-proving-ground.md` — the two loops, and why the second
cannot be skipped.
