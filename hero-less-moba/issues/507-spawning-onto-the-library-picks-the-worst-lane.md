# 507 — Spawning Onto the Library Picks the Worst Lane

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 102, 503 |
| Blocks | 703 |
| Reads | [the base and the library](../docs/008-the-base-and-the-library.md), [hero units](../docs/012-hero-units.md) |
| Open questions | none |

## Current behavior

A hero bought at the library enters the lane where the enemy has pushed deepest,
measured in **milestones** rather than distance — a lane where they sit one pace past
your first tower is in less trouble than one where they are inside your base, even
though the base is nearer.

## Intended behavior

The third spawn destination, and the only one that can never be blocked — if
enemies are next to your library the match is nearly over anyway.

The hero enters **the lane where the enemy has pushed deepest**, measured in
milestones, and walks outward.

The vision is emphatic that this is not a distance question: "not in terms of
distance as-the-crow-flies, but rather in terms of milestones thru the map." Its
worked example is the whole reason the milestone system exists — a lane where the
enemy sits one pace past your first tower is *less* urgent than a lane where the
enemy is inside your base, even though the base is physically nearer your
library. A straight-line check picks the wrong lane precisely in the case where
picking wrong loses the match.

The lookup:

1. Read the enemy's push depth for each of the three lanes — three integers the
   team record already keeps.
2. Take the largest. Break ties by lane number, low first, **deterministically
   and without touching a random stream**, so that a player watching two equally
   pressed lanes can predict where their hero will go. A random tiebreak here
   would be a hero appearing somewhere the player did not expect, which reads as
   a bug.
3. Enter that lane's path at the library node, facing outward.

**It re-evaluates nothing after that.** A hero that walked into the top lane
stays in the top lane unless a sign-post tells it otherwise. Continuously chasing
the worst lane would make heroes wander, and a wandering hero is a wasted
purchase.

This is the defensive option and it is slow — the hero has a long walk. Arrive
now and fragile, or arrive late and intact: that tradeoff across the three
destinations is the spend decision.

## Suggested implementation steps

1. Extend `spawn_hero` for destination kind 3.
2. Call `worst_lane` from issue 102. Do not reimplement it here.
3. Comment at the call site that the "walk once, never re-evaluate" behaviour is
   deliberate, so nobody later helpfully adds re-evaluation.
4. Write a test with the vision's own example: enemy one step past the first
   tower in one lane, enemy inside the base in another, assert the hero picks the
   second even though it is physically nearer the library.

## Related documents and tools

- [The base and the library](../docs/008-the-base-and-the-library.md)
- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
- `worst_lane` from issue 102
