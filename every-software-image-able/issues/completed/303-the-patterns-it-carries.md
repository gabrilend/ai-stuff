# 303 — The patterns it carries

## Current behavior

**Done, and tested** -- `src/083`, checked by `src/085`, 43 of 43 on
2026-08-02.

Eleven patterns, each with four parts, and every one is checked for having
all four: what it is, where it has worked, what it costs, and **where it
stops working**. The last is what makes a pattern usable rather than
decorative -- a shape recommended without its failure mode is a trap with a
good reputation.

Each says out loud that it is a suggestion and that a machine doing something
else entirely has done nothing wrong. The pattern about patterns is carried
with them.

The calling convention is the one exception and is marked as one: an
agreement rather than a suggestion, because everything the machine writes has
to agree with everything else it wrote and that has to start somewhere. It
carries what the flags defect in `204` taught -- a watch that changes what it
watches is not a watch.

`strategems/` in this repository remains this bundle at an earlier stage, and
the two should not be allowed to drift.

## Intended behavior

A bundle of build patterns on the chip. Patterns rather than implementations —
code would decide how the machine gets built, and a pattern says only that this
shape has worked before and leaves every part of applying it to whoever is
applying it.

## Suggested implementation steps

1. Write the ones already named: dispatch tables, thread pools, looping
   iterators, and the ceramic platform once it has been described (it has not
   been — see `notes/007`, and do not build on the term until it is).
2. Write the ones the design leans on without having named them that way: the
   interpreter with its operation table; the four rungs; condensing so that
   deleting costs verbosity rather than capability; the status triple; keeping
   only what could not have been recomputed; walking backward from a saturating
   reading. Every one of these is currently written as though it were how the
   machine works, and every one of them is a suggestion.
3. Give each the same shape: what the pattern is, where it has worked before, what
   it costs, and where it stops working. The last part is what makes a pattern
   usable rather than decorative — a shape recommended without its failure mode
   is a trap with a good reputation.
4. Include the calling convention settled in `204`, because everything the machine
   writes has to agree with everything else it writes, and that agreement has to
   start somewhere.
5. Include `strategems/009` itself. The rule about saying what is wanted and
   leaving the method alone is the pattern that governs the reading of all the
   others, including its own two exceptions.
6. Make them retrievable rather than all present at once — see `304`.

## Note

`strategems/` in this repository is this bundle at an earlier stage. What ships is
that directory grown up, and the two should not be allowed to drift.

## Blocks

Phase 6.

## Blocked by

`204` for the calling convention.

## Related documents

`docs/010-datapath-the-mind.md` — the patterns as the fourth thing on the chip.
`strategems/009-ask-do-not-schedule.md` — the pattern about patterns.
