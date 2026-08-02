# 603 — The demos, and the thing that runs them

## Current behavior

No phase has a demo and there is nothing in the project root to run one.

## Intended behavior

One demo per completed phase, in `issues/completed/demos/`, and a script in the
project root that asks which phase to show and runs it. They are part of the
deliverable rather than a development artifact, so they are kept working as the
project moves.

## Suggested implementation steps

1. Write each demo to show **numbers**, not descriptions. Tokens per second on the
   board in front of you beats a paragraph about the engine. Bytes per
   architecture beats a claim of portability. Time from power to first token beats
   both.
2. Have each demo use what earlier phases built, in a way those phases were not
   specifically for. The phase 4 demo running the phase 1 measurement across three
   architectures at once is worth more than three separate measurements.
3. Show something visible where it is possible. A serial console scrolling the
   machine's own narration of its startup is a demonstration; a table of results
   is a report.
4. Write the runner in the project root: ask for a number between one and however
   many phases are finished, then run that phase's demo. It should work from any
   directory, with the project location fixed at the top of the script and
   overridable by an argument.
5. Update the demos when the thing they demonstrate changes. A demo that no longer
   runs is worse than no demo, because it claims the project is further along than
   it is.

## Blocks

Nothing.

## Blocked by

Each phase's demo is blocked by that phase. The runner itself is blocked by
nothing and can exist from the first completed phase.

## Related documents

`docs/011-roadmap.md` — demos as deliverable rather than artifact.
