# Phase 3 — What it is told

**Goal.** The text payload the machine wakes up holding: the instruction, the
carried device descriptions, the bundled build patterns, and the decision about
which part of all that is present at the start versus fetched when relevant.

Settled while there is one engine to test against rather than three.

## Issues

| | | Status |
|---|---|---|
| `301` | What the machine is told | not started |
| `302` | The descriptions it carries | not started |
| `303` | The patterns it carries | not started |
| `304` | What is said at once, and what is fetched | not started |

## Where the risk is

`301`, and the risk is not technical. The instruction has to convey an order that
cannot be rearranged and two prohibitions that must not be softened, while
avoiding turning the four rungs and the status square and the condensing into
requirements — those are suggestions and belong in `303`. A machine that decides
to organise itself completely differently should still be able to follow the
instruction.

The test of whether this phase succeeded is `602`, not anything inside this
phase.

## Demo

The machine asked what it is carrying, and answering — then asked for a pattern
it has not been shown, and fetching it.
