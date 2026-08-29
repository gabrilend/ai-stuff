# 213 — What the Lane Can Afford

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 207, 211c |
| Blocks | — |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md), [waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md), [upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md) |
| Open questions | none |

## Current behavior

Every wave in every lane is the same wave: four melee, two ranged, one captain, from
a table with three numbers in it. The only thing that differs between two lanes is
what upgrades have been slotted into their stone, which changes how strong those
seven bodies are and never changes **which** seven bodies they are.

There is one melee body and one ranged body in the whole game. No equipment, no
weight, no variety, and nothing anywhere that decides a wave's composition.

## Intended behavior

**A wave is drawn, not specified.** Each lane keeps a purse and a set of meters, and
what walks out of the base is what the lane could afford and happened to draw.

### The units

Five kinds, and the differences are equipment rather than statistics:

| | Carries | Stands |
| --- | --- | --- |
| **Heavy infantry** | the full weight of it | the middle of the line |
| **Light infantry** | usually a spear and leather. Sometimes a shield, sometimes a sword, sometimes both. Sometimes a metal cap. | the sides of the line, where it can flank |
| **Skirmishers** | short reach — enough firepower to disable whatever comes near, and no more | the shoulders, shooting **around** the line |
| **Archers** | long reach, artillery. These are the ones that genuinely shoot **over** a line, across a glen. | behind |
| **Cavalry** | — | not built. Later. |

Everybody wears gloves and boots.

Heavy infantry are the extreme of the scale and should read that way: nearly
invincible killing machines, expensive, and rare because of it.

**Heavy toward the centre, light toward the sides.** That is not decoration — light
infantry are on the sides *so they can flank*, which is a thing they will do once a
formation can turn. See [211c](211c-a-formation-is-a-circle-that-faces.md).

### Equipment is randomised, and the cost is what feeds back

A body's kit is drawn when it is born: which of the several things a light infantry
might be carrying, whether it has a cap. **Heavier equipment costs more, lighter
costs less**, and the cost is not spent by a player — it is spent by the lane,
against a hidden purse that decides what the lane can raise next time.

That is the whole loop. Nothing about it is visible as a number; what a player sees
is that a lane which has been fielding heavy infantry starts fielding lighter ones,
and a lane that has been cheap for a while can suddenly afford something.

### The draw is a deck, and cost is paid in discards

Not a weighted roll. **A deck of tickets**, and the more resource a lane has the more
tickets go into it.

- Drawing is taking the **top card**.
- Whatever unit that card names, **N more tickets are drawn and discarded**, where N
  is that unit's resource cost. An expensive choice eats the deck.
- When the deck runs out, it is reshuffled.
- After each wave, the discards are reshuffled and placed **below** the tickets that
  have not been drawn yet.

Cost is therefore not a price checked against a balance. It is **how much of the deck
a choice consumes** — an expensive unit does not have to be affordable, it has to
have enough deck left, and having taken one you have less of everything for a while.
That is what makes a run of cheap waves build toward something, without any rule
saying so.

Two of a kind can walk out together and never three: **if a unit's meter reaches
twice its maximum ticket count, one of that unit spawns automatically**, without
needing to be drawn — and it can still be drawn as well.

### The shuffle, which is not a shuffle

A **pile shuffle**, in a fixed sequence: deal into 3 piles and concatenate, then 4,
then 5, then 4, then 7. The odd counts may be reordered between shuffles — 5, 7, 3
next time — but **every other pass must be a pile of four.**

Not perfectly uniform, very close, and **deterministic given the pile counts**, which
is worth a great deal in a project whose first invariant is that the same seed plays
the same match.

The alternative — inserting the discards back into the waiting deck at random
positions, one by one — was rejected for a precise reason. It *guarantees* the first
cards are evenly distributed, and a guarantee is a worse kind of non-uniformity than
a tendency.

### What the upgrades do

**They are what fills the purse**, and this is the whole reason the mechanism exists.
An upgrade slotted into a lane does some mixture of:

- **`+1 ticket per wave` for a specific unit entry** — that unit turns up more often
  in this lane.
- **`+1 resource per wave`** — more tickets in the pool overall, which means more
  troops or heavier ones. Because the draw distributes by *least recently seen*, more
  is always straightforwardly good.
- **Unlocking a new entry, usually at the cost of an old one** — usually the one it is
  taking the equipment from.

The third is the interesting one. A swordsman with a shield and an iron cap finds a
magic blade: if the swordsman entry costs 3, then **3 tickets leave the swordsman
entry and 3 arrive at the magic swordsman entry**, and N resources are added, where N
is the cost of the sword in particular — perhaps one point per, for three in total.

So an upgrade is not a bonus applied to a lane. It is a change to what that lane
**raises**, and where the new thing came from is visible in what stopped turning up.
Distribute the upgrades differently and different troops walk out of the base.

### Whose purse

**One per lane per team** — six on the map as it stands. The number is lanes times
two rather than players times two: the lane count is a parameter, and a larger map
with more lanes than players is a thing that might happen.

## Suggested implementation steps

1. Add the unit types to the catalogue as archetypes, appended rather than
   renumbered, so nothing that already refers to an archetype by number moves.
2. Add an equipment table: what a body of each type might be carrying, and what each
   piece weighs. Cost follows weight.
3. Give each lane a purse and a meter per unit type, in the team record, and a
   per-team named random stream for the draw. Everything random here has to come from
   a named seeded stream or the replay breaks on its first tick.
4. Write the draw as a ticket count per unit, built by the three thumbs above, and
   pick from it. A dispatch table of thumbs rather than a chain of adjustments, so
   adding a fourth is adding a row.
5. Spend the drawn units' equipment cost out of the lane's purse, and let the purse
   refill on whatever cadence the wave interval sets.
6. Place the drawn units by **bearing**: heavy at small angles, light toward the
   flanks, skirmishers on the shoulders, archers behind. The layout already works in
   bearings, so this is a band per type rather than new geometry.
7. Test the loop rather than the numbers: over a long match a lane should field a
   mixture rather than one thing; a lane that has fielded heavy infantry should be
   measurably poorer afterwards; and no wave should ever contain three of a type.

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [Waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md)
- [211c](211c-a-formation-is-a-circle-that-faces.md), whose bearings this places by
- The headless runner's census, which is where "what did this lane actually field"
  gets measured

## Still open

Nothing blocking. H10, H11 and H12 are answered above.

What is not specified and will need deciding when it is built: how many tickets a
unit starts with, what a resource point is worth against a piece of equipment, and
what the maximum ticket count per entry is — the number the doubling rule doubles.
Those are balance and belong in the ledger rather than here.
