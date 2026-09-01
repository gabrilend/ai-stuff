# 305 — A Ball Collides With Faces And Corners

| | |
| --- | --- |
| Phase | 3 — The Rolling |
| Blocked by | 304 |
| Blocks | nothing |
| Reads | [rolling with momentum](../../docs/013-rolling-with-momentum.md), [ways this could go wrong](../../docs/027-ways-this-could-go-wrong.md) |
| Open questions | none |

## Current behavior

Faces then corners, with the corner push only where both orthogonal neighbours
are open — pushing off a corner whose neighbour is also wall would shove the ball
back through the face it was just pushed out of.

While airborne the ball is resolved against the stone at its **current** height
rather than the surface below it.

`tests/053-bodies-stay-outside-stone.lua` runs three scenes over two seeds for
eighteen hundred ticks each and finds nothing buried, nothing outside the world,
nothing below it and nothing hanging in the air.

That test does **not** assert zero. A ball rolling on an interpolated floor is
strictly inside the step it is crossing — the blend is between the two cells'
heights while the ball is still over one of them — and that is the lie the
interpolation exists to tell. The clamp bounds the dip at one layer, and the
bound is what is asserted. A ball that has tunnelled into a wall is several
layers under. Working that out took a failing test and a while.

## Intended behavior

The ball has a `radius` a little under half a cell. A neighbouring cell whose
surface is more than `climb_limit` above the ball's is a **wall**, and the plane
at the boundary between the two cells is a **face**.

When the ball's centre comes within `radius` of a face:

1. Push it back out along the face's normal to exactly `radius`. Pushed out, not
   moved back along its path — resolving an overlap is about ending up somewhere
   legal, and straight out is the cheapest legal place.
2. Reverse the velocity component along the normal and multiply it by
   `restitution`. Leave the component along the face alone, so a ball at a
   shallow angle slides along the wall instead of stopping dead.

**Corners are the case that gets forgotten, and this issue exists mostly for
them.** Where two walls meet, the nearest point of the obstacle is not on either
face — it is the corner post — and the ball must be pushed away from a *point*.
Handling only the faces lets a ball squeeze diagonally through the join between
two blocks, which looks exactly like passing through solid stone, happens rarely
enough to be dismissed as a glitch, and is named in
[the risks](../../docs/027-ways-this-could-go-wrong.md) as the most likely bug in
this file.

**While airborne, the ball is checked against the stone at its current height,
not at the height of the surface below it.** A column solid at the ball's z is a
wall to it right now. Skipping that lets balls tunnel into the sides of walls and
re-emerge inside them, and once a ball is inside stone every rule in the design
gives a wrong answer — the floor under it is the top of the block it is inside,
so it stands on nothing, so it falls forever.

## Suggested implementation steps

1. Write the neighbour classification once per tick per ball — the eight
   surrounding cells, each labelled floor, wall, or cliff — and reuse it for the
   floor field, the faces, and the corners. Three passes over the same eight
   cells would be three cache visits for one answer.
2. Resolve the four faces first, then the four corners, then re-check the faces.
   A corner push can move the ball into a face it had already cleared.
3. Write the airborne wall check against the column at the ball's current layer.
4. Write the test that matters: run several thousand balls for a long time and
   assert **no ball is ever at a position whose column has stone at its height.**
   This one test is worth more than the collision code being carefully written,
   because careful code can be defeated by a number somebody changed.
5. Write a scenario that reproduces the corner case deliberately — two walls
   meeting at a diagonal, a ball aimed at the join at speed — and keep it in
   `scenarios/`, because a bug that has a scenario is a bug anybody can run.

## Related documents and tools

- [Rolling with momentum](../../docs/013-rolling-with-momentum.md)
- [Ways this could go wrong](../../docs/027-ways-this-could-go-wrong.md)
