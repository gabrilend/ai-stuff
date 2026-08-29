# Phase 4 — The Places

Everything above and below the block. Mostly bookkeeping, and almost none of it
geometry.

**Nine issues. None complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [401 — the containment chain is a list](401-the-containment-chain-is-a-list.md) | not started |
| [402 — groups, and the absence of a root](402-groups-and-the-absence-of-a-root.md) | not started — open question 11 |
| [403 — quadrants, four to a group](403-quadrants-four-to-a-group.md) | not started |
| [404 — districts are membership only](404-districts-are-membership-only.md) | not started — open question 12 |
| [405 — boundaries derived from members](405-boundaries-derived-from-members.md) | not started |
| [406 — a building, and its facts](406-a-building-and-its-facts.md) | not started |
| [407 — a house has no geometry](407-a-house-has-no-geometry.md) | not started |
| [408 — the zoom picks the level](408-the-zoom-picks-the-level.md) | not started |
| [409 — the cage at four weights](409-the-cage-at-four-weights.md) | not started |

## The finding that shaped this phase

**Three whole levels cost nothing but membership.** A district's outline is the
outer edges of its member blocks — an edge is on the boundary when exactly one of
the two blocks touching it is inside. That rule needs no geometry, serves every
level identically, and makes it *impossible* for a boundary to disagree with what
it is made of.

It is the same reasoning that made a block a face of a shared network rather than
an outline of its own, applied a level up: where a property matters, choose the
representation in which violating it cannot be expressed.

## The absence that is not a hole

Land beyond the wall has **no quadrant**. The tempting shape is a record with a
field per level, one sometimes empty — after which every piece of code walking the
hierarchy grows a test for nothing-there, and those tests spread into the tome,
the selection, the filters and the reports.

The absence has a cause: **the wall is what makes a quadrant.** So a place carries
the levels it has, as a list, and nothing anywhere asks whether a quadrant exists.

## What the top of the hierarchy turned out to be

Not a tree. A **forest of groups** — the city, and each megastructure — none of
which has a parent. Giving them a shared root called "everything" would invent a
place nobody lives in, purely so a walk could terminate tidily. It terminates when
the parent is absent, which is enough.

## The idea worth keeping

A quadrant is not a container, it is **a social horizon**: the scale at which two
people simply never meet. That has a consequence nothing is built for — because
readings are per person, a citizen's knowledge comes out shaped like their
quadrant, and the hatching draws the horizon on its own.
