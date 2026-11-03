# 113 — Every mechanic has a test

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 101 |
| Blocks | — |
| Reads | [the tests come first](../../docs/014-the-tests-come-first.md) |
| Open questions | none |

## Current behavior

Built. The census in `./validate-documentation` reads the stems from the
contract table in the tests document and **fails** for any stem whose file
exists under `src/` or `assets/` while no test's covers line names the issue
that owns it; a stem with no file is still only counted. The harness has
`fresh_world(parameters, modules)`, which assembles a world through the tick.
The phase 1 demo, `issues/completed/demos/phase-1-demo`, starts by running the
written checks and phase 1's program and stops on any that does not hold.

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

## What happened

- **The owner of a stem is the first issue its row names**, the one that
  creates the file -- the same issue the harness names in an absence. A row
  like `the-tick | 105, 801` asks for 105; later issues that add exports to a
  stem are left to the count, so the census does not fail an issue that is
  under-claimed on purpose.
- **Assets count as source.** `the-rules` lives in `assets/`, and the census
  looks there too, so a catalogue table with no test is caught the same way.
- **The report stays `finish()`**, which all ten programs already call; the
  table above said `report()`. Renaming it would touch every program for no
  gain, so the documents say `finish()` now.
- **`fresh_world` takes the parameters and an optional list of stems** and
  returns the world and those modules, exactly what the tick's `assemble`
  returns, so a test's world is validated the way a match's is.
- **The phase 1 demo runs the phase's own checks, and lets a later phase's
  absence through.** The original territory suite stands a tank on the ground
  and so waits for issue 201; an absence whose issue is outside phase 1 is
  printed by name and does not stop the demo, while any failed claim, any
  phase 1 absence, or any written problem does. Then it plays ten thousand
  ticks on one seed twice and prints both hashes, replays the first run's log,
  and draws the field.
- **One bug fixed this phase has its test**: a module loaded by a bare name
  from inside `src/` could not find its directory. The test fails without the
  fix (checked by removing it). The other fixes this phase were to the tests
  themselves or were caught by tests that already existed.
- The census and `fresh_world` are tested in phase 1's program on a scratch
  copy of the project, so the real covers lines are never edited.

## Related documents and tools

- [The tests come first](../../docs/014-the-tests-come-first.md)
- [The shape of the code](../../docs/013-the-shape-of-the-code.md)
- The harness: [the harness](../../tests/018-the-harness.lua)
- The phase 1 program: [the dunes and the clock](../../tests/019-the-dunes-and-the-clock.lua)
- `./run-tests`, `./validate-documentation`

## Still open

Nothing beyond the questions in the table.
