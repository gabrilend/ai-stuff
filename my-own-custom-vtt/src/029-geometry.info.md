# 029-geometry

The questions you are allowed to ask a wall. A wall is a line segment, not dark
pixels, and this file is what that buys — every one of these is a question a
picture could not have answered.

All integer arithmetic. Several return `int64_t` rather than a world coordinate,
because a cross product of two positions is a squared quantity that does not fit
in 32 bits. Two positions a kilometre apart multiply to about 2^42, and a wrapped
sign there means a one-way wall that blocks from the wrong side.

## The functions

| Function | Answers | Notes |
| --- | --- | --- |
| `geom_side` | Which side of directed segment a→b is point p on? | Positive is left, negative right, **exactly zero is collinear**. This is what `WALL_ONE_WAY` is tested with — "the segment's left" is literally this returning positive. |
| `geom_segments_cross` | Do these two segments cross? | Touching at an endpoint **counts**. |
| `geom_closest_point_on_segment` | Where on a→b is nearest to p? | Clamped to the endpoints, so an end cap is handled. A zero-length segment returns its own endpoint. |
| `geom_distance2_to_segment` | How far, squared? | Squared, because every caller compares against a squared radius. |
| `geom_segment_within_circle` | Does this segment come within `radius` of this point? | The broad-phase question for sight and for collision. |
| `geom_polygon_contains` | Is this point inside this closed polygon? | A point **on the boundary is inside**. |
| `geom_polygon_area2` | Twice the signed area. | Sign gives winding; zero means no interior. Doubled because nothing wants the area itself, only its sign and whether it is zero. |
| `geom_polygon_self_intersects` | Does this polygon cross itself? | Adjacent edges share an endpoint by construction and are skipped — including the wrap between the last edge and the first, whose omission makes every polygon report itself as broken. |

Polygons are given as a pointer to the first vertex and a count. The boundary is
closed by joining the last back to the first; the last vertex is **not** repeated.

## The three decisions that had to be made rather than derived

**Collinear is a real case, not a rounding artefact.** Three points in a line
happens constantly in a generated map, where corridors meet at right angles and
rooms share walls. Callers must decide what it means for them rather than
assuming it will not occur.

**Touching at an endpoint counts as crossing.** A body sliding along one wall
into a second must be stopped by the second even though it only grazes it, and a
polygon whose edges merely touch is still self-intersecting.

**A point exactly on a region's boundary is inside.** Arbitrary, and pinned
rather than left to the arithmetic: a body walking along an edge has to be
consistently in or consistently out. If it flickers, the ruleset gets an
entered-the-tavern event on every step.

## The place point-in-polygon usually goes wrong

The crossing-number comparison is deliberately asymmetric — one endpoint strictly
above the ray, the other not — so that an edge whose endpoint sits exactly on the
ray is counted once rather than twice or not at all. A symmetric comparison there
is the classic bug, and a test covers it.

## The broad phase is conservative in one direction only

`geom_segment_within_circle` may say yes for a segment that turns out not to
matter, and must never say no for one that does. Too generous costs a little
sorting. Once too strict makes a wall vanish, and somebody sees through stone.
