# Phase 1 — The engine

**Goal.** A model that thinks on bare hardware, with no operating system beneath
it. Weights in, tokens out, at a measured rate on a real board.

Nothing else in the project means anything until this works. A model that cannot
be run is a file.

## Issues

| | | Status |
|---|---|---|
| `101` | Package a model, whichever one | done — 10 of 10 round-trip checks |
| `102` | Find the weights without a filesystem | finding works on x86-64; memory map and ratchet remain |
| `103` | The arithmetic, in assembly | reference and fixture done, 7 of 7; the assembly itself not started |
| `104` | Sampling, and the carried seed | not started |
| `105` | The thinking loop, and its limits | not started |
| `105a` | The tokenizer | not started |
| `106` | Measure the engine | not started |

## Where the risk is

`103`. It is the largest single piece of work in the project, it is written in
assembly, and it will be written twice more in phase 4. The reference comparison
built alongside it is what makes the later ports tractable, so building that
fixture properly is worth more than it looks.

`105a` is the quiet one. A subtly wrong tokenizer does not fail — it produces a
model that seems mildly stupid, and nobody suspects the right thing for weeks.

## What is not decided here

Which model. That is a parameter of the build utility, chosen by whoever makes an
image, and this phase only has to be able to carry whichever one arrives.

## Demo

`106` produces it: tokens per second, bytes occupied, largest context, time from
power to first token, on whatever boards are to hand.
