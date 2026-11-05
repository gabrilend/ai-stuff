# 504 — Phase 5 demo: focused and broad

phase 5, looking into the project

## Current behavior

Phase 4's demo shows real turns without the look tool once 406 is done.

## Intended behavior

`issues/completed/demos/phase-5-demo`:

- asks the look tool one question at focus 1, 0.75, 0.5, 0.25 and 0 against
  guide-feature's own index, and shows, for each, the pieces returned and a
  chart of their similarity scores, so the shift from focused to broad can
  be seen;
- runs a few rehearsal rounds with real turns and shows each look call the
  models made: about what, at what focus, what came back;
- reports whether each voice's clone was in RAM or on disk.

## Suggested implementation steps

1. The run script and the chart.
2. Fill in `issues/phase-5-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 5

## Blocked by

503.

## Blocks

None.

## Decisions (2026-11-05; each the owner's to overturn)

1. **kuvalu's checkout is stood in for by guide-feature's own code**, copied
   into a one-commit monorepo (`kuvalu/ai-stuff/guide-feature`, as on
   kuvalu) in the throwaway folder, with its index built there by the
   builder (502). The voices clone from it and copy its index, as they
   will from kuvalu. The demo never builds or changes an index in the
   project it is run from.
2. **The five focuses are asked of the look tool directly**, with the same
   settings a turn uses (`input/look`): 4, 6, 8, 10 and 12 pieces. Each
   shows its pieces with a bar of their similarity, and a strip of where
   they sit among all the ranks, which shows the reach widening.
3. **The rehearsal's models look on a fixed rhythm**: each voice has its own
   stand-in chat model that looks focused at its first turn, broad at its
   second, not at its third, and so on, each voice about its own part of
   the project. A stand-in cannot choose what to look for; a real model
   will.
4. **The RAM tier is a tmpfs when one can be written** (`mktemp -d -p
   /dev/shm`), a plain folder otherwise, and the demo says which at the
   start. Nothing needs root.
5. **The demo's run line is the same as phase 4's**: `--minutes`, `--plain`,
   `--keep`, and `--about WORDS` for the question.

## What was built (2026-11-05)

- `issues/completed/demos/phase-5-demo` and `phase-5-demo.lua`; offered by
  `./run-phase-demo` as phase 5 with no change to it.
- `src/066-test-phase-5-demo.lua`: 21 checks against the programs' own
  logs, receipts and index.

## Needs the owner's machine

- The demo against kuvalu's servers and a real index: a real embedding
  model's similarities (the stand-in's count shared names, so many tie at
  0) and a real model choosing what to look for.
