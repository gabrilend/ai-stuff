# Phase 1 — The draw

The shared spine: a supplier that answers *give me a file, at random,
that I am allowed to lend*, knowing nothing about who asked. Both visions
consume it, so it is built first and alone.

## Where the phase stands

One issue open, substantially built.

| issue | what it is | status |
|---|---|---|
| 100 | the random draw | in progress — core done, config and ledger persistence remain |

## What exists

The draw resolves paths, walks a corpus, filters, and picks. Twenty-two
tests pass. The module never reads the contents of a file it names, and
never returns a path from outside the folder it was pointed at.

## What the phase has taught so far

**The boundary is not a string comparison.** Deciding whether one path is
inside another looks like a prefix test and is not. A sibling directory
named `lend-secrets` passes a naive prefix test against `lend`; a symlink
passes every string test there is. The check has to go through the
filesystem, and the test suite has to contain each way out as its own
case, because they fail independently.

**A path resolver that tolerates missing files is not safe here.** The
first implementation resolved with a flag that succeeds when only the
last component is absent — so a filename the corpus never contained came
back resolved and tested as lendable. Nothing in review caught it; a test
asserting that a never-written name is outside caught it immediately.
The lesson generalises: for a boundary function, the test that a
*non-existent* thing is refused is as load-bearing as the tests about
real ones.

**Rate is the exposure, not secrecy.** The project's threat is not that a
stranger reads one file — the corpus is chosen for lending. It is that
deletion is the request, so a stranger inside can ask repeatedly and a
random draw run enough times becomes a complete copy. That is why the
per-file ceiling lives in phase one, ahead of any credential work. The
credential only bounds how many draws someone gets; the ceiling bounds
what the draws can add up to.

**Running dry is an outcome, not a failure.** The draw returns nothing
plus a reason when a viewer has seen everything. Making that distinct
from an error means callers can say so to the viewer instead of retrying
into a wall.

## Open questions carried by this phase

- Does the roll rebuild while running, or is a restart required to see
  new files?
- What is the repeat ceiling's default — one per file per viewer, or
  unlimited?
- Should the ledger survive a restart? It does not today, so a restart
  lets every viewer see everything again.
