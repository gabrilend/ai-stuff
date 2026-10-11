<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10;
     reworked twice the same day: first when the owner said the player clicks
     only order buttons and dials are information only, then when the owner
     shaped the console as one hump of an M. Positions live as data in
     src/014-the-dashboard.lua (arch units); this file holds the arrangement
     and the reasons. -->

# Console layout: the arch

The owner's picture: "half of the M in the McDonald's golden arch, and that
is the display of the map, while the interior part, the part that's below
the M's curve but above its very bottom, that part is the dashboard surface.
With multiple allies, you see only a section, but it grows to accommodate all
of you, so it always remains the same size."

```
                 ╭───────────────╮            ← the band: gold-edged glass,
   SEAT 4      ╭─╯   ┌OCTOBER─┐  ╰─╮    SEAT 2   the map seen through it
  ╲  feet     ╱      ┌SATURDAY┐     ╲   feet  ╱
   ╲         ╱          (10)         ╲        ╱
    ╲       ╱  ●    (144)(6.9)(192)  ●╲      ╱  ← the surface: buttons ●
     ╲     ╱   ●   ┌─SEAT 4·LV 7─┐   ● ╲    ╱     and dials ( ) ┌─┐
      ╲   ╱    ●                     ●  ╲  ╱
       ╲ ╱     ●   ESCAPE: SETTINGS  ●   ╲╱
 ───────┴───────────────────────────────────┴──────  base
```

## Placement

The arch stands on the window's bottom pixel row and is stretched to both
sides (the owner: "position the bottom of the dashboard at the bottom pixel
row" and "width-enhance the dashboard to meet the edge of the screen"); its
height is a setting, half the window's height to start. With the arch full
width, allies' arches are off screen until the chair turns.

## Parts

- **The band** — the arch's curve, from foot to foot: glass through which the
  map behind is seen, bent a little like a lens, edged in gold. It is the
  map's display; it is never clicked.
- **The surface** — beneath the band, above the base: brushed metal.
  - Calendar: an arc window showing the month, a second below it showing the
    weekday, and a round hole below that onto the day number, one disc lower.
  - Readouts: frames per second, frame time, unit count.
  - The named slot: who the next order goes to.
  - Order buttons in two columns up the inside of the legs: advance, attack,
    hold, fall back on the left; flank left, flank right, shield, build on
    the right.
- **The neighbours** — with allies, the console is one arch per ally side by
  side, sharing feet: an M with a hump each. You see your own arch whole and
  your neighbours' feet at the sides, dimmer, labelled with their seat. Seats
  form a ring, so with four allies seat 1's neighbours are seats 4 and 2.

## Settings (Escape)

The calendar and the named slot give way to a large dial showing the
framerate cap, a row of painted −10, −1, +1, +10 buttons beneath it, the
three look toggles (FLAT VIEW, HUB VIEW or SLANT VIEW, UPRIGHT or OUTWARD, BLUR ON or
BLUR OFF), and BACK
and QUIT. The readouts stay.

## The rhythm

Map, console, map, console. The first click (map) names who; the second
(console) says what. Only painted buttons answer clicks.

## Why the console is in the middle

Your base is the middle of the world and every order starts there. Every
return of the eye to the console sweeps across the map on the way, and the
console's own band is a lens onto the map, so even while reading dials the
map is in view.
