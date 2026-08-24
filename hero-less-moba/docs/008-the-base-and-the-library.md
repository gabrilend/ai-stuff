# 008 — The Base and the Library

**Datapath document.** Covers the far end of the map: how a base is laid out, the
building that ends the game, and the rule that decides which lane a soldier
spawned on the library walks toward.

## Layout

A base is the wedge of ground where all three lanes meet. It contains:

- **Three base guard towers**, one at milestone index 1 of each lane — that is,
  at the mouth where each lane enters the base. They are ordinary towers.
- **One library**, standing behind all three of them, reachable only by crossing
  the open interior. There is no path that reaches the library without passing a
  base tower's node first, though a soldier can pass *outside* the arrow radius
  of two of the three.
- **The spawn point** for that team's waves, which is the library's node. Waves
  leave the library, fan out into the three lanes, and never come back.

The interior is one open space, not three corridors. That is what makes base
guards able to answer any lane — see [guard towers](007-guard-towers-and-their-guards.md).

## The library

| Property | Value |
| --- | --- |
| Health | About one and a half guard towers' worth. |
| Armour | None. Same as a tower. |
| Attacks | Nothing. It is a building, not a defence. |
| Regenerates | No. |

**When a library's health reaches zero, the team that destroyed it wins, and the
match ends on that tick.** There is no second objective, no throne behind it, and
no comeback after it falls.

The health figure is a ratio, not a number — one and a half towers — and it is
stored that way in the balance table so that retuning tower health retunes the
library automatically. A validator checks the ratio holds; do not copy the
absolute figure into prose anywhere, including here.

That ratio is worth a sentence of design commentary, because it is smaller than
players will expect. In most lane-pushers the final building is the toughest
thing on the map by a wide margin. Here it is barely tougher than the stone in
front of it. The effect is that a base breach is very close to a loss: once the
towers are down, a team does not get a long grinding defence of the core, they
get about one wave's worth of grace. This is deliberate — a game whose whole
premise is "the frontline must move" cannot afford a fortress at the end of it.

### If both libraries would fall on the same tick

They are resolved in the same buffered damage pass, so it can happen. The rule
is **a draw**, recorded as such. Picking a winner by team number would mean team
1 wins ties forever, which is the kind of invisible asymmetry that only ever gets
discovered by the player it kept losing to. This is a ruling, not something the
vision addresses; it is on the [open questions](020-open-questions.md) list.

## The library as an upgrade slot

Upgrades cannot be slotted into base guard towers directly. Instead, an upgrade
can be slotted into the **library**, and it applies to all three base guard
towers at once. The vision calls this rare and says it usually only happens when
all the lane towers are already destroyed — which is to say, it is the shape of
a last stand. The mechanics are in
[upgrades slotted into stone](010-upgrades-slotted-into-stone.md).

## The library as a spawn point, and the lane it picks

A player may spawn a hero unit on the library. When they do, the hero has to pick
a lane, and the rule is: **walk toward the lane where the enemy has pushed
deepest**, measured in milestones.

The vision is emphatic that this is not a distance question — "not in terms of
distance as-the-crow-flies, but rather in terms of milestones thru the map." The
worked example it gives: a lane where the enemy is one step past your first tower
is *less* urgent than a lane where the enemy is inside your base, even though the
base is physically nearer the library. A straight-line check picks the wrong lane
in exactly the case where picking wrong matters most.

The lookup is:

1. Read the enemy team's push depth for each of the three lanes — three integers
   the team record already maintains.
2. Take the largest. Ties are broken by lane number, low first, deterministically
   and without touching a random stream, so that a player watching two equally
   pressed lanes can predict where their hero will go.
3. The hero enters that lane's path at the library node and walks outward.

It re-evaluates nothing after that. A hero that walked into the top lane stays in
the top lane unless a sign-post at a junction tells it otherwise. Chasing the
worst lane continuously would make heroes wander, and a wandering hero is a
wasted purchase.

Related: [the map](002-the-map-and-its-milestones.md) ·
[guard towers](007-guard-towers-and-their-guards.md) ·
[hero units](012-hero-units.md) ·
[upgrades slotted into stone](010-upgrades-slotted-into-stone.md)
