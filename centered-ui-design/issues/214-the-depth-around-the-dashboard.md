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
under both. Pictures 012 to 014. Haulers walk on the sphere (step 8,
pictures 015-016). The arch view (step 9) is built and is now where the
game starts (`view_depth = "arch"`, `arch_reach`); neighbours' quadrants
grow from their own arches, and the quadrant across (never visible) is sent
below the screen so its wrapping angle cannot tear the ground (pictures
017-019, 018 showing the tear). The magic circles (step 10) then replaced
the neighbours' arches: one arch spans `arch_span_degrees` (450 to start)
foot to foot, the world drawn once per winding, the ground by its mesh's
own unbroken angle (pictures 025-027 at 450, 360, 720). The view dials
(step 11) are built: A with the wheel sets the reach, S the span, shown on
two console dials (pictures 036-041). The painted terrain (step 12) is
built: splotches all one size, as many to every stretch of ring, painted
far to near (pictures 042-049); the blur is now off by default.

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
- **The arch view** (the owner: "if you project the arc of the
  circumference of the circle you're rendering with a 2d texture plane, and
  then projected onto that... it might be easier to match the world's
  scaling to the curve of the dashboard"; asked to choose, the owner chose
  moving the points rather than wrapping a picture). A fourth view: every
  tier ring is drawn as a scaled copy of the arch's outer curve, grown
  outward from the console — tier 0 on the arch itself, the map's edge near
  the top of the screen, the fold pressing the far rings together. Along
  each ring runs the chair's quadrant from foot to foot exactly as along the
  band, so the band's painted map and the open world line up angle for
  angle. Each figure and cuboid is moved to its spot on its ring and drawn
  there upright, the same size everywhere; outer rings are longer, so far
  figures cross the screen sideways faster. The owner's picture of it:

  > picture a king in a castle walking along the battlements viewing all
  > the surrounds. if you walk to the east wall, you'll have a different
  > perspective of north and south than if you walked to the west wall.
  > Just like how when it's one time of year, we can see a certain
  > perspective of celestial objects, and when it's another time of year we
  > can see another angle.

  The arch is the wall; turning the chair is walking along it.
- **Magic circles: more than 360 degrees** (the owner: "can you try having
  much more than just 90 degrees? Like what if our circles were magic
  circles that had more than 360 degrees of rotation. Like, if the
  rotational axis was just... bigger. I think that'll help us fit the more
  correct displays on screen."). One arch's rings carry a wide span of
  angle foot to foot — a setting, and it may pass 360 degrees: then the
  circle runs on past itself, the same ground showing at both ends (the far
  side of the world at both lower corners at once). This takes the place of
  growing each neighbour's quadrant from the neighbour's own arch (which
  left seams where two families of rings overlapped).
- **Two view dials, turned by key and wheel** (the owner: "can we have a
  dial that the user can adjust with holding the modifier key listed next
  to it and scrolling that dynamically adjusts the speed of the distant
  units? Correspondingly, what does that modify? The view distance. I think
  A is a good letter to hold down while we scroll. Then, for S, can you
  increase/decrease the FoV that the user has? We should be able to see
  more/less of the dashboard by squeezing more units in from the side. With
  these two designs, I think we can fully customize how we want to
  view."). Holding A while scrolling changes the arch view's reach (how far
  out the top of the screen sees): reaching farther presses the far rings
  together, so distant units cross the screen more slowly; nearer, faster.
  Holding S while scrolling changes the arch's span (its field of view):
  more degrees squeeze more of the world in from the sides. Each has a
  small dial on the console, its key engraved beside it, showing the value
  (tiers reached; degrees). The plain wheel still turns the chair. The
  dials are still never clicked: the game turns them, the keys only ask.
- **Painted terrain, to test distance** (the owner: "can we make some
  "terrain" that's just different colors painted in splotches on the
  ground? To test the rendering at different distances. Remember, each
  "spot" (overlapping) is just a circle drawn with closer circles drawn
  on-top. It should still be partially visible, just enough to draw a part
  of the texture map. Then, we can automatically rotate the circles along
  the axis with the raycast to the camera, and rotate it just precisely
  enough to curve a little bit of the surface we're trying to model.
  Usually one side of the circle is bright, and one is darker." — and then:
  "um ok"). Splotches of earthy colour scattered over the ground, as many
  per ring near as far; each a disc lying on the ground, overlapping its
  neighbours, nearer ones drawn over farther ones; each tipped a little
  toward the camera about its sideways line and domed slightly, so it reads
  as a small rise; lit brighter on the side toward the hour's light and
  darker on the other, the bright side moving with the day. Then the
  owner: "all of the circles should be the same size, and there should be
  an even amount of them per "x" distance (around the central
  dashboard(s) but it should increase as it goes deeper. Meaning, at any
  particular length, there's N circles." — and "can we remove the
  blurring effect I think it's clearer without it."
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

8. Walking on the sphere (the owner's answer to the first question below:
   far figures should visibly move faster left-right, "closer / farther is
   always just dense"). The haulers' steering in the ceramic engine measures
   pace on the sphere instead of on the folded ground: a far pole setting
   (the foes' pole, just past the tiers shown), a lap radius
   (far pole / pi x sin(pi r / far pole), Lua and C twins), steering by
   outward tiers and sideways sphere distance at a steady tiers-per-second
   pace, reach and section arrival in tiers. The simulation is then the same
   under every view (the size law only touches drawing). Tests: the twins
   agree; sideways screen speed per step grows outward while outward screen
   speed shrinks; cuboids still delivered.

9. The arch view: a fourth view word ("arch") and a reach setting (world
   units from the hub, on the arch's outer curve, to the top of the
   screen); the camera learns the arch's size in pixels from the console;
   in `003`, the warp (ground point -> ring by its folded radius, place on
   the ring by its angle from the chair, foot to foot as the band does,
   continuing down past the feet off screen), its inverse for clicks, and an
   anchored projection for the shaders: a figure's or cuboid's anchor is
   warped and its own shape is laid on the ring's local direction at one
   scale; the ground mesh is warped point by point. The size law keeps full
   size in this view too. The focus ring finds a pixel's ring by solving
   for the scaled curve through it. Tests: tier 0 at the apex lands on the
   arch's outer curve; a point at the quadrant's edge lands on the foot;
   click round trip; a figure is as tall at the top as near the arch;
   sideways screen distance per radian grows outward.

10. Magic circles: a span setting (degrees foot to foot); the warp's
    angle is measured from the chair and laid as span (no neighbour-arch
    families); the world is drawn once per winding (the same ground offset
    by whole turns) so spans past 360 show it more than once; the ground
    mesh keeps its own unbroken angles so no ground piece ever straddles a
    wrap; ground beyond the span's feet is sent below the screen. Tests:
    the span's ends land on the feet; with a span past 360 one ground point
    appears at two places; click round trip. Pictures at several spans.

11. The view dials: wheel with A held changes the reach, with S held the
    span, each a tenth per notch within limits; the camera's arch scales
    recomputed from the reach; two dials and their engraved keys on the
    console; a scripted "wheel with a key held" option for pictures; tests
    of the limits and that a farther reach makes far rings tighter.

12. Painted terrain: seeding the splotches (`007`: place by tier distance
    and angle, size, colour from an earthy palette, from the seed; count
    from `terrain_splotch_count` in the settings, 0 for none); drawing them
    (`013`: one instanced disc, anchored like figures so the arch view lays
    it on its ring, tipped toward the camera and domed, shaded bright to
    dark across by the hour); tests that the seeding is the same for the
    same seed and spread evenly by tier; pictures at noon, dusk, far and
    near.

## Open questions

- Answered: figures near the top should visibly move faster left-right;
  toward and away stays dense (step 8). The owner: "otherwise we won't be
  able to simulate the other kingdoms that our kingdom of 4 is fighting.
  It's one across from each other on all four, but how else do you represent
  that except two (or more) poles on a sphere? well, instead of the units
  bending away from you, as if they were on the horizon sphere curving
  away... but also not curving toward you, as if you were both inside of a
  sphere's surface, but rather, just directly away, at the exact plane where
  they are not bent one way or the other, rather, simply perfect to you."
- Which span feels right? 450 shows three quadrants whole; 720 all four,
  the one across from ours at both edges.
- The arch view's figures are smaller than the slant view's (the whole
  hub-to-edge distance fits in the half screen above the apex), and fewer
  are on screen (mostly our own quadrant). Is that the right trade, or
  should the arch view reach less far (bigger figures, fewer tiers in
  view)?
- Where is the far pole? Built as one tier past the tiers shown (just
  beyond the map's edge). Should it be at the edge itself, or further?
- "Expand the longitude": built as showing from the hub out to the map's
  edge (the reach setting). Did it also mean more tiers in the world (the
  tiers shown setting, now 6)?

- What does "neither leaning toward nor away" look like when a villager
  stands at the left edge of the ring view? Built as: straight up in the
  world, seen at the camera's slant.
