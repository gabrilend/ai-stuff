# 203 — Touch memory

## Current behavior

**Done, and tested** — `src/071` is the rules, `src/072` checks them, 22 of
22 on 2026-08-02. Six hands: `peek`, `poke`, `fill`, `copy`, `compare`, and
`memory` for asking what may be touched at all.

The one refusal holds in every form: a write into the engine or the weights,
a write that only clips them, and a bulk write that would reach them — the
last refused before any of it happens rather than halfway through. Reads are
allowed everywhere the map calls usable, including its own mind, because a
machine reading itself is doing something useful and `204` depends on
reading back what it placed.

`poke` returns what the address holds afterwards rather than what was
written, so a device that does not keep what it is given says so. The test
carries a pretend device for exactly that reason.

Unaligned touches are refused: some processors fault and some quietly split
them into two, which is a different operation than the one asked for, and
refusing is the only answer that means the same thing everywhere.

**One defect worth keeping.** A byte count is not a width. The bulk forms
originally ran their range through the single-touch width check, which
refused every one of them as though sixty-four were an impossible width —
correctly, for entirely the wrong reason. It went unnoticed because the
comparison that should have caught it was itself being refused, and the test
could not tell a refusal from a match. So `compare` now answers three ways:
an offset when the ranges differ, false when they are identical, and nothing
with a reason when it could not look. *They are the same* and *I could not
see* are different facts and must not share an answer.

The real read and write are handed in rather than built here, because on the
metal they are three instructions and hosted they are a pretend region. The
rules are the same either way, and the rules are the ticket.

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
