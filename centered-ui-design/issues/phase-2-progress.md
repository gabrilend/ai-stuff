# Phase 2 Progress — Glass and metal

## Goals
The rendering kit with no game in it: palette tokens from dark to bright;
brushed-metal and glass-refraction shaders; circles, rings, arcs,
half-circles and text along arcs; dials turned only by the game, seen
through seamless glass; nested dials; readouts that roll like odometers;
bright buttons; the far camera; small 3D models; formula voxel effects.

The demo this phase ends with is described in docs/roadmap.md.

For current done/open counts, run:

    /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/centered-ui-design -m

## Completed Issues
- 210 — Units as figures: six spheroids (body, head, arms, legs) in one mesh,
  limbs bent by a formula fed each unit's walking phase, drawn per unit on the
  graphics card from the shared-memory records, code-drawn skin, specular
  metal glint.
- 212 — The dashboard on a view plane: face, dials and glass laid on a sheet
  in the 3D scene that exactly fills the far camera's view; the flat map
  folded onto the ground. The first look of the whole game.
