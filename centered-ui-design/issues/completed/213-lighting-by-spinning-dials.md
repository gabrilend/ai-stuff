# 213 — Lighting by spinning dials

**Phase:** 2 — Glass and metal
**Blocked by:** 201, 209
**Completed:** 2026-10-10
**Related documents:** docs/visual-language.md, assets/ (the owner's
reference pictures)

## Current Behavior

Built (2026-10-10). Three light dials — metal (fine streaks, a firm
highlight ring), glaze (smooth, a sharp ring and a soft sheen), earth (broad,
matte) — are painted by formula at start (`src/012-made-by-formula.lua`:
`light_at`, `light_dial`): noon warm white at the top, dusk and dawn orange
at the sides, night deep blue at the bottom, brighter toward the rim. Every
world shader (`src/013`) turns its surface's facing into the viewer's terms
(`view_facing`, `src/003`) and looks its light up through a window set off
the dial's centre (centre 0.52, radius 0.44 of the dial): facing up looks
toward the bright rim, facing sideways toward earlier or later hours. The
dials turn one full turn per calendar day (24 seconds), starting mid-morning,
so noon, dusk, night and dawn pass over everything — no skybox, no change of
view. The figures' panels use the metal dial; their bands and the cuboids,
the glaze dial tinted with their colour; the ground, the earth dial. Tests:
every dial is brighter at noon than at dusk and at dusk than at midnight; the
window never reaches past the rim. The old fixed light (a diffuse term and a
Blinn-Phong glint) is gone.

## Intended Behavior

The owner: "paint the background with positioned circle textures, at an
angle corresponding to the texture of the object ... rotate them alongside
the skybox as it rotates from day to night. the texture is a circle
projected onto a circle face, and it spins like a dial on a clock. the idea
is to represent lighting as reflections or texture changes on part.
different circle image for a different material, or sometimes just color
change." And: "we don't have to show a skybox at all if we just change how
the light reflects and we don't change our perspective."

- **One light dial per material** (metal, glaze, earth): a round picture
  painted by formula — never AI art — whose rim is a clock of the day: noon
  at the top (warm white), dusk and dawn at the sides (orange), night at the
  bottom (deep blue), brighter toward the outer edge (light from above),
  with a sharp highlight ring for shiny materials and fine streaks for
  brushed metal.
- **Every surface looks up its light through a window onto its material's
  dial**: a circle set off the dial's centre, like a watch's date window.
  Where in the window a surface looks depends on which way it faces the
  viewer — facing up looks toward the dial's bright outer edge, facing
  sideways looks toward earlier or later in the day.
- **The dial spins with the time of day** (one turn per calendar day), so
  noon, dusk, night and dawn pass under every window and the whole world's
  light changes — no skybox, no change of view.
- **Colours of one material are tints**: the owner band and the cuboids
  share the glaze dial, tinted; the ground shares the earth dial.

## Suggested Implementation Steps

1. The dial painter: one function per material in 012, returning image data.
2. The window lookup in the unit, cuboid and ground shaders, with the
   surface's facing turned into the viewer's terms.
3. The time of day from the calendar, sent as the dial's turn.
4. Tests: the painted dial is brightest at noon's side and darkest at
   night's; the window's lookup stays inside the dial for every facing.
