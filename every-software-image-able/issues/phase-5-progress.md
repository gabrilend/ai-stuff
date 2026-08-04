# Phase 5 — The image

**Goal.** Something you can put on a card. A recipe saying what the seed is, a
board description saying what it runs on, neither naming the other, and the
tooling that turns them into bytes on a medium.

## Issues

| | | Status |
|---|---|---|
| `501` | The recipe and the board | **completed** — two descriptions that do not name each other, enforced by looking; six existing boards pass unchanged |
| `502` | Build the image | **reopened** — image, manifest and identity all correct; but the engine's bytes arrive as a parameter and the only caller that supplies one is a test passing two thousand copies of a letter |
| `503` | Put it on a card | **completed** — device and size both named and checked, every objection at once, written then read back then compared; pretend devices only, deliberately |

## Where the risk is

The seam between `502` and `102`. The builder decides where things go and the
engine decides where to look, and if they disagree the machine fails at the
earliest possible moment with the least possible information. That agreement
should be checked by the build rather than discovered at first light.

**It is checked, and both sides of the check have never both existed at
once** (noticed 2026-08-04). The builder compares the layout it is about to
write against the offsets the engine expects, and refuses to build on a
disagreement — which is exactly right, and has only ever been run against an
engine region filled with a placeholder.

So the risk named above is not retired. It is deferred to the moment `107`
produces real engine bytes, and that is the moment this check earns its
keep or fails to. An image built today is a card holding a waking routine, a
model, some text, some randomness, and a gap where the thing that thinks
goes.

`503` holds the only operation in this project that cannot be undone by writing
more software. The confirmation is awkward on purpose.

## Demo

One recipe, three board descriptions, three images built and verified — and the
same image written to several cards in one run, since one image is meant to serve
many machines.
