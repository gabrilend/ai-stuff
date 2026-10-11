# 214 — The depth around the dashboard

**Phase:** 2 — Glass and metal
**Blocked by:** 209, 210
**Related documents:** docs/visual-language.md (The far camera),
assets/tilt-shift-style-design-part-1.2.png and part-2.2.png (the owner's
reference: a valley receding to mountains)

## Current Behavior

Three views are built (2026-10-10), waiting on the open questions below. The
hub camera (`src/003-the-far-camera.lua`) stands just above the hub (eye
height, look-down and field of view from `input/`) and aims along the chair;
under it the scroll wheel turns a whole quadrant a notch. Far ground, figures
and cuboids fade into a haze, which is also the sky (`src/013`). The focus
ring (`src/025-the-focus-ring.lua`) blurs by each pixel's ground distance
from the hub, worked out from the camera — an arc on screen. Figures stand
upright, or lean away from the hub (0.45 radians) to compare. The settings
menu has three painted toggles (view, standing, blur), and the starting
choices are in the settings file. Tests: under the hub camera a click finds
the ground point it was drawn at; the camera aims along the chair; nearer
ground is nearer in depth. Raising the hub camera straight up without
changing its aim (pictures 005 and 006 in development-history/) showed only
haze: its fixed look-down then aims past the map's edge. That led to the
slant view below. The slant view is built as described below and is where
the game now starts (settings: `view_depth = "slant"`, `slant_reach`);
the view toggle cycles flat, hub, slant; switching to slant switches the
size law (fold, shaders, and the ceramic engine at its next step). Tests:
the hub on the bottom row and the reach on the top row along the chair, a
far thing as tall on screen as a near one, nearer ground nearer in depth, a
click round trip, both size laws, and the C motion against its Lua twin
under both. Pictures 012 to 014.

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
- **The slant view** (the owner, after the raised-camera pictures: "expand
  the... longitude I think? to display more distance. Also, remember, the
  stuff that's displayed near the dashboard should be closer than the stuff
  that's near the top. But this means the stuff near the top just moves
  faster, but remains the same size relative to the part near the
  dashboard."). A third view: the hub sits at the bottom of the screen,
  behind the console, and the chair's quadrant runs up the screen to the
  map's edge at the top — the whole distance shown, not the few tiers the
  hub camera reaches before its haze. Nothing shrinks with distance: a
  figure at the top is the size of one by the dashboard (no perspective, and
  the sphere fold's shrinking of far things is switched off in this view).
  The fold itself stays: the outer tiers are still pressed together, so up
  there each step on screen covers more of the world — "the stuff near the
  top just moves faster" — and when the chair turns, the far ground sweeps
  past faster than the near, like the rim of a turning wheel. The scroll
  wheel turns a whole quadrant a notch, as under the hub camera. The focus
  ring, seen this way, is a semicircle around the console.
- **Haze**: far ground fades toward a hazy colour (hub camera only).
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
7. The slant view: a third word for the view setting ("slant") and a reach
   setting (world units from the hub, at the screen's bottom, to the top
   edge); its projection in `003` (the far camera's tilt and the chair's
   turn, no perspective, shifted so the hub is at the bottom row, zoomed so
   the reach fills the height) with Lua and shader twins and the click ray;
   a size law in the fold (`004`, shader twin, and the ceramic engine's twin
   in `020` with a setter through `022`/`023`) so sizes and carried or
   stacked heights stay full size while the slant view is on; the focus
   ring's distance for slant pixels; the menu's view toggle cycles flat →
   hub → slant; tests (hub at the bottom row, reach at the top, click round
   trip, sizes kept); pictures.

## Open questions

- "Moves faster" read as: the far tiers are pressed together on screen
  while figures keep their size, so near the top each step on screen is
  more of the world; and when the chair turns, the far ground sweeps faster.
  Is that the speed meant, or should figures near the top also visibly walk
  faster on screen than those by the dashboard?
- "Expand the longitude": built as showing from the hub out to the map's
  edge (the reach setting). Did it also mean more tiers in the world (the
  tiers shown setting, now 6)?

- What does "neither leaning toward nor away" look like when a villager
  stands at the left edge of the ring view? Built as: straight up in the
  world, seen at the camera's slant.
