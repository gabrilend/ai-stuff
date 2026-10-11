<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Current design of the map projection. Updated by the accordion view
     issue in phase 3. -->

# Datapath: from a world position to a pixel (the accordion)

## Data

| Structure | Fields |
|---|---|
| position | `tier_distance` (number), `angle` (number, radians) |
| accordion settings | `reach` (number: how many tiers fit between the wheel's edge and the screen edge), `squeeze` (number 0–1: 0 = every tier equally wide, 1 = strongly compressed outer tiers), `rotation` (number, radians: which way is up — turning the view so the current stand-in's quadrant faces up) |
| screen | `center_x`, `center_y` (numbers, pixels), `wheel_radius` (number, pixels: the map starts here), `edge_radius` (number, pixels: the map ends here) |

## Steps

```
 position ─▶ radial curve(tier_distance, reach, squeeze) ─▶ fraction 0..1
          ─▶ pixel radius = wheel_radius + fraction × (edge_radius − wheel_radius)
          ─▶ angle + rotation ─▶ (x, y) on screen
```

The radial curve: with squeeze 0 it is a straight line (tier distance /
reach). As squeeze rises it becomes a logarithm-like curve that gives the
inner tiers more room and folds the outer tiers together toward the edge —
the accordion closing. The curve is always increasing, so it can be run
backwards: a mouse click becomes a position by the inverse curve. Anything
beyond `reach` is drawn pressed against the screen edge as a marker, not
dropped.

Two zooms, two dials:

- **reach** — how much territory you overlook (more tiers on screen).
- **squeeze** — how the space is shared between near and far.

Each stand-in has their own accordion settings; switching seats in hot-seat
play restores that seat's settings.
