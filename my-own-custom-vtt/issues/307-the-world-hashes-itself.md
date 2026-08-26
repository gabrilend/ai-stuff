# 307 -- The world hashes itself

**Phase:** 3, the world ticks
**Blocked by:** [305](305-randomness-comes-from-named-streams.md),
[306](306-the-command-log-is-the-replay.md)
**Blocks:** [310](310-the-phase-three-demo.md), and every later claim about
replays.
**Documents:** [the world and its tick](../docs/004-the-world-and-its-tick.md)

## Current behaviour

Nothing exists.

## Intended behaviour

One number that stands for the entire state of the world at one instant.

Same function, three uses: checking a file survived the disk
([108](108-a-world-writes-itself-down.md)), checking a replay reproduced a session,
and checking two thread counts agree. **One hash, three uses** -- not three
functions that could disagree about what "the same world" means.

### What is hashed

Every block, in order, byte for byte -- including the stream positions from
[305](305-randomness-comes-from-named-streams.md), because two worlds that look
identical but will roll differently are not the same world.

Padding is not hashed. A struct's padding bytes are whatever the compiler left
there, and hashing them makes the same world hash differently on two builds. The
hash walks fields, exactly as the file writer does.

### The harness this exists for

A test that runs a scripted session twice and compares the hash **at every tick**,
not only at the end.

Comparing only the end tells you they diverged. Comparing every tick tells you
*when*, and when is the entire diagnostic -- a divergence at tick 4,000 in a
session of 10,000 is a hundred times easier to find than "the results differ".

Run it across: one thread versus many, two optimisation levels, and a replay
against the original.

### What it catches

| Failure | How it shows up |
| --- | --- |
| A float crept in | Divergence at different ticks on different builds. |
| An unstable tie-break in the sweep | Divergence between thread counts, intermittently. |
| A stream not in the snapshot | Divergence after the first rollback and never before. |
| Unordered iteration acted on | Divergence between runs on the same machine. |
| A ruleset reading the clock | Phase 7. Divergence between any two runs at all. |

Every one of these is silent without this test and unfindable an hour later with
it absent.

## Suggested implementation steps

1. Write the hash as a field walk shared with the file writer, so the two cannot
   drift about what is in a world.
2. Make it cheap enough to run every tick in a test build and compiled out of a
   release build -- it is a test instrument, not a feature.
3. Write the comparison harness: run twice, compare per tick, report the first
   differing tick and which block differs.
4. Make that harness part of the build, not a thing somebody remembers to run.
5. Write the companion `.info.md`.
6. Test the test: deliberately introduce a divergence -- an iteration order that
   depends on thread count -- and assert the harness names the right tick.
