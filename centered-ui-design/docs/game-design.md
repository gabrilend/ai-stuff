<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10,
     from notes/vision and the first round of answers. It describes the game
     as designed; when the design changes, change this file, not a log. -->

# Game design

Words in **bold** are defined in [core-terms.md](core-terms.md).

## One sentence

A real-time strategy game where your base is the center of the world, the
controls are a great glass-and-metal wheel sitting on that base, and your
team pushes outward ring by ring against one foe in each direction while
every order you give takes time to reach the front.

## The screen

The **hub** is always at the center of the screen. The **command wheel** sits
on it, large — a third or more of the screen's height. Around the wheel, on
every side, is the map, squeezed by the **accordion** so that the nearest
**tier** is wide and the far tiers fold in toward the screen edge.

The wheel is three things stacked like a watch:

1. The **rim** — a ring of sectors with writing in them. It rotates like a
   lazy susan. The sector under the **pointer notch** is selected. On the rim
   are the stands of the current **quadrant**; turning the rim chooses which
   **stand** the next order goes to.
2. The **face** — the inner disc, holding the bright round **order buttons**
   in arcs and half-circles, and many **readouts** (resource counts, transit
   times, stand strengths) shown as bare metal under glass.
3. **Complications** — windows cut through the face onto lower discs. The
   **calendar complication** sits on the arc: a word (day of week, or month)
   in the window, a number on the disc below it, and a button that flips
   between day mode and month mode.

Near the sides of the screen sit two scrolling dials for the accordion,
**reach** and **squeeze**, and the **depth dial** for heroes.

## Giving an order

Always the same two steps, and always in this order:

1. Turn the rim until the stand you want is under the notch (it may already
   be there).
2. Press an order button on the face.
3. Click a spot on the map.

The order is given. One button, one click, one order, one stand. A **courier**
leaves the hub and runs out to the stand; the order only takes effect when it
arrives. On the map the courier is visible as a moving spark, so you can watch
the order travel. If the situation changes while it travels, you can send
another order after it.

Order types (first set): move, attack-move, hold, fall back, flank left, flank
right, deploy shield (the stand plants a glass shield dome at the clicked
spot, which other stands can fall back behind and then press out from the
side of), follow (another stand).

The vision's own example of why transit matters: "okay now everyone flank
left" — "okay deploy those shields and fall back on that other front then
press out from the side of the shields". Each of those is several orders,
one per stand, each with its own courier, each arriving at its own time.

## Production

Each quadrant builds **factories** near the hub. When a factory is built its
**waypoint path** is set by clicking points on the map; once confirmed, the
path is locked. Every unit the factory makes walks that path when it leaves,
then joins a stand at the end of it.

To change a locked path you must send **engineers** to the factory to
dismantle it (they take time to get there, and time to work), get back part of
its cost, and rebuild something else in its place with a new path.

## The team table

A team is 1 to 4 (later more) **stand-ins**, each owning one quadrant. In
hot-seat play one person switches between stand-ins; seats not being played at
the moment keep running their standing orders and a helper AI.

The team shares one treasury. Two kinds of vote decide how it is spent:

- **Distribution vote** — for each resource, each stand-in proposes how it
  should be split (between production, upgrades, heroes, reserve). The result
  is the weighted average of the proposals, where each proposal counts as much
  as that stand-in's **priority weight** for that resource.
- **Next-purchase vote** — candidate purchases are listed; each stand-in
  spreads their weight across the ones they want; the top one is bought when
  affordable.

Every stand-in has the same total weight to spread across ballots, so caring
a lot about one resource means caring less about another. The **vote cadence**
(how often the table votes) is set from the calendar complication.

## Center to outer

In every direction there is one foe. The foe's forces sit in tiers: an outpost
at tier 1, a bigger one at tier 2, and so on. A **front** is decided when one
side's outpost at the current tier falls.

When a front is decided, **both** sides **level up**: each gains resources and
is offered choices. The winner advances: the next fight in that direction is
against the foe's next tier out, played by the same foe, who has levelled up
too — differently, because they chose differently.

Side-to-side movement is the flanking game: forces sent around the circle to
help a neighbouring quadrant's front, or to hit a foe from the side.

**Heroes** are sent adventuring with the depth dial: "go three tiers out and
come back". They fight, gather aether and return.

The map is not to scale. Each tier band takes about the same time to cross
(**tier-time**), so a force far out appears to move faster. Transit is still
real: the further the front, the longer every order takes to arrive.

The map is not linear: no lanes. Terrain in each band is generated, with open
ground, walls, narrows and high ground, so fronts look different from each
other.

## Choices and balance

The balance goal is Mechabellum's: everyone has the same number of choices,
of roughly equal value, at every level-up.

- The **choices** themselves are generated at the start of a game from a
  seed. Each choice is built by spending a fixed value budget across its
  stats, so no choice is worth much more than another.
- Choices are drawn through **roll tables**: each entry has a chance to come
  up, and when it does, a second set of percentages picks which value.
- An **offer** gives each side the same count of choices, and the offer
  generator re-rolls until every side's total value is within a small margin
  of the others.
- A choice may have a **price** in metal and glass, or need an **unlock**
  bought with aether, or both.
- A choice can be **held** for later. A held choice that needs an unlock not
  yet owned waits; when the unlock is bought, every held choice that needed it
  strengthens it.

## Players

Phase by phase: first hot-seat with AI foes; AI teammates for unplayed seats;
then networked play where each stand-in can be a different person on a
different machine. See [roadmap.md](roadmap.md).

## Open questions

These are interpretations made while turning the vision into this design.
Each is still to be talked through. See
[open-questions.md](open-questions.md) for the full list.
