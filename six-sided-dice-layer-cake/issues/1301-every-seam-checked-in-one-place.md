# 1301 — Every seam checked in one place

Produces `src/087-system-integration.md`.

## Current behavior

Nothing. Roughly a hundred and forty cross-blueprint constraints have been asked
for by individual tickets and nobody has checked that they cover the seams.

## Intended behavior

**The interface register: every place two phases meet, what crosses, which
blueprint owns it, and whether a constraint exists on it.**

### Why this is the capstone rather than a summary

Each blueprint checks itself. `095` checks every constraint that has been written.
Neither notices a constraint that was never written, and **the gaps are always at
the seams** — between the phase that produces a number and the phase that consumes
it, where each assumes the other is handling it.

So this blueprint is a register of seams, and its output is a list of the ones that
are unguarded.

### The seams

Roughly forty, and the blueprint must enumerate them rather than sampling. The
ones already visible from the tickets:

| from | to | what crosses |
|---|---|---|
| model shape (`078`) | slice capacity (`047`) | layer size, twice over |
| slice capacity | die area (`041`) | half the die |
| die area | face plate (`013`) | four dies plus streets |
| face plate | the cube (`012`) | plus edge rails |
| engine power (`045`) | power map (`041`) | to spreading (`025`) |
| heat (`020`) | flow (`024`) | to junction temperature (`025`) |
| conversion loss (`028`) | heat (`020`) | the energy identity |
| core bandwidth (`034`) | crossbar (`037`) | single-face-takes-all |
| crossbar | link (`051`) | and to slice write (`047`) |
| transfer size (`052`) | four owners | correction line, interleave, quantum, latency |
| tier count (`036`) | core edge (`012`) | the two-chain check |
| spare fractions (`051`, `063`) | yield (`083`) | in both directions |
| lifetime (`086`) | nine mechanisms | the allocation |

### The three triple checks

Three quantities are derived by three independent routes and must agree. They are
the most valuable constraints in the project because each catches an error that no
single blueprint could:

- **Crossover batch**, from `045`, `053` and `079`.
- **Time per token**, from `055`, `061` and `080`.
- **Core edge length**, from the cube inward and from the tier stack outward.

This blueprint must confirm all three are actually asserted somewhere, and assert
them here if not.

### What it must produce

**A list of unguarded seams.** Not a narrative. For each seam: the two blueprints,
the quantity, and either the tag of the constraint that guards it or the word
missing.

That list, with nothing on it, is what finishing this project means.

## Symbols this must publish

Seam count. Guarded and unguarded counts. The three triple checks and their
agreement. Constraint count by phase. Count of `target` kinds still outstanding.

## Constraints this must assert

- Every seam in the register has a constraint tag. **The capstone constraint**, and
  the one that will fail longest.
- The three triple checks hold.
- No `target` kinds remain anywhere in the blueprint set.
- Every blueprint has at least one constraint. A blueprint with none has published
  numbers nobody checked.

## Suggested implementation steps

1. Enumerate the seams from the blocks-and-blocked-by graph in the tickets, which
   is already most of the work.
2. For each, find the constraint or record it missing.
3. Confirm the three triple checks.
4. Publish the unguarded list and treat shortening it as the remaining work.

## Blocks

`1302`, `1303`, `1304`.

## Blocked by

Everything.

## Related documents

`001` for the phase structure this crosses. `002` for the constraint notation.
