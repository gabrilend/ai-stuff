# 007 — The Cloud

The air war does not happen on the field. It happens in a cloud above it, and the
player watches it through a small window.

## The cloud is a place

Somewhere above the field — the working ruling is above its centre — there is a
**cloud**: the place every plane goes when it has nothing else to do. It looks,
the vision says, like a big cloud with a swarm of fighters flying around in it.
That is what it is: a swarm, not a formation, and its state is a list of planes
with a mission each rather than positions that matter.

A plane leaves its air factory and flies straight to the cloud. It has no pattern
and is given no destination. From the moment it arrives, what it does is decided
by the cloud's own rules, below, and by reports that reach it.

## Rounds on a counter

The cloud fights in **rounds**, on a counter like every other periodic effect.
When the round counter fires, the cloud pairs off opposing planes that are in it
and resolves each pair: the stronger plane, by its **air strength**, wins on a
draw from the `cloud-round` stream weighted by the strength difference, and the
loser takes damage. Air strength is what a team's plane upgrades add up to, and a
plane copies its team's strength at birth — a plane built before an upgrade is a
plane without it.

That is the vision's "depending on how they upgrade the planes, they'll fight
better or worse accordingly." The cloud is where evenly-matched air forces grind
each other down.

## Fight or avoid

Before each round, every plane compares its strength to the strength of the
enemy planes in the cloud:

- If its side is **weaker**, it leaves the cloud and becomes **defensive**: it
  flies over friendly territory and does not seek combat. The vision: "if they
  don't have good air combat abilities compared to their foes, then they'll avoid
  combat."
- If its side is **stronger**, it seeks out enemy planes and **intercepts** them
  — in the cloud if they are there, and over their own ground if they have gone
  defensive.

The second half is the point. **Defensive planes fly over friendly territory,
where anti-air can be stationed.** An interceptor that follows them there is a
plane over enemy ground, and every anti-air gun with a
[sightline](002-the-dunes-and-the-sightlines.md) to it fires. Winning the cloud
does not win the air; it moves the fight to where the guns are.

## Reports send bombers

A [scout](008-the-command-truck-and-its-plane.md) that sees an enemy reports the
position. The report reaches the cloud, and any plane there that is **suitably
unbothered** — not engaged in a round, not defensive — and **has the requisite
bombing gear** leaves on a **bombing run** to that position, drops on it, and
returns. In the demo every plane has the gear; in the full game it is an upgrade.

A bombing run is a flight over the field at altitude, and anti-air along the
way fires at it. A plane that arrives drops its bomb on the reported cell:
damage to what is there, and a claim on the ground, which is how the air war
reaches the [roster](005-territory-mass-and-energy.md).

## Anti-air

An anti-air gun is a land unit whose weapon reaches the air. It shoots at any
plane it can see: interceptors over its ground, bombers on their runs, scouts
passing over. It does not shoot into the cloud, because the cloud is above the
centre of the field and the working ruling is that it is out of every gun's
sight — a question [marked open](016-open-questions.md), because a cloud that
can be shelled from below is a different air war.

## What the player sees

A small window — television inside the television — that the player opens on
the cloud. It shows the swarm, coloured by side, and reads as a mood: crowded or
thin, one colour or two, calm or churning. The window is a
[view](010-the-views.md) like any other and reads the snapshot; on the handheld
it is the obvious tenant of the second screen.

## Missions

A plane's mission is one of a fixed set, indexed, and each mission is a row in a
dispatch table that decides its movement this tick:

| Mission | The plane is |
| --- | --- |
| to-cloud | flying from its factory to the cloud |
| in-cloud | in the swarm, fighting rounds |
| defensive | over friendly ground, avoiding combat |
| intercepting | pursuing a named enemy plane |
| bombing | flying to a reported cell |
| returning | flying back to the cloud after a run |

Adding a mission is adding a row. The command truck's plane has missions of its
own, in [its document](008-the-command-truck-and-its-plane.md).

Related: [a unit](004-a-unit-and-what-it-carries.md) ·
[the economy](005-territory-mass-and-energy.md) · [the views](010-the-views.md)
