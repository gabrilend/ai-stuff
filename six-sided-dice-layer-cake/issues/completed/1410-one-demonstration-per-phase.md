# 1410 — One demonstration per phase

Produces `src/100-the-phase-demonstrations.lua`, fourteen scripts in
`issues/completed/demos/`, and `run-demo` at the project root.

## Current behavior

**Done.** All sixteen files exist and run.

`./run-demo` with no argument lists the fourteen phases and asks which. Each
demonstration loads the whole blueprint set, picks out that phase's files, and
shows what the phase actually produced: its blueprints with symbol and constraint
counts, its headline numbers **with live values**, every constraint it asserts and
whether it holds, and anything it left as a target.

Phase fourteen is different, because it has no dimensions of its own. What it
produced is the ability to ask the other thirteen anything, so its demonstration
exercises that instead — the units engine refusing four things it should refuse,
and one derivation traced from its inputs to its answer, then the same number
derived the other way round from the memory stack so that a reader can see the
two-chain check with both halves in front of them.

Phase thirteen additionally builds the specification sheet, the bill of materials,
the full listing and the site, and prints the paths — because the capstone's
output is something to look at rather than something to read in a terminal.

## Intended behavior

**A demonstration of a blueprint set cannot be a program doing something.** There
is no machine; there is a design. So the demonstration is the design answering
questions about itself, and the property that makes it a demonstration rather than
a printout is that **every figure is resolved at the moment you run it**. Change a
dimension in `src/` and run it again and the numbers move.

That is also what makes it a test. A phase whose demonstration cannot name six of
its own figures has not settled anything, and a phase whose constraints stopped
holding says so where somebody will see it.

## Suggested implementation steps

1. One engine that takes a phase number, so that fourteen demonstrations are
   fourteen lines of shell rather than fourteen programs to keep in step.
2. Name each phase's headline symbols explicitly rather than printing everything
   it declares. The choice of which eight or ten figures say what a phase
   produced is the editorial content of the demonstration.
3. Group constraints by the phase of the blueprint that asserts them, and print
   the failures rather than only the count.
4. Give phase fourteen a different shape, because a list of numbers would say
   nothing about what instruments are for.
5. Have phase thirteen produce files and name them, since a site is not a
   terminal output.

## Blocks

Nothing.

## Blocked by

`1405` for the checker, `1407` and `1409` for what phase thirteen's demonstration
builds.

## Related documents

`002` for the notation the figures come from.
