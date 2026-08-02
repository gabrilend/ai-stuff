# 203 — Touch memory

## Current behavior

The model can describe memory. It cannot read or write a byte of it.

## Intended behavior

Reading and writing physical addresses, as a tool call, with the ranges the
engine and the weights occupy refused rather than merely discouraged.

## Suggested implementation steps

1. Read and write, at a physical address, in the widths the processor supports.
   No translation, no permission layer — this machine has neither, and adding one
   here would be inventing a kernel the design deliberately does not have
   (`docs/001`).
2. **Refuse writes into the engine and the weights.** The ranges are known from
   `102`. This is the one place in the seed where the model is stopped from doing
   something it asked to do, and the reason is specific: a mind that overwrites
   itself does not report an error, it goes quiet (`docs/010`).
3. Refuse reads and writes outside the usable ranges from the firmware map, or at
   least report that the address was outside them. On some machines a read from
   nothing hangs the bus, which turns a typo into a dead computer.
4. Return what was actually read, not what was expected. Some addresses are
   devices rather than memory and do not hold what was last written to them; that
   difference is information the model needs.
5. Provide a bulk form — fill a range, copy a range, compare two ranges — because
   a model issuing one call per byte spends its whole context on addresses.

## Blocks

`204`, `205`.

## Blocked by

`201`, `202`.

## Related documents

`docs/010-datapath-the-mind.md` — why writing into the mind is the one
irreversible mistake in software rather than hardware.
