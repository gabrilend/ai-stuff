<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10;
     reworked the same day: the map is a grid on a sphere, and far or
     crowded units merge into level-and-count markers. Updated by phase 3
     issues. -->

# Datapath: from a place on the sphere to a pixel

## The world is a sphere

The map is a grid lying on a sphere. The hub is one pole. Tiers are bands of
latitude: tier 1 the ring nearest the pole, each further tier further toward
the equator and beyond. Each band takes the same time to cross
(**tier-time**), so the grid's cells are not equal in real size; the sphere
and the timing are what is true, and the circle on screen is a distortion
that makes it viewable all at once.

The sphere has two faces: the surface and the **underworld** inside it. (How
the two faces connect, and what lies at the far pole, are open questions.)

## Data

| Structure | Fields |
|---|---|
| place | `tier_distance` (number: 0 = hub pole, 1.0 = outer edge of tier 1), `angle` (number, radians, 0 = up, clockwise), `face` (the word `surface` or `underworld`) |
| projection settings | `tiers_shown` (number), `fold` (number 0–1: how strongly outer tiers fold toward the edge), `rotation` (number, radians: the current seat's quadrant faces up) — set by the game, never by the player (dials and settings are information only) |
| screen | `center_x`, `center_y` (numbers, pixels), `dashboard_radius` (number, pixels: the map starts here), `edge_radius` (number, pixels: the map ends here) |
| merged stand | `average_level` (number), `count` (integer), `balance` (number −1…1: its strength against the threat it contests), `place` |

## Steps

```
 place ─▶ radial curve(tier_distance, tiers_shown, fold) ─▶ fraction 0..1
       ─▶ pixel radius = dashboard_radius + fraction × (edge_radius − dashboard_radius)
       ─▶ angle + rotation ─▶ (x, y) ─▶ 3D scene position (see datapath-glass-and-metal)
```

The radial curve is a logarithm-like curve: inner tiers get the most room,
outer tiers fold together toward the edge. It is strictly increasing, so a
click runs backwards to a place exactly.

## Merging

```
 stands in one screen cell ─▶ too many, or too far out?
     no  ─▶ draw each stand's models
     yes ─▶ merge: average level, total count, balance vs. contested threat
          ─▶ marker: level and count on a small dial; balance color;
             differential triangles (▲ ahead / ▼ behind, more = larger gap)
```

Merging is a view decision only: the simulation still holds every unit.
Clicking a merged marker names its strongest stand (open question: or the
whole merge?).
