# 508 — Sign-Posts Stand at the Corners

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 101, 106, 202, 503 |
| Blocks | 705 |
| Reads | [sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md) |
| Open questions | none |

## Current behavior

Six posts, one per lane per team, standing at the junctions and clickable where
they stand as well as in the panel. A click cycles: straight on, then each connector
leaving that junction, then back. The middle has two alternatives and the side lanes
one each.

Heroes obey them and nothing else does. Only the viewing team's are drawn.

## Intended behavior

**Six sign-posts on a three-lane map: three junctions, and each team has one at
each.** The junctions are the top-left corner, the middle of the field, and the
bottom-right corner — the three points where the lanes come closest, joined by
connectors along that diagonal. One post per lane per team, so the count follows
the team size.

The record and the reasoning for all of the below are in
[sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md).

**Who obeys: heroes, and only heroes.** Wave units, guards, and monsters ignore
them entirely. If waves could be rerouted, a team could feed two lanes into one
and the lane structure of the map would be decorative.

**One turn per body, ever.** A hero that has followed a sign-post goes straight on
at every junction for the rest of its life. The whole feature is the ability to
move a body into a neighbouring lane once, with the walk to the corner as the
delay. It is not a routing system and it cannot build a loop.

**Who may set: any player, any of their own team's three, at any time.** The two
teams' posts are separate objects standing at the same junctions, so setting one
is only ever an order to your own heroes and never an act against the enemy.

**No locks and no objections.** Sign-posts are instant and reversible, and a
negotiation layer over something undoable in one click would be ceremony with
nothing under it. What the viewer owes instead is a loud signal when a teammate
changes one, since it silently redirects every hero they have inbound.

**Hidden from the enemy — absent, not undrawn.** You cannot read the opponent's
standing orders, and under the networking model their posts are not on your
machine at all. You learn where their heroes go by watching heroes arrive.

The default is **straight on**, so a player who never touches one gets the
behaviour they would expect from a game with no sign-posts in it.

## Suggested implementation steps

1. Write the sign-post array, populated by the map builder from the junction
   nodes — one entry per junction per team, each carrying its `team`.
2. Replace the junction stub in the move pass with the lookup, guarded on flavour
   so only heroes read it, and on the body's own team so it reads its own team's
   post.
3. Give a body a "has already turned" flag and check it before consulting a post
   at all. This is the rule most likely to be forgotten, because nothing breaks
   visibly without it — heroes simply become steerable twice, and the lane
   structure quietly stops meaning anything.
4. Write the `set_signpost` handler, refusing any post that is not the issuing
   player's team's.
5. Put **your own team's** sign-posts into the viewer's frame. The enemy's are not
   in it at all — not a hidden field the renderer declines to draw, an absent one.
6. Write a test that a team's frame contains no entry whatsoever for the enemy's
   three sign-posts.
7. Write a test: set a sign-post toward the connector, spawn a hero up that lane,
   assert it ends up in the centre lane, that a wave unit behind it does not, and
   that the same hero ignores the centre post it reaches afterwards.

## Related documents and tools

- [Sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md)
- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
