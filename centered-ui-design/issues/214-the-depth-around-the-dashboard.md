# 214 — The depth around the dashboard

**Phase:** 2 — Glass and metal
**Blocked by:** 209, 210
**Related documents:** docs/visual-language.md (The far camera),
assets/tilt-shift-style-design-part-1.2.png and part-2.2.png (the owner's
reference: a valley receding to mountains)

## Current Behavior

Built (2026-10-10), waiting on its open question. The hub camera
(`src/003-the-far-camera.lua`) stands just above the hub (eye height, look-
down and field of view from `input/`) and aims along the chair; under it the
scroll wheel turns a whole quadrant a notch. Far ground, figures and cuboids
fade into a haze, which is also the sky (`src/013`). The focus ring
(`src/025-the-focus-ring.lua`) blurs by each pixel's ground distance from
the hub, worked out from the camera — an arc on screen. Figures stand
upright, or lean away from the hub (0.45 radians) to compare. The settings
menu has three painted toggles (HUB VIEW / FLAT VIEW, UPRIGHT / OUTWARD,
BLUR ON / BLUR OFF), and the starting choices are in the settings file.
Tests: under the hub camera a click finds the ground point it was drawn at;
the camera aims along the chair; nearer ground is nearer in depth. The
owner then asked to try raising the camera straight up without changing its
aim (pictures in development-history/).

## Intended Behavior

The owner brought pictures of a tilt-shift look — a valley seen from high
up, the near ground large, the far end shrinking toward mountains, little
pieces on it like a model — "instead of giant robots ... little individuals
running about and performing medieval village duties", and: "the input
image is not curved around the dashboard as the final result should be, it
is just the depth effect applied down one scenery."

- **The camera at the hub, aimed outward one colour at a time.** The owner:
  "position the camera at the origin of the graph shape drawn on the ground.
  Then, aim it outward at one color at a time." A true perspective camera
  stands just above the hub and looks out and down across one quadrant —
  the valley of the reference pictures, its far end the foe's tiers. Each
  notch of the scroll wheel turns it to the next colour (eased), so the
  depth goes all the way round the dashboard, one valley at a time. The far,
  flat view stays as the other choice to compare.
- **Haze**: far ground fades toward a hazy colour.
- **Focus blur, in a ring**: "if you apply blurring ... apply it in a
  semicircle around a radius zone" — sharp within a band of distance from the
  hub, blurring nearer and farther; seen from the hub camera, ground at one
  distance is an arc, so the sharp zone is a semicircle on screen. Optional: "if you have lots of visible
  spaces, it can fake the tilt-shift without blurring."
- **Standing**: villagers stand straight up on their own ground — "neither
  leaning toward nor away". For comparison, a second way: leaning outward
  from the hub (the owner wanted to see both).
- **Compare everything**: the flat view and the ring perspective, blur on
  and off, the two ways of standing — switched by painted buttons in the
  settings menu, and set at start from input/game-settings.lua.

## Suggested Implementation Steps

1. The ring perspective as a mapping of each object's place (ground
   distance -> screen distance and size), in the world shaders; flat view
   kept as it is.
2. Haze in the world shaders by perspective depth.
3. The focus ring: a full-screen pass over the world picture, blurring by
   distance from the focus radius.
4. Standing modes in the unit and cuboid shaders.
5. Settings: three words in the settings file; three buttons in the menu.
6. Pictures of every combination in development-history/.

## Open questions

- What does "neither leaning toward nor away" look like when a villager
  stands at the left edge of the ring view? Built as: straight up in the
  world, seen at the camera's slant.
