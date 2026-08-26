# 1304 — What a materials engineer receives

Produces `src/090-handoff-package.md`.

## Current behavior

**Done.** `src/090-handoff-package.md` exists with the omissions list **at the
front**, and `C-090-1` asserts it as a **floor rather than a ceiling** — the
failure mode of a handoff package is a shorter list than the truth, so shortening
it is a violation.

Seven omissions. The largest is that **every number in this project is a point
value and nobody has written down a tolerance for anything**. A materials engineer
will ask on the first day.

`C-090-4` reduces the notation's whole claim to a fraction: **about four numbers
in seven are derived rather than chosen**, and the remaining three are the
material properties, the process figures and the eleven lengths somebody decided.

The worked example is the part that makes this a machine rather than a folder of
drawings: **change the compute die's edge from twenty-four millimetres to
twenty-six and run the checker.** It names the core-edge constraint, because the
core's size is derived one way from outside the cube and another way from the
stack inside it, and nothing forces those two arguments to agree.

**The ownership table is not here** — which blueprint a question goes to, and
which open question bears on it. It wants generating from the tickets rather than
writing.

## Intended behavior

**The package, its contents, its reading order, and — the part that matters most —
the list of things this design does not tell them.**

### The contents

- The ninety blueprints in `src/`, with their companion pages.
- The checker, `095`, and its report.
- The documentation in `docs/`, chiefly the five datapaths and the honest
  departures page.
- The bill of materials and the specification sheet.
- The bring-up procedure.
- The open questions page, in full and unedited.

### The reading order

Not the numeric order. A person receiving this should read:

1. `000`, for what the object is.
2. The five datapath documents, because one journey teaches more than six part
   descriptions.
3. `008`, for the six places the original idea was overruled and what the numbers
   were.
4. `012`, for the eleven chosen lengths everything else derives from — **this is
   the shortest path to understanding what is actually decided here.**
5. Their own phase.
6. `009`, before doing anything.

### The list that matters

**What this design does not tell them.** It should be long, specific, and at the
front rather than the back:

- **No tolerances.** Every number in the project is a point value. `009` entry X2
  admits it. A materials engineer will ask for the tolerance on the cube edge and
  the honest answer today is that nobody wrote one down. This is the single largest
  omission.
- **No supplier or process qualification.** Three nodes are named; none is
  qualified, and nobody has confirmed a line will run the cold plate's etch.
- **No thermal or mechanical simulation.** The thermal chain is one-dimensional
  hand analysis with a spreading term that is currently a guess. It has not been
  meshed.
- **No signal integrity simulation.** `051` and `063` are budgets, not
  extractions.
- **No cost.** `088` gives structure and sensitivity, deliberately not a price.
- **Nothing has been built or measured.** Every number is derived. Consistent is
  not correct and correct is not manufacturable.

### The one thing the package does have that most do not

**It checks.** `095` loads every blueprint, resolves every symbol, evaluates every
constraint, and reports. A recipient can change a dimension and find out
immediately what breaks — which is a different kind of document from a set of
drawings, and the handoff should explain how to use it that way, with a worked
example. `103`'s suggested step of changing the die size and watching the core
edge constraint fire is the right example, because it demonstrates the two-chain
check catching something a reader would not have caught.

### Who owns what afterward

A short table: which blueprint a question about a given subject goes to, and which
open question in `009` is likely to bear on it. This is the part that makes the
package usable by somebody who did not write it.

## Symbols this must publish

Contents list. Reading order. The omissions list, itemised. Worked example
specification. Ownership table. Blueprint, constraint and open question counts,
all pulled from the ledger rather than counted by hand.

## Constraints this must assert

- Every blueprint in `src/` appears in the contents.
- Every open question in `009` appears in the ownership table.
- The counts match what `095` and `097` report. A summary document that disagrees
  with the thing it summarises is worse than none.

## Suggested implementation steps

1. Write the omissions list first and put it at the front.
2. Write the reading order and justify it against numeric order.
3. Write the worked example using `103`'s die size change.
4. Build the ownership table from the tickets' related-documents sections.
5. Pull every count from the ledger.

## Blocks

Nothing. This is the last one.

## Blocked by

`1301`, `1302`, `1303`, `1205`, and every blueprint.

## Related documents

`001` for what the deliverable was declared to be. `009`, which travels with the
package unedited.
