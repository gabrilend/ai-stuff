# 705 — The Sign-Posts Are Clickable in the World

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | 508, 701, 702 |
| Blocks | 805 |
| Reads | [sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md) |
| Open questions | none |

## Current behavior

Sign-posts are clickable where they stand. Only the viewing team's are drawn — not
greyed out, not drawn without a direction: not drawn.

## Intended behavior

Four objects standing at four corners of the map, clicked where they stand.

They are **not** a menu, a panel, or a settings screen, and the difference is the
whole design of the feature: a per-hero waypoint order is a chore repeated once
per purchase, while a sign standing at a corner is a **policy** every hero obeys
until somebody changes it. See
[sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md).

**Draw your own two clearly** — direction, who set it, roughly how recently, and
how many of your heroes are currently inbound to that junction.

**Draw the enemy's two as objects with no direction shown.** Not a viewer
decision: the snapshot does not contain their directions at all, so there is
nothing to accidentally render. It should be visually obvious which two are
yours.

Clicking cycles the branch — straight on, or into the connector toward the
center. Two states, so a click is not a menu.

**There are no locks on sign-posts**, so there is no lock or objection state to
draw here. Which means the one thing the viewer owes a player is a **clear,
immediate signal when a teammate changes one**: it happens without warning and it
silently redirects every hero they have inbound. It is the only unnegotiated
change any player can make to another player's plans.

## Suggested implementation steps

1. Draw each of your sign-posts at its junction node, with an arrow along its
   current branch.
2. Draw the enemy's two as plain objects, and do not accept clicks on them.
   Assert in a test that no direction is available to draw for them.
3. Write the click-to-cycle, emitting `set_signpost`.
4. Draw the heroes currently inbound to each junction as a small count beside it.
5. Announce a teammate's change loudly and briefly, and show the new direction on
   the sign for a moment afterwards.
6. Watch a match where one team uses sign-posts and the other does not, and
   confirm the difference is visible.

## Related documents and tools

- [Sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md)
- [Sign-posts stand at the corners](508-signposts-stand-at-the-corners.md)
