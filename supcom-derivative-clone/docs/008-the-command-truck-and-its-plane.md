# 008 — The Command Truck and Its Plane

The player's presence on the field, and the one unit the player points.

## One truck, one hit

Each player has a **command truck**. The vision calls it both a command tank and
a command truck; this project uses *truck*, and the [open questions](016-open-questions.md)
page records the belief that the two names are one unit. It is a land unit, it
moves when commanded — one of the few things in the game that does — and it dies
in a single shell.

Its death is the game's stake. What losing the truck means for a match — the end
of it, as in the game this one derives from, or the loss of everything the truck
was doing — is [open](016-open-questions.md), and the working ruling is the
parent game's: a team whose last truck dies has lost.

The truck is also the natural centre of a team: engineers on energy duty raise
their buildings nearest to it, and the roster is imagined as living around it.

## The compass wheel

The truck launches a plane in a direction chosen on a **compass wheel** centred
on the truck, perpendicular to the ground. That is the whole input: a direction.
The plane flies that heading in a straight line.

A launch is a command, queued like everything else, and the truck may launch
again when its launch counter has advanced enough since the last — the
[pair of integers](003-the-tick-and-the-timers.md) again.

## What the plane does

The truck's plane is a **scout with one missile.** Along its heading it sees the
ground beneath it, and everything it sees is a **report**: an enemy unit or
building at a position, sent to the cloud, where
[unbothered planes with bombing gear](007-the-cloud.md) answer it.

It also hunts. The vision: it "attempts to eliminate enemy command units, if it
knows one is there then the next plane won't attack anything except that ...
because it can only shoot one missile at each target." The rule:

- The plane carries one missile.
- If an enemy command truck is **known** — seen by this plane, or by any earlier
  report the team holds — the plane flies to it instead of its heading and fires
  the missile at it.
- Otherwise the missile goes to the first enemy the plane sees.
- Having fired, it returns to the truck to reload, unless it can reload in the
  air, which is an upgrade the full game may have and the demo does not.

One missile per target, one target per sortie. A truck that knows where the enemy
truck is sends every plane at it; the enemy's answer is anti-air along the way.

## The scout that is free

The vision separates two things the truck does: it "flies scout planes of their
own design, free command tank unit ability," and it flies the missile plane. The
working ruling folds them into one plane that both scouts and shoots, on the
grounds that the vision's next sentence — "the moment a scout plane sees an
enemy then planes from the dogfight are encouraged to make bombing runs" — is
about what the plane *sees*, which the one plane does. Whether the full game
wants two plane kinds, a free scout and a costly hunter, is
[open](016-open-questions.md).

## Missions

| Mission | The plane is |
| --- | --- |
| heading | flying the compass direction, seeing and reporting |
| hunting | flying to a known enemy truck |
| striking | firing the missile at its target |
| returning | flying back to the truck to reload |

The truck's plane is a unit like any other — a row in the unit arrays with the
plane's domain — so anti-air shoots it, and it dies the same way.

Related: [the cloud](007-the-cloud.md) ·
[a unit](004-a-unit-and-what-it-carries.md) · [the views](010-the-views.md)
