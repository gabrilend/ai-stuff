# 1309 -- The phase thirteen demo

**Phase:** 13, the world becomes solid
**Blocked by:** [1304](1304-the-reveal-is-a-distance-field.md),
[1306](1306-the-passes-are-a-sequence.md),
[1307](1307-the-third-view.md),
[1308](1308-the-question-window.md)
**Blocks:** nothing. It is the capstone.
**Documents:** [the roadmap](../docs/015-roadmap.md)

## Current behaviour

Twelve demos exist and all of them draw a flat world. `./run-phase-demo` counts
them, offers them by name, and runs the one you pick.

## Intended behaviour

**A demo in which the world is solid, somebody walks into it, and the picture is
never a hole.**

It must show, in one run:

1. A DM building geometry live -- dragging a vertex, bisecting an edge -- while
   somebody else is standing in the room. Nothing recomputes, because visibility
   is authored and geometry does not decide it.
2. A structure sitting on an elevation tilemap, each unaware of the other.
3. A body walking toward a corner, with tiles fading in as the distance field
   falls, rather than a wedge appearing all at once.
4. A doorway into an unrevealed room drawn as *a stone doorway shrouded in
   shadow* -- a surface, not blackness -- and a test alongside it proving no term
   in that surface read anything on the far side.
5. The DM raising one structure's reveal by one, and the goblins in it becoming
   visible without the DM touching a single creature.
6. The pass schedule printed beside the pass table, with the sequence visible,
   and a body's total distance over N beats shown equal to what the alternation
   would have moved it.
7. A player pulling a locked drawer, and the same zero being what the player sees
   and what the AI would have seen.
8. All three views on one session -- browser, terminal, and the new one -- and
   the server unchanged between them.

**Proves:** that a world can be built while it is being played in, that
visibility can be a decision rather than a computation without the picture
becoming a hole, and that the third view cost no server change, for the second
time.

## Suggested implementation steps

1. Build it last, and let it find things. Every capstone so far has.
2. Reuse the phase 11 demo's arrangement for running two views at once, and add
   a third.
3. Report statistics rather than describing functionality: vertices, tiles
   flooded, reveal levels, beats, and the schedule itself.
4. When it finds something -- and it will -- write that down here and in the
   phase progress file rather than fixing it quietly.
