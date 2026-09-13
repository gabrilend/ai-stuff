# 113 — Every mechanic has a test

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 101 |
| Blocks | — |
| Reads | [the tests come first](../docs/014-the-tests-come-first.md) |
| Open questions | none |

## Current behavior

The tests exist before the source does. Under `tests/` there is a harness and
ten test programs, one per phase, each carrying a line naming the issues it
covers; `./validate-documentation` refuses a coverage claim on an issue that
has no file and **counts** how many issues have a test naming them. The count
is reported and does not fail, because at this stage the tests are the
specification and the number is the interesting part. `./run-tests` runs every
program under `tests/` and reports each named absence as a failure, never a
skip.

## Intended behavior

The rule this issue enforces: **a mechanic with source behind it and no test
naming it is a bug in the project**, at the same severity as a wrong answer.

Three things make it a rule rather than an intention:

- **The harness is the only shape a test takes.** Every test program loads its
  subject by stem through the harness, which refuses on zero or two matches;
  asserts through the harness's check, which prints one line per claim; pins
  the suite's seed from the environment; and exits non-zero through the
  harness's report if any claim did not hold. A test that does its own loading
  or its own counting is refused by review, because a test with its own
  behaviour is an instrument that measures itself.
- **The census fails once there is source.** For every stem in the contract
  table of the tests document, if a file with that stem exists under `src/`,
  the issue that owns the stem must be named by some test's covers line, or
  the validator fails naming the stem and the issue. Until the file exists the
  census only counts, which is the behaviour it has today.
- **Every fixed bug gets a test that fails without the fix**, placed in the
  phase's program under a folded function whose comment says what went wrong.
  The reason for chasing a bug is never that an issue exists; it is that the
  thing has to work, and the test is what says it does.

The harness's exports, which the ten programs already assume:

| Function | Does |
| --- | --- |
| `load(stem)` | finds exactly one `src/NNN-<stem>.lua` and returns its module, or fails naming the stem and the issue that creates it |
| `check(name, condition, detail)` | counts and prints one claim |
| `seed()` | the suite's seed, pinned |
| `report()` | prints the totals and exits non-zero on any failure |
| `fresh_world(parameters)` | assembles a world through the tick module for tests that need one |

The phase demo runs `./run-tests` as its first act, so that a demo is never
shown on a build whose own checks do not hold.

## Suggested implementation steps

1. The harness at `tests/018-the-harness.lua` and the ten programs exist; keep
   their covers lines under-claimed on purpose.
2. Add the stem-to-issue table to the validator's census, read from the
   contract table in the tests document rather than kept as a second copy.
3. Make the census fail, not count, for a stem whose file exists and whose
   issue no test names.
4. Add `fresh_world` to the harness once issue 105's assemble exists.
5. Have every phase demo begin by running the tests.

## Related documents and tools

- [The tests come first](../docs/014-the-tests-come-first.md)
- [The shape of the code](../docs/013-the-shape-of-the-code.md)
- The harness: [the harness](../tests/018-the-harness.lua)
- The phase 1 program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)
- `./run-tests`, `./validate-documentation`

## Still open

Nothing beyond the questions in the table.
