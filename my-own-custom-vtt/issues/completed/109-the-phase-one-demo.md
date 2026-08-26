# 109 -- The phase one demo

**Phase:** 1, the world holds still
**Blocked by:** every other issue in phase 1.
**Blocks:** nothing. It is the capstone of the phase.
**Documents:** [the roadmap](../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` reports that no demos have been built yet, and points at the
roadmap. That is the correct behaviour for a project in this state and it already
works.

## Intended behaviour

An executable at `issues/completed/demos/phase-1-demo`, taking the project root as
its first argument, which shows that a world can be described, held, checked, and
round-tripped.

Phase demos are not development scrap. They are part of what this project
delivers, they are kept working, and each one recombines the tools of earlier
phases into something none of them could do alone. Phase 1 has no earlier phases
to recombine, so its job is narrower: **show the numbers**, and prove the round
trip.

### What it shows

Statistics first, description second. A demo that explains itself at length and
shows three numbers has the balance backwards.

| Reported | Why it is worth seeing |
| --- | --- |
| Counts per block -- things, walls, regions, vertices, lights, strings | The shape of a world at a glance. |
| Region nesting depth, and the deepest chain | The parent walk in phase 6 has a cost, and this is it. |
| Bytes per block, and the total | What a world costs. The number somebody will quote later when deciding whether to preallocate. |
| Bytes in the file versus bytes in memory | How much of the world is padding the writer refused to emit. |
| Time to validate | This runs on every load and after every structural change; it should be watched from the beginning rather than discovered to be slow in phase 8. |
| Time to write, and to read back | The same. |

Then the round trip: write, read, write again, compare the two files byte for
byte, and say so plainly. That comparison is the whole claim of phase 1 and it
should be the last line on the screen.

### And it must fail visibly

The demo should also deliberately corrupt a world and show the validator refusing
it -- naming the block, the index, the field, the value found, and what was
expected. A demo that only shows success is a demo that has not shown the most
important thing this phase built, which is a component that will not guess.

## Suggested implementation steps

1. Write the world it operates on with a tool, not by hand. Phase 8 builds the
   real generator; for now a small fixture-maker that emits a few rooms, a nested
   region, and some props is enough -- and it lives in `src/` as a permanent tool,
   because every later phase's tests will want fixtures too.
2. Write the demo as a bash script that builds what it needs and runs it, so that
   it works from a clean checkout with no prior build step.
3. Ensure `tmp/shared-memory/` exists before writing anything to it. The demo's
   scratch files are ephemeral and belong in the RAM tier.
4. Report timings from the run rather than quoting numbers in any document. A
   document with a hard-coded measurement in it is a document that becomes wrong
   without anybody noticing.
5. Confirm `./run-phase-demo` finds it, offers it, and runs it, both with and
   without an argument.

## Related tools

The fixture-maker from step 1 is not a temporary script. It is the first thing in
the project that makes rather than holds, and phases 2 and 3 both need worlds to
run against before phase 8's generator exists.
