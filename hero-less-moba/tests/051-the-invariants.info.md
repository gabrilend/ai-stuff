# 051-the-invariants

The properties this project refuses to break, checked in one run.

## Running it

```
luajit tests/051-the-invariants.lua
```

Exits non-zero if anything failed, so it can be wired into a build. `./run-tests` runs
this along with the documentation validator.

## What it checks, and what each one is really guarding

| Check | Fails the day somebody… |
| --- | --- |
| The map validator finds nothing wrong | …changes a shape parameter that makes the geometry inconsistent. |
| A lane's milestones mirror across the junction diagonal | …breaks the symmetry independently of the validator noticing. |
| **The world under the cursor does not move while zooming** | …adds a camera feature that quietly breaks issue 708's whole point. |
| Home returns to the whole map instantly and drops the drag | …makes getting back a navigation task, after which players stop zooming in at all. |
| The camera cannot pull back past the whole map | …lets the map drift into empty space. |
| The camera cannot push in past the badge-reading ceiling | …unbounds the zoom. |
| A query wider than the grid's cell still finds everything | …reintroduces the fixed nine-cell ring. |
| No per-body field is ever nil | …adds a field to the world and forgets to zero it, or to clear it on release. |
| **The same seed plays the same match, tick for tick** | …adds a global random call, iterates a hash table whose order is not stable, or reads the wall clock. |
| Stacking a lane pushes its frontline further | …breaks the premise, however well everything else runs. |

## Two of them earn their place above the others

**Reproducibility** is the project's most valuable regression test. It is compared on a
fingerprint of every body's position and health rather than on a summary, because a
summary can agree while the details diverge.

**The camera anchor** is checked with four hundred random cursor positions and random
scale changes rather than with one hand-picked case, because every later camera feature
is a chance to break it silently. It is asserted against the camera's **target** rather
than its drawn values — the animation is allowed to be on its way; it is the destination
that must be exact. Trials where the pan clamp bites are skipped rather than failed,
because the clamp is a deliberate rule and not a defect.

## The test's own randomness

The camera test uses a small hand-written generator rather than `math.random`, so that a
failure is reproducible — and so that this file cannot be the thing that introduces
global randomness into a project whose first invariant is that there is none.

## What is not checked yet

**Symmetry.** The documents ask for a second standing test: a match with no player
commands should leave the two teams in exact mirror states at every tick. It does not
currently hold, and why it does not is written up as an open question rather than papered
over. See `docs/020-open-questions.md`.
