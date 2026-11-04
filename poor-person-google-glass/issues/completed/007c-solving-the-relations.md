# 007c — Solving the relations

**Phase:** 0 — Tools
**Parent:** 007
**Blocked by:** 007b
**Blocks:** 007d

## Current Behavior
Built in `src/014-solving-the-relations.lua`: sizes, directions, places,
each in dependency order (depth-first, circles refused with their lines).
Extents a part is measured by itself are applied last. The middle of
everything is the first part named that no sentence places (not simply the
first part, so "the drum sits on the base" can be said with the drum named
first). Every default used is listed for the report.

## Intended Behavior
Statements become parts with numbers: extents (along, across, deep), axis
("x", "y" or "z"), centre {x,y,z}, colour. Names are resolved to numbers once,
in dependency order (a part is sized and placed after every part its
statements mention). Sizes: an extent set by a statement is ratio × the
named extent of the other part; extents not mentioned keep the kind's
proportions to the ones that are. Placement: one position statement per
part (on top of, under, beside, in front of, behind, inside, at the centre
of, at the end of, passes through, around), plus orientation (stands
upright, lies flat, lies front to back, aligned with the axis of). The first
part sits at the origin. A part never placed is an error, not put somewhere.
Two statements fixing the same extent or position differently, and any
cycle, are errors naming both lines. Every default used is listed in the
result, so the report can show what was assumed.

## Suggested Implementation Steps
1. src/014-solving-the-relations.lua.
2. Tests: "twice as wide" doubles; an unmentioned extent keeps proportion;
   "on top of" makes faces touch; "aligned with the axis of" puts centres on
   the line; a cycle and a conflict are refused with both lines named.
