# 602 — A foe per direction, with an outpost at each tier

**Phase:** 6 — Foes in every direction
**Blocked by:** 601, 105

**Blocks**: 603, 605, 607
**Related documents:** docs/core-terms.md (direction, tier, front),
docs/game-design.md (Center to outer)

## Current Behavior

The only enemy is phase 3's scripted foe.

## Intended Behavior

- One foe per quadrant direction (by default; see open question). A foe has
  an outpost in each tier band of its direction, growing stronger outward,
  and its own treasury, factories and stands, using the same rules as a seat.
- A front is the pairing of a seat's direction and the foe's current tier.
- The snapshot lists each front: direction, current tier, both sides'
  strength.
- **Two teams of four, pole to pole** (the owner, 2026-10-10):

  > the enemy kingdoms are all equidistant from their opposites. So player
  > A, B, C, and D are up against player 1, 2, 3, and 4. Team alphabet is
  > arranged like this:
  >
  >     A B
  >     C D
  >
  > while team numbers are like this:
  >
  >     1 2
  >     3 4
  >
  > in that case, A and 1 are opposite one another in the direction of the
  > top-left corner of their team-grid for both 1 and A. B and 2 are
  > opposite one another, pointing toward the top-right of B and the
  > top-right of 2. Our camera sits in the middle, and as it turns left and
  > right we can see a different angle of the battle - outside the walls of
  > the castle. Distant reports are sorta innacurate "oh there's some bad
  > guys over here walking around in a large area" like actors on one of
  > those greek stages where the actors went up a staircase too

  The foes are one team of four (seats 1-4) whose hub is the sphere's far
  pole, every one of them the same distance from us (the far pole tier, see
  issue 104). Each of our seats faces one foe: A (our top-left quadrant)
  faces 1 (their top-left), B faces 2 (top-right to top-right), C faces 3,
  D faces 4. Seen from our hub, foe 1's kingdom lies far out in A's
  direction, near the far pole; the chair turning shows "a different angle
  of the battle - outside the walls of the castle".
- **Reports from afar are vague**: what is far away is not shown exactly
  but as "some bad guys over here walking around in a large area" — a
  presence spread over a region rather than figures at their true places,
  the vaguer the farther (see the open questions).

## Suggested Implementation Steps

1. Foe table in the world (shares the seat machinery: treasury, factories,
   stands).
2. Outpost placement per band, strength by tier.
3. Front list derived each tick.

## Open questions

- Answered: four foes, one team, pole to pole (above).
- "Like actors on one of those greek stages where the actors went up a
  staircase": is the far region shown as a raised stage — the distant
  rings stepping upward like a theatre's tiers, with a few stand-in actors
  playing the foe's forces there — or is the staircase about the actors
  coming and going (reports arriving and leaving)?
- How vague, and by what: by distance alone, or also by how old the report
  is (couriers carry news, issue 106)?
