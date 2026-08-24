# 013 — Sign-Posts and Lane Routing

**Datapath document.** Covers the four objects in the world that decide where
heroes turn, and why they are objects in the world rather than buttons on a
panel.

## The four corners

The side lanes bend twice each — once near either base — and the center lane runs
straight. Those four bends are the **junctions**, and each one is joined to the
center lane by a short connector. See [the map](002-the-map-and-its-milestones.md).

A **sign-post** stands at each junction. It is a piece of the world with a
position, not an entry in a menu. Players click it where it stands.

## sign-post record

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Index in the sign-post array. |
| `node` | integer | The junction node it stands at. |
| `team` | integer | 1 or 2 — which half of the map it is in, and therefore who may set it. |
| `direction` | integer[2] | Where a hero travelling each way should be sent. Indexed by the hero's `facing`. |
| `set_by` | integer | Player number that last changed it, or **0** for the default. |
| `set_tick` | integer | When. Feeds the viewer's "recently changed" highlight. |

`direction` holds a node id: either the next node along the same lane, or the
first node of the connector toward the center. Two entries because a junction is
passed in both directions and a sign that only made sense for advancing heroes
would be useless to a hero walking home.

The default for every sign-post is **straight on** — continue along the lane. A
player who never touches a sign-post gets the behaviour they would expect from a
game without sign-posts at all.

## Who obeys

- **Hero units** read the sign-post at every junction they pass and take the
  branch it names.
- **Wave units** ignore sign-posts completely and always continue along their own
  lane. This is not an oversight. If waves could be rerouted, a team could feed
  all three lanes into one and the three-lane structure of the map would be
  decorative. Waves are the map's skeleton; heroes are the thing that moves
  across it.
- **Guards** never reach a junction; they are leashed to their tower.
- **Challenge monsters** ignore sign-posts. They walk the center lane and nothing
  redirects them.

## Who may set one

Only the team whose half of the map the junction sits in. Each side has two
junctions — the near corners of its own two side lanes. You cannot set a
sign-post in enemy territory, which means you cannot reroute your heroes at the
far corners: once a hero has crossed the midpoint it is committed to the lane it
is in.

That constraint is what gives sign-posts their shape as a decision. Routing is
something you do on the way **out**, near your own base, before you know what you
will meet. It is a prediction, not a correction.

Any player on a team may set any of that team's sign-posts, and **there is no lock
and no objection** — unlike upgrades. *Settled; see
[open questions](020-open-questions.md), D5.* Sign-posts are cheap, instant, and
reversible, and adding a negotiation layer to something undoable in one click
would be ceremony with no stakes underneath it.

## The enemy cannot see which way yours point

**Sign-posts are hidden from the other team.** *Settled; see
[open questions](020-open-questions.md), D4.* You cannot read the opponent's
standing orders.

They are physical objects standing in the world, which argues for visibility, and
that argument was rejected — because it is the same argument that would make the
enemy's chest visible, and this design has consistently answered it the same way.
**You learn where their heroes go by watching heroes arrive**, not by reading a
sign. That is the same rule as everything else: the fog is made of walking, and
what an opponent knows about you is what has physically reached them.

The consequence is that routing is genuinely concealed until it pays off. A team
that has quietly pointed both of its junctions at the center has committed every
future hero purchase to the middle, and the other team finds out when heroes
start arriving there — several purchases late, and by then the commitment is
already a wave or two deep.

For the viewer: draw your own two sign-posts clearly, draw the enemy's **as
objects with no direction shown**. They exist, they are visibly there, and which
way they point is not yours to know.

## What this is actually for

Two jobs, and they are worth naming because a player who does not see them will
never touch a sign-post:

1. **Concentrating a purchase.** You have bought a hero and you want it in the
   center lane, but your library's automatic lane choice would send it top.
   Spawn it on a top-lane tower and set the near junction to point at the
   connector, and it walks into the center.
2. **Standing orders.** A sign-post is not a one-shot order. Every hero that
   passes that corner for the rest of the match obeys it until it is changed. A
   team that sets its two sign-posts toward the center at the start of a
   siege-surge has committed all of its future purchases to the middle without
   having to remember to.

The second job is the interesting one, and it is why this is a sign-post in the
world rather than a per-hero waypoint. A per-hero order is a chore repeated once
per purchase. A sign is a policy set once and forgotten, which is the right shape
for a thing a player has to manage while also managing a chest.

Related: [the map](002-the-map-and-its-milestones.md) ·
[hero units](012-hero-units.md) ·
[players, teams, and commands](016-players-teams-and-commands.md)
