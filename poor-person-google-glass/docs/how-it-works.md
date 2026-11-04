<!-- Made by Claude (Opus 5.5), 2026-10-10, from notes/vision, during project initialisation, so the vision's parts have agreed names and a checked design. -->
# How it works

A head-worn projector with no camera and no lens. Light is shaped by moving
parts inside a liquid-filled light pipe and thrown outward onto a small
curved panel the wearer holds in front of their face on an arm. The wearer's
own inputs decide what is shown; nothing watches the eye.

## The three flows

1. **Light** (docs/datapath-light.md). Emitters at the back of the crown send
   light down the light pipe. Tabs swing into the pipe; their open slots,
   overlapping, form the mask. Light that meets a closed slot is turned aside
   into the store, a mirrored rotating cylinder, where it circulates. The
   store's aperture lets light out in releases; each release carries the
   mask's picture outward to the panel.
2. **Decisions** (docs/datapath-input.md). Dials, buttons, the pocket stick
   and the cuff produce input decisions. Decisions choose what is shown,
   which sets the tabs; and they move the panel arm, which changes where and
   how large the picture lands.
3. **Heat** (docs/datapath-heat.md). Emitters, the store's walls and the tab
   motors warm up. Releases are intermittent; air pumps move air; heat fins
   flare out from the hair when hot.

## What changes and how fast

A still picture costs only light: the tabs hold their places and the store
keeps releasing. A new picture costs motion: the tabs re-adjust, which takes
on the order of a second with the first mechanism — "the faster, the more
responsive. room for mechanical improvement." That makes this a display for
pages, glyphs and slow scenes first, and the tab speed is the main number to
improve.

## Where it sits among real devices

See docs/physics-check.md for each part set against known physics.
