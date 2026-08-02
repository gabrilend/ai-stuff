# 705 — What the emulator lies about

## Current behavior

Passing every emulated test is treated as meaning the seed works. It does not
mean that, and the places where it does not are currently discovered one at a
time, painfully, at first light.

**Three entries already exist and should start the list.** All three were paid
for during `701` and `702a` rather than predicted:

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
