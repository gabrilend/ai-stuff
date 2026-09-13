# 005 — Territory, Mass, and Energy

Minimal resources; the focus is on inflows and outflows. This is the whole
economy: where mass comes from, where energy comes from, what construction
consumes, and what losing ground costs.

## Territory is painted on cells

Every cell of the [field](002-the-dunes-and-the-sightlines.md) has an **owner**:
nobody, or a team. Ownership is painted by presence. When a unit stands within a
claim radius of a cell for long enough, uninterrupted, the cell becomes its
team's. "Long enough" is an increment count on the claim counter, so a claim in
progress is a cell storing the increment it began at — the
[pair of integers](003-the-tick-and-the-timers.md) again.

A cell already owned by the other team takes the same time to flip. A cell with
units of both teams near it does not flip at all; it is contested, and stays as
it was until one side leaves. Enforcers claim with a larger radius, which is the
vision's "they can claim territory with ease."

A team's **territory** is its cell count over the field's land cell count, as a
percentage. Water is never owned. Everything below reads that percentage.

## Territory implies mass

Mass is the metal that units are made of, and it comes from ground held.
Every tick, a team's mass income is its held cells times the mass a cell pays.
There is nothing to build to get it and nothing to protect except the ground
itself. Take ground and the income arrives; lose it and the income leaves.

Mass and energy can be spent on **improving territory** — the vision's one
sentence on it. What an improvement does, and whether it is per cell or per
team, is [open](016-open-questions.md); the working ruling is that an
improvement is a per-cell level that raises the cell's mass payment, bought with
both resources, and lost with the cell.

## Energy is built on the ground and lost with it

Energy generation is a **building**, placed with build power on a held cell. It
pays energy every tick while it stands and while its cell is held. If the cell
changes hands, the building is gone — the vision's "when losing territory, you
lose the energy that was built while that part of territory was controlled by
your guys." Energy buildings are naturally spread out because they are placed
where the ground is, and each one is a small bet on holding a place.

Some cells are **hydrocarbon**: bonus chunks of energy in the ground, raised by
the dune tool at a rate given by a shape parameter. Finding one — a scout report
or a claim — buffs the *next* energy building the team builds, wherever it is
built. The buff is spent when that building finishes.

## The energy menu is four buttons

The vision's always-open menu: **four buttons that decide how many of a team's
engineers are put toward energy.** Nothing else is on it, and nothing else should
ever be — the moment it grows a fifth button the economy has become a menu.

The four buttons are four **assignment levels**: none of the engineers, a third,
two thirds, all of them. Engineers on energy duty do two things: they raise
energy buildings on held ground without being told where (nearest hydrocarbon
first, then nearest to the command truck), and they operate what stands.
Engineers *not* on energy duty are build power for everything else. So the
four buttons are one lever, and it trades construction speed against energy
income, and that is the whole decision.

The level is a command like any other, queued and applied at its tick.

## Builders and engineers

Two kinds of labour, both counted in a **roster** rather than standing on the
field:

- **Builders** are trivial: cheap, fast to make, and contributing build power
  and nothing else. A team makes more whenever it wants.
- **Engineers** take time and effort to make. They contribute build power *or*
  energy, by the menu, and they are the thing a team cannot easily replace.

Each roster member has a health, on a roster-recovery counter of its kind. That
matters because of what losing ground does.

## Losing ground costs bodies

When a team's territory falls by a percentage, **the same percentage of its
builders and engineers are hurt.** Lose four percent of the ground, and four
percent of the roster takes damage — random members, chosen on a named stream.
They heal slowly on their counter, and faster when there are many engineers,
because engineers repair each other. A roster member at zero is gone.

This is how an air war reaches the backline. Planes that get through take ground
under nobody's guns, and every percent taken is a percent of the labour force in
the infirmary. See [the cloud](007-the-cloud.md).

<!-- toy: ground -->

## Thorns

Build power can be turned into **defences**: a capacity, held by the team, that
hurts whoever takes its ground. For every percent of territory an enemy claims,
the thorns deal a fixed damage to the units doing the claiming — and lose a share
of their capacity in doing it. Thorns are spent by being used; a team that loses
half its ground has lost half its thorns as well as the half that were spent
hurting the takers.

The full game will have many kinds of tower. The demo treats thorns as one
artillery-like capacity with no position: the damage lands on the claimers of
the cell that flipped, wherever it is. Where thorns are *placed*, and whether
they have positions at all, is [open](016-open-questions.md).

## Construction is a stream, not a purchase

Nothing is paid for up front. A line building a tank draws the tank's mass and
energy across the ticks it takes to build, in proportion to the build power
working on it. If the team's mass or energy runs dry mid-build, the build stalls
until income arrives, and everything else being built stalls with it, in
proportion — this is the streaming economy of the game this one derives from,
and it is what makes overbuilding a visible mistake instead of a hidden one.

**Build power** is the roster's builders plus the engineers not on energy. It is
split evenly across everything under construction. More things building means
each one builds slower, never that one is starved for another.

## The cost table is a shape

The vision gives the costs as ratios, and the ratios are the design:

| Alignment | Mass : energy |
| --- | --- |
| land | ten to one |
| air | one to ten |
| sea | ten to ten |
| land that shoots air | equal parts |

Tier two costs a hundred of whichever resource its alignment leans on; an
experimental costs a thousand. The demo's tank is a land unit and so leans on
mass; its helicopter leans on energy; its frigate and its anti-air gun pay both.

The magnitudes are catalogue numbers and are not written here. The vision's
first guesses at them are in the catalogue as starting values and in the
[balance ledger](balance-updates.md) as they change. The invariants — that a
land unit's mass is ten times its energy, that a tier-two unit costs ten times
its tier-one cousin, that an anti-air gun pays equal parts — are what the tests
assert, and they hold no matter what the magnitudes become.

<!-- toy: costs -->

Related: [factories](006-factories-and-patterns-in-the-sand.md) ·
[the dunes](002-the-dunes-and-the-sightlines.md) · [the cloud](007-the-cloud.md)
