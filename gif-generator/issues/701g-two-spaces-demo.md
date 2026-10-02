# 701g — two spaces demo (capstone)

Part of 701. Depends on: 701d, 701e, 701f.

## Current Behavior

Phase demos exist for phases 1 to 5 under `issues/completed/demos/`, chosen
from by `./demo`. None shows a 3D shape, and none mixes the two painters.

## Intended Behavior

A phase 7 demo, runnable from `./demo`, that shows rather than tells:

- one mixed score rendered live: a 3D shape moving in world space with a
  2D stroke of light following it on screen through the cross-over landmark;
- the same score's 2D-only and 3D-only halves rendered beside it, so the
  composition is visible;
- the statistics each render already reports (frames, bytes, palette seats
  lit, seconds per stage), and the pool's count per tier;
- opened in the viewer, where a rating can be given and is seen landing on
  the card.

## Suggested Implementation Steps

1. Write the mixed score; prove it passes the wall.
2. Write `issues/completed/demos/phase-7/run`.
3. Add phase 7 to `./demo`'s list.
