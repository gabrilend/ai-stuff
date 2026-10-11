<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Current design of how a console element becomes pixels. Updated by
     phase 2 issues. -->

# Datapath: one console element to pixels

## Data

| Structure | Fields |
|---|---|
| palette token | `name` (string, e.g. `metal-3`, `glass-1`, `paint-seat-2`), `r`, `g`, `b`, `a` (numbers 0–1) |
| element | `shape` (circle, ring, arc segment, half-circle), `center_x`, `center_y`, `inner_radius`, `outer_radius` (numbers, pixels), `start_angle`, `end_angle` (numbers, radians), `material` (metal, glass, paint), `tone` (integer 1–5, dark to bright), `rotation` (number, radians), `angular_velocity` (number, radians per second) |
| readout | an element plus `value` (number), `shown_value` (number, rolls toward value), `digits` (integer) |

## Steps

```
 snapshot values ─▶ console layout (which elements, where) ─▶ element list
 per frame, in order back to front:
   lower discs (complications' insides)
   ─▶ metal body: base tone + circular brushed-streak shader + rotating highlight
   ─▶ cut-outs: complication windows reveal the lower discs
   ─▶ glass: refraction shader samples what is beneath, tints, adds edge + highlight
   ─▶ paint: buttons, flat bright, pressed state
   ─▶ text along arcs
```

Rotation is physical: each rotating element has an angular velocity, a
friction, and detents (resting angles it settles into). Values roll toward
their target each frame; they are never set instantly.

This is pure viewing code: it reads snapshot numbers and never changes the
world.
