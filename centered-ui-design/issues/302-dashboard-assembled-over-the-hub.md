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
flight dials.

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

## Open questions

- In the round world, are allies' arches arranged in a ring around the hub
  (one facing each quadrant), with the M seen as a straight row only because
  you see one section at a time? (Built as a ring-ordered row.)
