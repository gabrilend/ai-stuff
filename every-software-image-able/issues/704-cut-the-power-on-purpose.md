# 704 — Cut the power on purpose

## Current behavior

`docs/003` names one failure this design cannot help with: the window during
moving in where the machine exists in two places, or in neither. Nothing tests it,
and on real hardware it can only be met by pulling a plug and hoping to hit the
moment.

## Intended behavior

The machine's state saved and restored exactly, so that power can be cut at a
chosen instant — every instant in the window, repeatedly — and the outcome
observed rather than guessed at.

## Suggested implementation steps

1. Get snapshots working: save the whole emulated machine, restore it, confirm it
   continues identically.
2. Sweep the move-in window. Snapshot at its start, run forward a chosen number of
   instructions, kill the machine, restart it from its storage, and see what state
   it came back in.
3. **Bisect rather than scan.** The window may be millions of instructions long
   and testing each one is pointless — what is wanted is where the *boundaries*
   are. Find one instant that recovers and one that does not, then narrow between
   them. The answer is the same and it costs a few dozen runs instead of millions.
   Watch for more than one band, though: bisection assumes a single boundary, and
   a window with two unrecoverable stretches will hide one of them.
3. Report the shape of the damage rather than a pass or fail. What matters is
   which instants are recoverable, which leave the machine confused, and which
   leave it unable to start at all — and whether the unrecoverable band is one
   instruction wide or a million.
4. Do the same for the intent notes of `205`. A note written before a probe is
   only useful if it survives the machine dying, and dying halfway through writing
   the note is the case it was designed for.
5. Use recorded and replayed execution where the emulator offers it. It provides
   at the hardware level what `006` describes the machine doing for itself, which
   makes it a way to check that the machine's own version agrees.
6. Keep the results as data. This is the sharpest measurement in the project — how
   fragile the one unhelpable moment actually is — and it is the kind of number
   that should never be written into a document (`docs/011`).

## Blocks

Nothing. It informs `206` and `602`.

## Blocked by

`701`, `206`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the window this ticket exists to measure.
