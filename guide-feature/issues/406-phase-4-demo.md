# 406 — Phase 4 demo: three real turns per version

phase 4, the turn

## Current behavior

Phase 3's demo shows stand-in turns through rmail once 306 is done.

## Intended behavior

`issues/completed/demos/phase-4-demo` runs the rehearsal with the real turn
on all three stand-in voices, against kuvalu's llama.cpp server, and shows:

- the canvas changing, with marks, in the terminal;
- per turn: words changed against the budget, fit tries and why, give-ups;
- per voice and endpoint: seconds and tokens per turn;
- a role switched to another endpoint halfway through with
  `scripts/use-endpoint`, and the switch visible in the numbers.

## Suggested implementation steps

1. The run script.
2. Fill in `issues/phase-4-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 4

## Blocked by

402, 405.

## Blocks

None.
