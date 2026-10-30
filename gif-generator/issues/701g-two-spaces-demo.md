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

## What Happened

Built 2026-10-30 on top of 701f. `./test-shape-films` is 315 of 315.

- **The mixed score (step 1).** `issues/completed/demos/phase-7/meeting.lua`:
  two moons circle a sign of glass, a gold cube passing in front of it and
  a violet icosahedron behind it. A rose ring is painted on the sign, a
  jade spark rides each moon across the picture through the cross-over
  landmark, a teal comet flies from one moon to the other on the front
  pane, and an ice sweep glows on the back pane. It passes the wall, and
  `src/054-two-spaces-test.lua` checks that it does.
- **The halves.** The two-space renderer takes a `show`: `"world"` films
  the shapes alone, `"light"` the panes' light alone (the shapes still
  hide and show it, but are not drawn). The tests prove the shapes' half is
  byte-identical to the score with its strokes and panes taken away, and
  that both halves together are the score as it always films.
- **The demo (step 2).** `issues/completed/demos/phase-7/run` films the
  score three ways and side by side (`meeting-side-by-side.gif`: the
  shapes, the light, both), prints each render's frames, bytes, palette
  seats lit and seconds per stage, gives every film a card, and counts the
  pool by tier from the cards (her library, when it's there, and the
  demo's own folder). With a display and LÖVE, it then opens the viewer
  on the demo's films; rate one with 1 to 5, close it, and the card is
  printed with the rating on its last line.
- **`./demo` (step 3).** It lists every `phase-*/run` it finds, so phase 7
  appears with no change to it.
- The films are kept beside the demo, as phase 5's are, so they can be
  watched without running anything.

Not tried here: the viewer step, since this machine has no display and no
LÖVE. Everything before it ran.
