# 302 — The console: an arch over the hub

**Phase:** 3 — The wheel at the center
**Blocked by:** 205, 206, 207, 301
**Blocks**: 303, 306, 307, 501
**Related documents:** docs/console-layout.md, docs/game-design.md (The
screen)

## Current Behavior

Built (2026-10-10), waiting on its open questions. The console is an arch
(`src/019-the-arch.lua`: parabolic outer and inner curves meeting the base at
the feet) centered on the screen, 74% of the window's height. Its band is
gold-edged glass through which the finished world picture is seen, bent like
a lens (`src/015-the-view-plane.lua`, now drawn after the world). Beneath it,
the brushed-metal surface holds the calendar (month and weekday arc windows,
the day-number hole one disc lower), three readouts, the named slot, and two
columns of order buttons — laid out as data in arch units
(`src/014-the-dashboard.lua`). With `team_size` above 1 (from `input/`),
the neighbours' arches show at the sides sharing your feet, dimmer, labelled
with their seats (a ring: seat 1 sits between seats 4 and 2); with 1, no
neighbours. Tests: surface and band never overlap; every button and window
lies wholly on the surface; a neighbour's foot lands exactly on yours. Not
built yet: the resource and couriers-in-flight dials.

## Intended Behavior

The owner's picture: "half of the M in the McDonald's golden arch" — one
arch.

- The console in the middle of the screen is an **arch**: a tall curved band
  rising from two feet on a flat base, like one hump of an M.
- **The arch's band is the display of the map**: a band of glass through
  which the world map is seen, bent slightly as through a lens, edged in
  gold.
- **The part beneath the arch's curve and above its base is the dashboard
  surface**: brushed metal holding the painted order buttons and the dials
  (calendar, readouts, who the next order goes to).
- **Allies make it an M.** With several stand-ins the whole console is one
  arch per ally, side by side, sharing their feet — an M with as many humps
  as there are allies. Each player sees only their own section: their arch
  whole, the neighbours' feet at its sides. The console grows to hold every
  ally while each section stays the same size.
- Only buttons answer clicks; the band and the dials are information.

## Suggested Implementation Steps

1. Arch geometry: outer and inner curves of the band, the interior, as
   functions of a section's width, height and band thickness; hit tests.
2. Lay the dashboard out in arch coordinates (across from the center, up
   from the base) as a data table.
3. The band's glass: the view plane samples the world picture through it
   (so the plane is drawn in a second pass, after the world).
4. The M: neighbours' arches drawn at the section's sides, dimmer, labelled
   with their seat.
5. Tests: the arch's interior and band never overlap; every button lies
   inside the interior; the section's size does not change with team size.

## Open questions

- Is the band "the display of the map" meant as glass onto the world behind
  it (as built), or as a separate drawn map (a minimap) along the band?
- In the round world, are allies' arches arranged in a ring around the hub
  (one facing each quadrant), with the M seen as a straight row only because
  you see one section at a time?
