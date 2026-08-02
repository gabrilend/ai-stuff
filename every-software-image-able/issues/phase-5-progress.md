# Phase 5 — The image

**Goal.** Something you can put on a card. A recipe saying what the seed is, a
board description saying what it runs on, neither naming the other, and the
tooling that turns them into bytes on a medium.

## Issues

| | | Status |
|---|---|---|
| `501` | The recipe and the board | not started |
| `502` | Build the image | not started |
| `503` | Put it on a card | not started |

## Where the risk is

The seam between `502` and `102`. The builder decides where things go and the
engine decides where to look, and if they disagree the machine fails at the
earliest possible moment with the least possible information. That agreement
should be checked by the build rather than discovered at first light.

`503` holds the only operation in this project that cannot be undone by writing
more software. The confirmation is awkward on purpose.

## Demo

One recipe, three board descriptions, three images built and verified — and the
same image written to several cards in one run, since one image is meant to serve
many machines.
