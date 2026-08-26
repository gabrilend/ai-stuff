# 042-sight

What a body can see, right now. Recomputed whenever asked, never stored between
ticks.

**This is not a drawing feature.** It is computed so the outbound filter knows
which records it may put on a socket. That it also happens to be exactly what a
renderer needs for a clean edge between torchlight and dark is a convergence
worth noticing, not the reason it exists.

## The functions

| Function | In | Out | Notes |
| --- | --- | --- | --- |
| `sight_ray` | world, from, direction, range | distance | The primitive. How far the light gets before something stops it. |
| `sight_point_visible` | world, body, x, y | 1 / 0 | **What decides what may be sent.** Casts a fresh ray; does not read a fan. |
| `sight_compute` | world, body, `*fan` | 1 / 0 | Builds the visibility polygon, for drawing and for the fog. |
| `sight_fan_init` / `_release` | | | |
| `sight_fan_capacity_for` | world | count | What to pass to `sight_fan_init`. |

`struct sight_fan` holds the origin, the wedge (centre, arc, range, start), and a
run of `struct fan_point` — an angle and a distance — sorted by angle **measured
from the wedge's starting edge**, so a wedge straddling the wrap point sorts like
any other with no special case.

## Ray casting, not an angular sweep

The classic answer is a sweep: sort every wall endpoint by angle, walk through
them keeping a set of walls currently crossing the sweep ray, emit a boundary
wherever the nearest member changes. O(n log n), and what a large scene wants.

This casts a ray at every corner instead — three rays, one at the corner and one
just to either side — and takes the nearest wall each meets. O(corners × walls).

**Why:** the sweep's difficulty is entirely in the active set — deciding which of
two overlapping segments is nearer, in integer arithmetic, with ties broken the
same way on every machine. Get it slightly wrong and a wall goes missing at one
angle, and somebody sees through stone. That is a security failure, not a drawing
glitch, because this polygon decides what goes on a socket.

Ray casting has no active set. Each ray is independent and obviously correct. At
tabletop scale it is also fast enough: the phase 2 demo measures it rather than
this file claiming it — currently around 90 microseconds per body against 17
walls, which for a table of six is about 1% of one core at twenty ticks a second.

If that measurement ever says otherwise, the sweep is the answer, and the tests
in `043-test-sight.c` are what will keep it honest while it is written.

## Three rays per corner

A ray aimed exactly at a corner is ambiguous — it may stop there or slip past,
and which it does is a rounding accident. The rays to either side are
unambiguous, and between them capture both what the corner hides and what it
reveals. The nudge is two angle units, about five millimetres at fifty metres.

## Two independent answers, on purpose

`sight_compute` draws the picture. `sight_point_visible` decides what may be sent.
They are computed differently, and a test asserts they agree across thousands of
sampled points.

One implementation would make a drawing bug and a leak indistinguishable.

## The cases handled explicitly

- A wall seen exactly edge-on blocks nothing — treating it as a hit would put a
  phantom edge in an open room whenever a body lined up with a wall.
- A ray grazing a wall's endpoint **is** stopped — a corner is solid, and treating
  it as a gap lets a body see a sliver through a join between two walls.
- A one-way wall's blocking side is decided once, from the eye's side.
- A body with no range or arc sees nothing, which is a coffee cup's normal state.
- The point a body is standing on is visible without asking for its direction,
  which is undefined.
