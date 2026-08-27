# 052-formations

How a host arranges itself before it fights.

## What it is for

**The lane decides the path you take toward the enemy. It does not decide how you
are arranged when you engage.**

A host walks its lane in column while there is nothing to fight. When an enemy
comes into view — and *before* anything is in weapon reach — it leaves the path,
draws a line through the mass of the enemy, and forms its ranks parallel to that
line. Melee in front, ranged behind at their own reach, cavalry behind that to
flank whichever of the enemy's flanks is weak.

Once swords cross, cohesion stops being enforced. The formation was for getting
there.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — Allocates the per-host records. Once, at assembly. |
| `plan(world)` | | — Every host's line and slots. Once per tick, before the brain. |
| `step_to_slot(world, id)` | | `true` once the body is standing in its slot. |
| `side_of_line(world, id)` | | −1, 0 or +1 — which side of the enemy's line a body is on. |

## A host

**One team's non-guard bodies in one lane.** Not a wave — waves overlap, and two
waves fighting side by side are one battle line rather than two. Guards are
excluded because a guard is not going anywhere; it is standing on a piece of
ground it has been told not to leave.

## The line, and its two consumers

The line through the enemy's mass is not a new idea. It is already how a ranged
body with nothing to shoot decides which way to orbit — a body on the left of it
drifts left, one on the right drifts right, so both sides send their long-reach
bodies to the same flanks and they end up facing each other.

This file computes it **once per host per tick** and hands it to both consumers.
Computing it twice in two places, slightly differently, is how those two behaviours
would quietly stop agreeing about which way is left.

The axis is the principal component of the two-by-two covariance of their
positions, which in two dimensions is a **closed form** — half the arctangent of
twice the off-diagonal over the difference of the diagonals — and not something to
reach for a matrix library over.

## The per-host record

| Field | Meaning |
| --- | --- |
| `live` | 1 when there is an enemy group to form against. |
| `count` | Bodies in the host. |
| `deployed` | How many of them are near enough to have a place in the line. |
| `centre_x`, `centre_y` | The enemy group's centroid. |
| `axis_x`, `axis_y` | Along their line. Ranks are parallel to this. |
| `forward_x`, `forward_y` | Perpendicular, pointed at them. |
| `anchor_x`, `anchor_y` | Where the front rank stands. |
| `extent` | Half the width of their line. Sets how wide a rank is. |
| `depth` | How far their group reaches toward us. Sets how far short to stop. |

## Three mistakes this file has already made, kept as comments in it

**Anchoring off their centre.** Both hosts anchor against each other, so if each
front rank aims a fixed distance short of the other's *centre of mass*, and the
hosts are three hundred paces apart, each destination is behind the other's front
rank. The two lines walk straight through one another. It anchors off their **near
edge** instead.

**Taking the line through their whole host.** A host marching down a lane is strung
out over hundreds of paces, and a line drawn through all of it runs *along* the lane
rather than across it — so you form a column beside their column, which is
geometrically what was asked for and tactically nothing. "The enemy group" is the
cluster within a contact spread of their nearest body, not their tail.

**Letting the axis point along the approach.** Even with the group narrowed, two
columns that have not deployed yet reach a stable useless arrangement: each sees a
line running away from it and forms alongside. So if the computed axis comes out
more parallel to the approach than across it, the enemy has no front yet and the
host forms across its own line of advance.

## Two rules that keep it stable

**Bodies are ordered within their role by where they already are along the line.**
A body keeps its left-to-right place and nobody crosses the whole formation to
reach a slot. Without it the slots reshuffle every tick and the formation shimmers
instead of forming.

**Only bodies near the anchor deploy.** A host is not everything that shares a
lane. Bodies fresh from the library are hundreds of paces back, and giving them a
rear-rank slot — which is only a few ranks behind the front — would send them
beelining across open ground, cutting every corner the lane bends around. They
march until they are close enough to have somewhere to stand.

## How wide is a rank?

**As wide as theirs**, bounded by how many bodies there are to put in it. A host
with more bodies than the enemy's line is wide puts the surplus in the ranks
behind, which is where a numerical advantage belongs.

Note what this does *not* read: the lane's width. The world is flat and the lanes
are suggestions. What that costs is [open question G8](../docs/020-open-questions.md).

## The one place something moves without the graph

`step_to_slot` and the free movement it uses are the only motion in this game that
is not "read the next node out of an array". The body's node and progress are kept
current underneath by re-projection, so push depth stays honest and a body that
loses its formation rejoins the lane where it actually is rather than where it left.
