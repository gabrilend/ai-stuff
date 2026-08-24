# 508 — Sign-Posts Stand at the Corners

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 101, 106, 202, 503 |
| Blocks | 705 |
| Reads | [sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md) |
| Open questions | none |

## Current behavior

The junction branch in the move pass returns "straight on" from a stub. Heroes
walk the lane they were spawned into and cannot be steered.

## Intended behavior

Four sign-posts, one at each junction — the two bends on each side lane. Each is
a piece of the world with a position, not an entry in a menu.

The record, the two-entry `direction` field, and the reasoning for all of the
below are in
[sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md).

**Who obeys: heroes, and only heroes.** Wave units, guards, and monsters ignore
them entirely. If waves could be rerouted, a team could feed all three lanes into
one and the three-lane structure of the map would be decorative.

**Who may set: only the team whose half the junction sits in.** Two each. You
cannot reroute at the far corners, so once a hero crosses the midpoint it is
committed — which is what makes routing a prediction rather than a correction.

**No locks and no objections.** Any player may set any of their team's two, at any
time. Sign-posts are instant and reversible, and a negotiation layer over
something undoable in one click would be ceremony with nothing under it.

**Hidden from the enemy.** You cannot read the opponent's standing orders. The
same rule as everything else: you learn where their heroes go by watching heroes
arrive.

The default is **straight on**, so a player who never touches one gets the
behaviour they would expect from a game with no sign-posts in it.

## Suggested implementation steps

1. Write the sign-post array, populated by the map builder from the junction
   nodes.
2. Replace the junction stub in the move pass with the lookup, guarded on flavour
   so only heroes read it.
3. Write the `set_signpost` handler with the territory check.
4. Put **your own** sign-posts' directions into the snapshot. Put the enemy's in
   as objects with **no direction field** — not a hidden field the viewer declines
   to draw, an absent one. A viewer cannot leak what it was never sent, and this
   is the only place in the snapshot where a field is withheld by team.
5. Write a test that a team's snapshot contains no direction data for the enemy's
   two sign-posts.
6. Write a test: set a sign-post toward the connector, spawn a hero up that lane,
   assert it ends up in the center lane and that a wave unit behind it does not.

## Related documents and tools

- [Sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md)
- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
