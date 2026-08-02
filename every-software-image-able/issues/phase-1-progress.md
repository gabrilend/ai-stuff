# Phase 1 — The engine

**Goal.** A model that thinks on bare hardware, with no operating system beneath
it. Weights in, tokens out, at a measured rate on a real board.

Nothing else in the project means anything until this works. A model that cannot
be run is a file.

**The phase is complete on the first architecture, 2026-08-02.** Every piece of
a thinking machine — the packed model, the finding of it, the arithmetic, the
conducting, the sampler, the tokenizer, and the loop that closes them into one
machine — exists in assembly on x86-64, each half held to a readable twin with
no tolerance anywhere. The other two tongues are phase 4's whole purpose.

## Issues

| | | Status |
|---|---|---|
| `101` | Package a model, whichever one | **completed** — 10 of 10 round-trip checks, re-verified with the full suite before closing |
| `102` | Find the weights without a filesystem | **completed** — finding, memory map and ratchet on all three architectures, 27 of 27 against the host's arithmetic |
| `103` | The arithmetic, in assembly | **completed** — nine kernels bit-exact 37 of 37; the conducting in assembly too, 6 of 6; a whole thought is assembly end to end on x86-64 |
| `104` | Sampling, and the carried seed | **completed** — reference respecified to single precision and exact integers, 9 of 9; assembly agrees choice for choice over fifteen thousand draws, 8 of 8 |
| `105` | The thinking loop, and its limits | **completed** — the loop closed on the assembly engine, four stoppers named, cache reuse proven bit-exact, 13 of 13; the disk half of the atoms stays with `304` |
| `105a` | The tokenizer | **completed** — reference 21 of 21; assembly agrees on the whole awkward corpus, 17 of 17 |
| `106` | Measure the engine | **completed** — 1.36 G multiply-adds/s conducted end to end; three boards timed from power to their own memory report; results kept as data |

## Where the risk was, and what it turned out to be

`103` was named the largest single piece of work, and was. The reference
comparison built alongside it earned its keep twice over: composing the
kernels found a rounding defect in the *reference*, and the sampler's
respecification caught an integer generator that quietly was not one.

`105a` was named the quiet one. Its assembly half agrees with the readable
half across the whole awkward corpus, so the mild-stupidity failure now
requires both implementations to be wrong identically.

The risk nobody named: integration. Closing the loop caught a separator in
the context that belonged to no atom — each part correct alone, and the
machine they made subtly wrong together.

## What is not decided here

Which model. That is a parameter of the build utility, chosen by whoever makes an
image, and this phase only has to be able to carry whichever one arrives.

## Demo

`issues/completed/demos/phase-1-the-engine.sh`, chosen through `run-demo` at
the project root: what fits (`046`), how fast it thinks (`051`), and the
boards from power to speech (`063`). Numbers, not descriptions, and the
tools keep their results as data so none of them go stale in a document.
