# 302 — The console: an arch over the hub

**Phase:** 3 — The wheel at the center
**Blocked by:** 205, 206, 207, 301
**Blocks**: 303, 306, 307, 501
**Related documents:** docs/console-layout.md, docs/game-design.md (The
screen)

## Current Behavior

Built (2026-10-10), waiting on its one open question. The console is an arch
(`src/019-the-arch.lua`) standing on the window's bottom pixel row and
stretched to both sides (`arch_height_share` in `input/`, 0.5). Its band
carries the map painted from far beyond (`src/024`), the ally's quadrant
unrolled along it. Beneath it, the surface holds the calendar, three
readouts, four section counts, the named slot, two columns of order buttons,
and (in the settings menu) the framerate cap and the three look toggles —
laid out as data in arch units (`src/014`). The allies' arches form a ring-
ordered row that slides with the chair; with the arch full width, only your
own is on screen until the chair turns. Tests: surface and band never
overlap; every button and window lies wholly on the surface; a neighbour's
foot lands exactly on yours. Not built yet: the resource and couriers-in-
flight dials. The metal's second pass is built (pictures 020-024): brushed
along the arch, lit by the metal dial over a panel lamp (added when the
night picture's labels could not be read), sheen and hour highlight. The
console is now 40% of its old area (a fifth of the window high), laid out
in rows; lettering is sized by the window; the calendar's rings take their
radii from their windows; tests check that nothing shown together overlaps,
labels included (pictures 028-031, the first two showing what broke). The
console spins by hand: a press on its metal drags the chair, letting go
settles it on the nearest seat, and every arch in view is drawn whole with
its own buttons and dials (pictures 032-033). A press let go outside the
window used to leave the console held, so any later mouse move spun it;
it now lets go as soon as a move arrives without the button. Spinning now
carries the console along the arch's curves, as the map does (step 10;
pictures 080-081). The metal flashed as the day turned (fine streaks on its
light dial swept past); the streaks are gone and a test checks the light
changes steadily.

## Intended Behavior

The owner's picture: "half of the M in the McDonald's golden arch" — one
arch.

- **Placed at the bottom, full width.** The owner: "position the bottom of
  the dashboard at the bottom pixel row of the screen" and "width-enhance
  the dashboard to meet the edge of the screen on the left-and-right." The
  arch stands on the window's bottom edge and is stretched to touch both
  sides; its dials and buttons keep their places in arch units.
- The console in the middle of the screen is an **arch**: a tall curved band
  rising from two feet on a flat base, like one hump of an M.
- **The arch's band is the display of the map** — "through. Not through its
  opening, but painted onto its surface from some distant beyond." The band
  is not a window onto what lies behind it: the map is painted onto the
  band's surface, as seen from far beyond, straight down. Each arch paints its
  own ally's quadrant unrolled along it: from left foot to right foot runs
  the quadrant's angle; from the band's inner edge to its outer edge runs the
  distance from the hub out to the farthest tier. Units and cuboids show on
  it as they move.
- **The part beneath the arch's curve and above its base is the dashboard
  surface**: brushed metal holding the painted order buttons and the dials
  (calendar, readouts, who the next order goes to).
- **Allies make it an M.** With several stand-ins the whole console is one
  arch per ally, side by side, sharing their feet — an M with as many humps
  as there are allies, all the way round (seats form a ring). **You see only
  your own arch and the very edge of your allies'.** The console grows to hold
  every ally while each section stays the same size.
- **Rotating your chair**: scrolling turns your chair around the hub. The map
  turns with you and the row of arches slides by, so you can look along to
  an ally's arch and quadrant to see what they are up to; scroll back to
  return. Only your own arch's buttons answer; an ally's are shown, dimmed.
- Only buttons answer clicks; the band and the dials are information.

- **Spun by hand, every arch whole** (the owner: "can you make it so the
  user can spin the dashboard by clicking and dragging? it should show the
  other player's buttons too. the arc that it has now is the exact same arc
  that it should have when the other player's orbit past."). Pressing on
  the console's metal (not on a button) and dragging sideways turns the
  chair with the hand — the row of arches and the world slide together, one
  arch's spacing of drag for one seat's quadrant — and on letting go the
  chair eases to the nearest seat. (With arches as wide as the screen,
  "nearest" needed a drag of half the screen, so ordinary drags slid back
  and the owner found dragging did not work: now, like a carousel, a drag
  of more than a sixth of an arch carries on to the next seat in its
  direction.) Every arch that passes is drawn exactly
  as yours, the same shape and brightness, with its own buttons, dials and
  labels; its named slot says whose seat it is.
- **Spinning along the curve, as the map does** (the owner: "when we swap
  in the neighbor graph dashboard and viewpoint, we're forgetting to curve
  it around the arc of the dashboard. We're just sliding in from the
  left/right and spinning the UI - what we want to do is slide it along
  the curved texture, same as the map."). The seats' consoles sit round a
  curve like the world's quadrants: spinning carries each seat's buttons,
  dials and band along the arch's own curves — your seat slides down and
  away past one foot as the next rises in over the other — half a turn of
  the curve per seat. The console is drawn once, in place, and the sheet
  that shows it reads each screen pixel from its place on the curve moved
  by the spin (the arch view's warp); clicks go back through the same warp.
  Each seat's band shows its own quadrant.
- **Forty per cent of the surface** (the owner: "can you make it so
  there's like, 40% as much dashboard in total square footage surface area
  as there is now?"). The arch's area is two thirds of width x height; the
  width stays pinned to the window's edges, so the height drops to 40%: a
  fifth of the window's height instead of a half, the arch about eight times
  wider than tall. Buttons, dials and lettering keep their size on screen
  (lettering is sized by the window, not the arch), so the surface is laid
  out again in rows across its width: the calendar in the middle, the
  readouts to its left, the section counts to its right, the order buttons
  in a row of four at each end, the named slot beneath the calendar.
- **The metal, seen at the camera's slant** (the owner, after the arch
  view: "there's a pretty intense reflection on the surface of the
  dashboard ... we have since moved the camera so now it looks weird at
  this angle"). The surface was brushed in circles round the calendar with
  two fixed glints, like a watch face seen head-on; seen across like a desk
  it read as a spinning spotlight. Second pass: the brushing runs parallel
  to the arch (fine streaks along scaled copies of its curve, the world's
  rings carried on inward across the metal); the metal is lit by the metal
  light dial at the spot an upward surface sees from the camera's slant,
  like every world surface, so it dims at dusk and turns blue at night; a
  soft sky-coloured sheen grows toward the far edge beneath the band (a
  surface seen at a grazing angle reflects most there); and one faint
  highlight across the streaks slides along the arch with the hour.

## Suggested Implementation Steps

1. Arch geometry: outer and inner curves of the band, the interior, as
   functions of a section's width, height and band thickness; hit tests.
2. Lay the dashboard out in arch coordinates (across from the center, up
   from the base) as a data table.
3. The band's paint: a picture of the map from straight above (the flat map
   with units and cuboids as marks), and per band pixel its place along and
   across the band, so the sheet's shader can look up the map at that
   quadrant angle and tier.
4. The M: every ally's arch in a ring-ordered row; a clip that shows your
   own and only a sliver of the next.
5. The chair: a turn angle eased toward where the scroll wheel leaves it; it
   turns the map and slides the row.
6. Tests: the arch's interior and band never overlap; every button lies
   inside the interior; the band's paint maps its feet to the quadrant's
   edges and its outer edge to the farthest tier.

7. The metal's second pass: the brushing, the dial light (a Lua twin of
   the world shaders' dial lookup in `012`, so the game can hand the
   console its light each frame), the sheen and the hour's highlight in
   the metal shader (`014`); a test that the twin matches the dial
   painter at the same spot; pictures at noon, dusk and night.

8. Forty per cent: `arch_height_share` 0.5 -> 0.2 (balance log); the
   lettering sized by the window's height; the layout data in `014` laid
   out again for the wide, low arch at the old pixel sizes; a test that no
   two buttons or windows shown together overlap; pictures, orders and
   settings.

9. Spinning by hand: the game follows a press on the console that is not
   on a button as a drag (mouse moved and released handlers, routed from
   `main.lua`; a scripted drag option for pictures); the chair follows the
   drag and snaps to the nearest seat on release; the console draws every
   visible arch's face and dials in one way (the old dim allies' drawing
   removed); allies' buttons are drawn but do not answer (see the open
   questions); pictures mid-drag and settled on a neighbour.

10. Spinning along the curve: the sheet's shader (015) finds each pixel's
    arch-shaped ring and angle, moves the angle by the spin (half a turn of
    the curve per seat), and reads the console there, with the seat that
    angle falls in shifting the band's quadrant; the console is drawn once
    at home (014: the row of sliding arches retired); a Lua twin of the
    warp (014, unwarp) sends clicks to the home layout, the front seat's
    buttons answering. Tests: no spin is no change; half a seat's spin
    carries the apex to the next seat's foot. Pictures mid-spin.

- Neighbours' consoles are drawn from the front seat's own console (the
  same dials, the front seat's named slot); only their bands show their own
  quadrants. Should each seat's console show its own state as it comes
  round?

## Open questions

- In the round world, are allies' arches arranged in a ring around the hub
  (one facing each quadrant), with the M seen as a straight row only because
  you see one section at a time? (Built as a ring-ordered row.)
- When an ally's arch is spun to the front, should its buttons answer —
  playing that seat (hot-seat, issue 501) — or only ever your own seat's?
  Built for now: drawn, but only your own seat's answer.
- While spinning, a dark wedge shows between two arches' feet (inside the
  arch's curve is the hub, which has no ground drawn). Should the hub show
  there — the castle's own courtyard — or should the world's rings slide
  with the arches?
- Spinning carries each part of the console along its own arch-shaped
  track, upright, stretching with the curve, like a belt — as the map does.
  A rigid wheel (each seat's panel rotating as it travels, tipped at the
  feet) would look different (see-in-3d model kept in mind/). Which is it?
