# Phase 5 — The image

**Goal.** Something you can put on a card. A recipe saying what the seed is, a
board description saying what it runs on, neither naming the other, and the
tooling that turns them into bytes on a medium.

## Issues

| | | Status |
|---|---|---|
| `501` | The recipe and the board | **completed** — two descriptions that do not name each other, enforced by looking; six existing boards pass unchanged |
| `502` | Build the image | **reopened, and larger than the reopening said** — image, manifest and identity all correct, but the engine's bytes arrive as a parameter whose only caller is a test passing two thousand copies of a letter; and on 2026-08-08 the image turned out to carry no partition table and no filesystem, so no firmware can boot one |
| `503` | Put it on a card | **completed** — device and size both named and checked, every objection at once, written then read back then compared; pretend devices only, deliberately |

## Where the risk is

**It was named as the wrong seam, and that is the lesson of 2026-08-08.**

The seam watched here was between `502` and `102`: the builder decides where
things go, the engine decides where to look, and a disagreement fails at the
earliest moment with the least information. That check was written, is correct,
and both sides of it were always right.

**The seam nobody named was between the builder and the firmware.** A built image
carries five regions at block boundaries and no partition table, no filesystem
and no file — and firmware opens *one file on a FAT filesystem*, not a medium.
So no image this phase has ever produced could be booted by anything, and the
check that would have caught it is the one nobody wrote: build an image, then ask
a firmware to open it.

Two things hid it. The check that existed compared the builder against the
*engine*, and the engine is not what has to find the first byte. And the emulated
boards boot from a host directory the emulator synthesises into a filesystem
(`018`), so the built image was never the thing under test — the road that proved
first light and the road a card takes were never the same road.

**The general form is worth more than the fix.** A seam is only checked if
somebody named both sides of it, and the side that goes unnamed is the one facing
outward — toward the firmware, the medium, the machine somebody else built. Two
components of ours agreeing is the easy half.

The original seam below is not retired; it is still waiting on real engine bytes.

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
