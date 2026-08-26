# 1406 — The companion pages

Produces `src/096-symbol-sweep.lua`.

## Current behavior

Nothing. Ninety companion pages are promised by `002` and must not be written by
hand.

## Intended behavior

**Generate one `NNN-name.info.md` per blueprint, from the blueprint's own
declarations and the ledger's reverse index.**

### Why generated

The project's rule is that a thing is written once. A companion page written by
hand is the same information twice, and the second copy is the one that goes
stale. So the sweep writes them and the header of every one says: do not edit this,
edit the blueprint.

### What a page contains

**What this blueprint publishes.** Every symbol, its unit, its kind, its resolved
value, and its meaning. This is the interface other blueprints consume.

**What it consumes, and from where.** Every symbol its derivations reference, with
the blueprint that declares it. This is the dependency list, and it is the part a
reader most often wants: *what do I have to understand before this file makes
sense?*

**What consumes it.** From `094`'s reverse index. The other half, and the one that
tells somebody what breaks if they change a number here.

**Its constraints**, with their reasons.

**Where it sits.** Its phase, the issues that describe it, and the blueprints on
either side of it in the dependency graph.

### The coverage report

Alongside the pages, one summary: which blueprints have symbols nobody consumes,
which have no constraints, which have targets outstanding, and which have
drawings with no dimensions called out. **Four ways for a blueprint to be thin**,
and the report makes thinness visible rather than leaving it to be discovered by
whoever tries to build from it.

### Idempotence

Running the sweep twice must produce identical files. That means no timestamps, no
run identifiers, and a stable ordering everywhere — symbols in declaration order,
consumers sorted by number. A generator whose output changes when nothing changed
makes every commit look like a documentation edit.

## What the file must offer

Sweep a directory, write the pages, write the coverage report, report what it
wrote. A dry-run mode that reports without writing, because a person will want to
know what a sweep would change before it changes it.

## Tests

- A fixture blueprint produces a page containing every declared symbol.
- The consumes list names the right source blueprint.
- The consumed-by list is the reverse of another page's consumes list.
- Two consecutive runs produce byte-identical output.
- Dry run writes nothing.
- The coverage report finds a deliberately thin fixture.

## Blocks

`1409`.

## Blocked by

`1404`.

## Related documents

`002` for what a companion page is for.
