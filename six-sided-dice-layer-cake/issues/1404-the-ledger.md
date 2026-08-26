# 1404 — The ledger

Produces `src/094-ledger.lua`.

## Current behavior

Nothing. `002` promises that a symbol is written once and referenced everywhere,
and nothing enforces it.

## Intended behavior

**Load every blueprint, sort the symbols into dependency order, resolve them all,
and refuse in the four ways that matter.**

### The four refusals

**A duplicate name.** Two blueprints declaring the same symbol is either a copy or
a disagreement, and both are worth stopping for. This is the refusal that makes
`002`'s central claim — one dimension, one place — true rather than aspirational.

**An undefined reference.** An expression naming a symbol nobody declares. Names
the referencing file, the symbol, and the position from `092`.

**A cycle.** Two derivations that depend on each other. The error must print the
whole cycle, not just detect one, because a cycle of five is much harder to find
than to fix.

**A dimension mismatch inside a derivation.** Caught by `091` during evaluation and
re-raised with the blueprint and symbol attached.

### The order

Build the dependency graph from `092`'s symbol collection, topologically sort it,
and evaluate in that order. Nothing else works: evaluating in file order means
resolving `L_cavity` before `t_face` exists, and evaluating lazily means a cycle is
discovered as a stack overflow rather than as an error.

### What it publishes

A table of every symbol with its resolved quantity, its kind, its meaning, and the
blueprint that declared it. Plus the reverse index — for every symbol, which
blueprints reference it — which `096` needs for the companion pages and `087` needs
for the seam register.

That reverse index is worth as much as the values. **A symbol nothing references is
either dead or the design has a hole**, and only the ledger can tell.

### Orphans and targets

Report, without failing: symbols nothing references, and symbols of kind `target`.
Both are conditions the project should see every time it runs, and neither is an
error today. `095` decides what to do about them.

## What the file must offer

Load a directory of blueprints. Resolve. Return the symbol table, the reverse
index, the orphan list and the target list. Raise on the four refusals.

## Tests

- A fixture set of three blueprints with a chain of derivations resolves in the
  right order.
- A duplicate raises and names both files.
- An undefined reference raises with a position.
- A cycle of three raises and prints all three.
- The reverse index finds every reference including those inside constraints.
- An orphan is reported and does not fail.

## Blocks

`1405`, `1406`, `1407`, `1408`, `1409`.

## Blocked by

`1401`, `1402`, `1403`.

## Related documents

`002`. `087`, which consumes the reverse index.
