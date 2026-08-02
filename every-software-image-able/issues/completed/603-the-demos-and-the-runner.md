# 603 — The demos, and the thing that runs them

## Current behavior

**Done for every phase that is finished** — five demonstrations in
`issues/completed/demos/`, and `run-demo` at the project root, on 2026-08-02.

Each shows numbers rather than descriptions:

| | what it shows |
|---|---|
| phase 1 | what a thinking machine costs, tokens per second measured four ways, and three boards timed from power to their own memory report |
| phase 2 | a live exchange on the real engine, a program written and run on this processor, the reach into memory and storage and hardware with its refusals, and a sentence drawn into real firmware's framebuffer checked pixel by pixel |
| phase 3 | how much is carried, how little is held at boot, and what fetching one piece costs — with the room left over stated as a fraction |
| phase 5 | one recipe built for every board described, side by side, with their identities |
| phase 7 | a bench of parts that can really be destroyed, and the same machine explored with the discipline held and broken |

**Each uses what earlier phases built in ways those phases were not for.**
The phase 5 demonstration reads the rate phase 1 measured out of the file the
measuring tool wrote, and says what a real model would manage at that rate —
so it cannot go stale while claiming not to. The phase 3 demonstration counts
its payload against the context budget phase 1 established.

The runner lists what exists, takes a number, and passes anything after it to
the demonstration — so the slow ones can be told to skip their boots. What
each demonstration is about is read out of that demonstration's own opening
comment rather than kept in a second list inside the runner, which would
drift the first time one of them changed.

**A number this surfaced rather than reported.** At a two-thousand-token
budget the boot set leaves the machine thirty-six percent of its room to
think in. That is tight, it is the kind of thing a table of features would
never have shown, and it is exactly the argument for `304` being a separate
ticket from `301`.

Phases 4 and 6 have no demonstration because they are not finished. The
runner lists what exists rather than what is planned, so they appear when
they do.

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
