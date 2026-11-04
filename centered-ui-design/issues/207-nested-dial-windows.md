# 207 — Nested dial windows

**Phase:** 2 — Glass and metal
**Blocked by:** 203, 204
**Blocks**: 208, 302, 306
**Related documents:** docs/visual-language.md (Dashboard materials),
docs/console-layout.md

## Current Behavior

Every dial is drawn at one depth.

## Intended Behavior

- A dial's surface can itself have a window cut into it, through which a
  second dial one level lower is seen — "a number, on one level lower". The
  calendar is the first user: month or weekday on the upper dial, the day
  number below.
- The lower dial is darker than the one above. Each window's glass is
  seamless with the surface around it.
- Implemented with stencils so anything on a lower dial only shows through
  its window.

## Suggested Implementation Steps

1. Extend the dial with an optional nested dial and a window on its own
   surface.
2. Stencil drawing, deepest first.
3. Demonstrate a two-level calendar: weekday words on the upper dial,
   numbers 1–31 below.
