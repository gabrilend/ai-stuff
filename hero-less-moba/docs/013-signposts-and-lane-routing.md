# 013 — Sign-Posts and Lane Routing

**Datapath document.** Covers the three objects in the world that decide where a
body turns, and why they are objects in the world rather than buttons on a panel.

## Three posts, on the other diagonal

The two bases sit at opposite corners of the field. Put team A's at the
bottom-left and team B's at the top-right, and the three lanes are:

- **the top lane**, up the left edge and along the top, bending once at the
  **top-left corner**
- **the centre lane**, straight along the diagonal between the two bases, with
  its midpoint at the **middle of the field**
- **the bottom lane**, along the bottom and up the right edge, bending once at
  the **bottom-right corner**

Those three points — top-left, middle, bottom-right — are the **junctions**, and
they lie on the field's other diagonal, the one the bases are *not* on. A short
**connector** joins each side lane's junction to the middle. That diagonal is the
ground that used to be jungle, with everything that made it jungle removed.

**Each team has a sign-post at each junction** — three apiece, one per lane, six
in total. *Settled; see [open questions](020-open-questions.md), F16.* Every
junction carries two of them, yours and theirs, standing in the same place and
pointing wherever each team last set them. A sign-post is a piece of the world
with a position, not an entry in a menu, and players click it where it stands.

**One post per lane per team**, so the count follows the team size like
everything else about the map: four sign-posts on a two-lane match, six on a
three-lane match, eight on a four-lane match.

An earlier version of this document had **four** posts, at the near corners of
the two side lanes, two in each team's own half. That geometry had a hole in it:
the centre lane had no junction of its own, so anything that walked into the
middle could never walk out again. Putting a post *in* the middle fixes that by
construction, and drops the count from four to three.

## What a sign-post says

| Sign-post | Default | The alternative |
| --- | --- | --- |
| **top-left** | toward the enemy base | toward the centre |
| **middle** | toward the enemy base | toward the top-left, or toward the bottom-right |
| **bottom-right** | toward the enemy base | toward the centre |

A click toggles it. The default everywhere is **straight on**, so a player who
never touches a sign-post gets exactly the behaviour they would expect from a
game that did not have them.

## One turn per body, and then never again

A body arriving at a sign-post takes the branch it points at. **After that it
goes straight on at every junction for the rest of its life**, whatever the next
sign says.

That single rule is what keeps this from being a routing system. There is no
looping a body around the anti-diagonal, no chaining two posts to reach the far
lane, and no policy that steers a body twice. What the three posts amount to is:

> **the ability to move a body into a neighbouring lane, once, with a delay** —
> the delay being however long it takes to walk out to the corner.

That is worth stating as the whole feature rather than as a consequence of it. A
sign-post is a lane swap on a timer, and the timer is the walk.

## sign-post record

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Index in the sign-post array. |
| `node` | integer | The junction node it stands at. Two sign-posts share each junction node, one per team. |
| `team` | integer | 1 or 2 — whose heroes obey it, and who may set it. |
| `lane` | integer | The lane whose junction this is. |
| `branch` | integer | Node id the sign currently points at: the next node along the same lane, or the first node of a connector. |
| `set_by` | integer | Player number that last changed it, or **0** for the default. |
| `set_tick` | integer | When. Feeds the viewer's "recently changed" highlight. |

The old record carried a two-entry `direction` array indexed by a body's
`facing`, so that a sign made sense to something walking home as well as
something walking out. That is gone with the one-turn rule — a body walking home
during a calm is leaving the game and does not need steering, and a body that has
already turned ignores signs anyway.

## Who obeys

**Hero units, and nothing else.** *Settled; see
[open questions](020-open-questions.md), F16.*

- **Wave units ignore sign-posts completely** and always continue along their own
  lane. This is not an oversight. If waves could be rerouted, a team could feed
  two lanes into one and the lane structure of the map would be decorative.
  **Waves are the map's skeleton; heroes are the thing that moves across it.**
- **Guards never reach a junction**, being leashed to their tower.
- **Challenge monsters ignore them.** They walk the centre and nothing redirects
  them.

## Who may set one, and who can see it

**Any player on a team may set any of that team's three, at any time, with no
lock and no objection.** *Settled; see [open questions](020-open-questions.md),
D5.* Sign-posts are cheap, instant, and reversible, and a negotiation layer over
something undoable in one click would be ceremony with no stakes underneath it.

The three players share one set of standing orders, and every hero any of them
buys obeys it. What that leaves the viewer owing a player is **a clear, immediate
signal when a teammate changes one**: it happens without warning and it silently
redirects every hero they have inbound, which makes it the only unnegotiated
change one player can make to another's plans.

**The enemy cannot see yours.** *Settled; see D4 and F16.* Not drawn without a
direction, not drawn greyed out — not drawn. Under the networking model their
routing is not on your machine at all, which is what makes the secrecy real
rather than polite; see [players, teams, and commands](016-players-teams-and-commands.md).

Setting a sign-post is therefore **only ever an order to your own heroes.** It is
never an act against the enemy. The rejected alternative was three shared posts,
one per junction, where turning one redirected the opponent's heroes as well as
your own — the only mechanic in the whole design where two teams would act on the
same object. It is recorded rather than deleted, because it is a genuinely
strange idea and this is where to find it again.

The consequence of hiding them is that routing is concealed until it pays off. A
team that has quietly pointed all three junctions at the centre has committed
every future hero purchase to the middle, and the other side finds out when
heroes start turning up there — several purchases late, with the commitment
already a wave or two deep. **The fog is made of walking.**

What underlies all of it: **routing is something you do on the way out, before
you know what you will meet.** It is a prediction, not a correction, because a
body that has turned cannot be turned back.

## What this is actually for

Two jobs, worth naming because a player who does not see them will never touch a
sign-post at all:

1. **Concentrating a purchase.** You have bought a hero and you want it in the
   centre, but the library's automatic lane choice would send it to the top.
   Spawn it into the top lane and point that junction at the connector, and it
   walks into the middle.
2. **Standing orders.** A sign-post is not a one-shot instruction. Every body
   that passes that corner obeys it until somebody changes it. A per-body
   waypoint would be a chore repeated once per purchase; a sign is a policy set
   once and forgotten, which is the right shape for something a player has to
   manage while also managing a chest.

Related: [the map](002-the-map-and-its-milestones.md) ·
[hero units](012-hero-units.md) ·
[players, teams, and commands](016-players-teams-and-commands.md)
