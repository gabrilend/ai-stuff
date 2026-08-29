# 213 — What the Lane Can Afford

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 207, 211c |
| Blocks | — |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md), [waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md), [upgrades slotted into stone](../docs/010-upgrades-slotted-into-stone.md) |
| Open questions | H10, H11, H12 |

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

### The draw is a lottery with three thumbs on the scale

Each lane has **its own resource table and its own meter per unit type**. Each wave:
work out how much there is to distribute, then draw.

| Thumb | Effect |
| --- | --- |
| **Recency** | a unit chosen more recently has **fewer** tickets, so a lane does not field the same thing eight waves running |
| **Scarcity** | a unit that costs more, when there is less to spend, has **more** tickets |
| **Arrangement** | what has been slotted into the lane's stone makes certain units more likely, with all the resource costs that implies |

The scarcity thumb is the surprising one and it is deliberate: being poor makes the
expensive thing *more* likely, not less. What it produces is a lane that cannot go
quiet — a run of cheap waves builds toward something.

### Doubling up

**If a unit's meter ever reaches twice its maximum number of tickets, one of that
unit spawns automatically**, without needing to win the draw. It can still win the
draw as well, so a wave can contain two of a type — and never more than two.

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

Three questions, all of which change what gets built.

**H10 — is the purse per lane per team, or per lane?** "Each lane has a different
resource table" could be three purses or six. Six is the obvious reading and means
each side's lanes evolve independently; three would mean the two teams draw against a
shared lane character, which would be a strange and interesting thing.

**H11 — what fills the purse?** Nothing in the description says where the resource
comes from. Candidates: a fixed income per wave; income that scales with how well the
lane is doing; income from kills in that lane. The third is the one with teeth and
also the one that snowballs.

**H12 — what does "more tickets when we have fewer resources" do at the extremes?**
Taken literally, a lane with almost nothing has an enormous ticket count for the most
expensive unit it cannot possibly afford. Either the tickets are capped, or affording
it is a separate check after the draw, or the draw is over what is affordable and the
thumb only reorders within that.
