# 009 — Enforcers and Experimentals

The big things. One of them is in the demo; the rest are designed now so that
the demo's price points and record shapes are built to hold them.

## The enforcer

The vision's optional unit, and the demo's only tier-two unit: an AI walker that
"walks forward like a hero and can reclaim the bones of enemies."

- **It is tall.** Its eye and profile heights are the largest of any land unit,
  so it sees over crests that hide a tank and is seen over them too. The vision:
  "they are taller than tanks, and so should be carefully placed." Its pattern is
  therefore the most important drawing a player makes.
- **It eats.** When an enforcer stands near [bones](004-a-unit-and-what-it-carries.md),
  it consumes them, and the mass goes two ways: to the team's treasury, and to
  the enforcer's own **upgrade**. The proportion is set at the factory when its
  line is laid — a dial from all-to-treasury to all-to-upgrade — and, like the
  pattern, is not changed afterwards. "The more they consume, the more they can
  upgrade, and you can set the proportion at the factory."
- **It claims with ease.** Its claim radius is larger than a tank's, so an
  enforcer walking a ridge paints ground as it goes and pays for itself in mass.
- **It carries a cannon on its arms**, and its head "often put them in danger
  before they can use the cannon" — which in this simulation is exactly the
  height rule: it is seen before it sees, because its profile is taller than its
  eye. That is a catalogue relation, not a special case.
- **It has a shield**: a sphere around it that protects allied units inside the
  sphere as well as itself. The shield is a health pool on its own recharge
  counter — the [pair of integers](003-the-tick-and-the-timers.md) — that
  absorbs shots aimed at anything inside the sphere until it is down, then
  recharges when it has not been hit for long enough. The vision's numbers: the
  enforcer takes six tank shells, its shield four more.

What an enforcer's upgrade *does* — more health, more damage, a bigger sphere,
all three — is [open](016-open-questions.md).

## Everyone has the same experimentals

The vision's rule: no faction-specific experimentals. Every team can build the
same set, and each one "takes one attack pattern and maximizes its impact."
Each costs a thousand of the resource its alignment leans on.

| Experimental | Maximises | Shape |
| --- | --- | --- |
| artillery | range | a gun whose falloff curve is flat: full damage at any distance it can see |
| gunship | damage | a plane that ignores the cloud and flies a pattern, dealing the largest single hit in the game |
| land carrier | utility | a factory that moves |
| underwater carrier | utility | a factory that moves, submerged, and surfaces to unleash aircraft |
| air factory | utility | a carrier for bombers: builds bomber patterns, moves up close, unleashes |

The artillery is worth a note, because "maximises range" in a game where nothing
is out of range means something specific: its shells lose nothing to distance,
and it is the one weapon whose sightline is not from its own eye but from any
friendly eye — it fires at what the team can see. That is a working ruling and
an [open question](016-open-questions.md).

## The carrier builds while it moves

The land and underwater carriers are the design that most needs the record
shapes to be right from the start, which is why they are designed now.

A carrier is a **factory with a pattern**. It follows the pattern like a unit,
and while it is moving it is **constructing, for free**: its line runs without
drawing mass or energy, and the units it finishes stay inside it. When it stops
— at the end of its pattern, or because it is held — its contents **swarm out
and attack**, following the carrier's own attack pattern from where it stands.

Unless it is marked **keep hold**, in which case its contents stay inside even
when it is standing still — until the carrier is attacked, whereupon they spawn
and attack whatever attacked it. Both the flag and the patterns are set when
the carrier's line is laid.

The underwater carrier is the same machine on the sea, submerged while moving,
which puts it out of every sightline that is not a torpedo's; it surfaces to
unleash and is a frigate-sized target while it does.

The air-factory experimental is the same again for bombers: it builds bomber
patterns while moving, moves up close to the enemy, and unleashes them on
[bombing runs](007-the-cloud.md).

## Submarines and torpedo planes

Not in the demo. The full game has both, and they are the counter to the
underwater carrier — which, the vision notes, can otherwise only be contested by
anti-air once it has surfaced. They are a phase-five issue that is blocked by
the demo's completion, not by any design question.

Related: [a unit](004-a-unit-and-what-it-carries.md) ·
[factories](006-factories-and-patterns-in-the-sand.md) · [the cloud](007-the-cloud.md)
