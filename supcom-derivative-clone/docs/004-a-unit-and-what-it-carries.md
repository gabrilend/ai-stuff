# 004 — A Unit and What It Carries

One record for everything on the field that can be shot. What it holds, how it
moves, how it aims, and how it dies.

## One record

Every unit is a row in a set of flat arrays: tanks, guns, helicopters, frigates,
command trucks, enforcers, and — in the full game — everything larger. There is
no class hierarchy. A frigate is a tank with a different domain and a different
row in the catalogue.

| Field | Type | Holds |
| --- | --- | --- |
| kind | integer | index into the unit catalogue |
| team | integer | which side owns it |
| x, y | double | position on the field |
| domain | integer | land, air, or sea — copied from the catalogue at birth |
| altitude | double | height above the ground; zero for land and sea |
| health, health_at | integer, integer | the heal pair: value written, increment written at |
| reload_at | integer | the increment the weapon last fired at |
| pattern | integer | which pattern it follows; zero for a plane, which has no pattern |
| leg | integer | which segment of the pattern it is on |
| mission | integer | for a plane: idle in the cloud, defensive, intercepting, bombing, returning |
| target | integer | the unit it is currently shooting at; zero for none |
| damage, falloff | integer, integer | copied from the catalogue at birth — see below |
| eye, profile | double, double | how high it looks from and how tall it looks |
| shield, shield_at | integer, integer | the enforcer's shield pair; zero for everything else |
| eaten | integer | mass an enforcer has consumed |

No field is ever absent. A unit with no target holds zero. A tank has a shield of
zero, not a missing shield. Whether the catalogue and the factory filled every
field is a validator's question at load, not a question the tick asks.

## Copied at birth

A unit carries copies of what it will read constantly: its damage, its falloff
curve, its pattern, its eye height. It does not hold a reference to its factory,
its team's upgrade table, or the catalogue. That is the vision's "they don't
listen after they've left the factory," arrived at from the performance side:
the firing path touches only the unit's own row, and nothing that changes later
can reach it. A tank built before an upgrade is a tank without the upgrade, and
that is the game, not a bug.

## The six kinds of the demo

The catalogue holds the numbers. What this document holds is the shape.

- **The tank** is the baseline. Everything else's toughness is measured in tank
  shells: the vision says a tank takes four, an anti-air gun three, a command
  truck one, an enforcer six with a shield that takes four more.
- **The anti-air gun** is a land unit whose weapon reaches into the air. It is
  the only thing in the demo that reliably shoots planes, and it is priced as a
  land unit and an air unit at once — equal parts of both resources.
- **The helicopter** is the demo's plane. It leaves the factory and goes to the
  cloud. It has no pattern.
- **The frigate** is the demo's ship. It moves only on water and is priced in
  both resources equally, which is the vision's rule for the sea.
- **The command truck** is the player. It moves on command — one of the few things
  that do — dies in one shell, and launches a plane. See
  [its own document](008-the-command-truck-and-its-plane.md).
- **The enforcer** is tier two and the demo's only tier-two unit. See
  [enforcers and experimentals](009-enforcers-and-experimentals.md).

Builders and engineers are **not units.** They are counts in a roster with a
health each and no position; see [the economy](005-territory-mass-and-energy.md).

## Nothing is out of range

A unit fires at any enemy it can **see** — a [sightline](002-the-dunes-and-the-sightlines.md)
from its eye to the target's profile — and there is no distance past which it may
not. What distance does is two things:

- **Damage falls off.** Each weapon has a falloff curve: full damage out to some
  distance, then a straight decline to a floor. The vision's phrase is "some have
  lower damage from far away," and the *some* is the catalogue's business — a
  tank's shell might lose most of its punch across the field while an artillery
  piece loses none.
- **The shell takes time.** A shot fired now lands at a later tick, by distance
  over the weapon's shell speed. The target may have moved. The shot resolves
  against the target's position when it lands — a shell tracks the unit it was
  fired at rather than the ground it was aimed at — which is a working ruling and
  an [open question](016-open-questions.md), because the other reading (a shell
  lands where it was aimed) makes long shots miss moving targets and turns the
  whole field into a lead-your-target game.

### Choosing what to shoot

A reloaded unit looks at every enemy in the domains its weapon reaches, keeps
the ones it has a sightline to, and picks by a fixed priority: an enemy command
truck first, then whatever is closest. It keeps that target until the target
dies, leaves sight, or something higher-priority appears. Ties break by array
order, which is stable.

Anti-air guns look only at the air. Tanks and frigates look at land and sea.
Planes have their own rules; see [the cloud](007-the-cloud.md).

## Damage is buffered, then applied

Firing does not change anything. It appends a **shot** — shooter, target, damage
at the target's current distance, arrival tick — to a buffer. The land pass walks
every shot whose arrival tick is now, in buffer order, and applies each one to
its target's health pair. Because arrival order is fixed and the buffer is walked
one-to-length, two machines land the same shots in the same order, which is what
[lockstep](011-other-players.md) requires.

A unit whose derived health is at or below zero at the end of the land pass dies
in the die pass. Death is a state, not an event: the row is marked dead, it
leaves the arrays' live count, and it becomes **bones**.

## Health comes back on a shared timer

Every unit kind heals on its own counter — the tanks' counter, the guns' counter,
the planes' counter — using the [pair of integers](003-the-tick-and-the-timers.md).
When a shell lands, the target's current health is derived, the damage is taken
off, and the pair is rewritten with the increment of now. Nothing ever walks the
units to heal them. Health is never above the catalogue's cap, and a unit is never
observed to be dead by any code but the die pass.

## Movement

A land unit follows its pattern one leg at a time, at its speed over flat
ground, slower up a slope, stopping at the water. A ship does the same on water,
stopping at the shore. A plane does not follow a pattern; it flies its mission at
its altitude, which is the ground beneath it plus its flight height, so a plane
crossing a dune climbs with it.

When a land unit reaches the end of its pattern it **holds**: it stops, and keeps
firing at whatever it can see from there. There is no chase. The pattern is
where the player put the fight, and the unit fights it there.

Two land units cannot occupy one cell. A unit whose next step is occupied waits
one tick, then tries the neighbouring cells along its leg. Whether that is enough
to keep a column from knotting on a narrow ridge is a question the proving ground
answers, not this document.

## Bones

A dead unit leaves bones: a row in a separate array holding a position and a
mass, the mass being a share of what the unit cost. Bones do nothing. Enforcers
eat them. Bones on ground that changes hands are still bones; they belong to
nobody.

Related: [the tick](003-the-tick-and-the-timers.md) ·
[factories and patterns](006-factories-and-patterns-in-the-sand.md) ·
[enforcers](009-enforcers-and-experimentals.md)
