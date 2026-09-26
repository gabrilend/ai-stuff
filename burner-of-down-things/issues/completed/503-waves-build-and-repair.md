# 503 — Waves, build and repair

Building the blueprint level by level, repairing what fails, holding what
cannot be repaired ([007](../docs/007-datapath-the-design.md)).

## Current Behavior

Built as `src/050-building.lua`, with the `build` command in `src/051-the-design-commands.lua`. The fixture's hand-written design (`tests/fixtures/tiny-notes-design/`, whose own tests pass) is what the stand-in writes, with switches to build an issue broken N times and to have one issue's build break an earlier issue's file. Checked by tests/052: a clean build in 3 waves and 6 turns; one repair; a build that never passes (2 repairs, `build-failed`, 301 held and never built); 201's build breaking 101's store, caught after the wave and 101 repaired; an issue that could not be described holding its reach from the start; building again runs no turns. Run end to end through the launcher (open, survey, describe, build) with the delivered notes program then used.

## Intended Behavior

- **Build step** (case, optional set of ids to rebuild): the graph's levels;
  for each level, the ids that are wanted (not `built`, or in the rebuild
  set), not held, and whose blockers are all built — as one set of `build`
  turns (306). Each build prompt holds its issue whole, its blockers' issues
  whole, the target, and the design rules of 007.
- After the set: acceptance for each (502). Pass → `built`. Fail → a
  `repair` turn given the failure; up to two repairs, run as sets of their
  own; still failing → `build-failed`, and its reach (402) is held for the
  rest of this run.
- After each level: acceptance re-run for every built issue; any that now
  fail are repaired before the next level (007, the last decision row).
- A breach stops the step.
- **Command `build`**: lays out the design (501) and runs the build step.

## Suggested Implementation Steps

1. With a stand-in that writes passing code for a three-level fixture
   blueprint. **Test:** three sets of turns, every issue `built`.
2. A stand-in whose build of one issue fails once. **Test:** one repair, then
   `built`.
3. One that always fails. **Test:** `build-failed`; its reach never gets a
   build turn; the rest does.
4. **Test:** running `build` again runs no turns.

## Blocked by

- 402
- 502
