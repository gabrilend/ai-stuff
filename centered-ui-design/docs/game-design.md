<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10,
     from notes/vision and two rounds of answers. It describes the game as
     designed; when the design changes, change this file, not a log. -->

# Game design

Words in **bold** are defined in [core-terms.md](core-terms.md).

## One sentence

A real-time strategy game where your base is the center of the world, the
controls are a glass-and-metal dashboard sitting on that base, every
instruction is told to someone by name — one click on the map, one click on
the dashboard — and travels out to them, while your team pushes outward ring
by ring against one foe in each direction.

## The screen

The **hub** is always at the center of the screen. The **console** sits on
it, large, shaped as one hump of an M — an **arch**. Its curved band is glass
through which the map is seen; beneath the band, above the base, is the
**dashboard surface**. With allies the console is one arch per ally side by
side (an M with a hump each); each player sees their own arch whole and
their neighbours' feet at the sides. See [console-layout.md](console-layout.md).
Around the console, on every side, is the map: a grid that really lies on a
sphere, drawn flattened into a circle so that every tier is visible at once
(see [datapath-accordion-view.md](datapath-accordion-view.md)).

Units on the map are small figures made of spheroids — body, head, two arms,
two legs — whose limbs bend (deform, never swing rigidly) as they walk.

The dashboard surface has two kinds of part, and they never mix:

1. **Order buttons** — bright, painted, round or half-round. They are the
   only things on the dashboard the player clicks.
2. **Dials** — information only. A dial is a disc no thicker than paper,
   turning beneath a seamless glass window cut into the dashboard. The player
   never sees a whole dial, only the part under its window: a month name, a
   weekday, a number, a count. The player never turns a dial; the game turns
   it. The dial is a generic component used all over the dashboard.

There are lots of dials and lots of numbers. The numbers do not look like
buttons; they look like bare surface under a glass viewer.

## Giving an order: always tell someone

There are no menus, no right-click commands, no drag-boxes. Everything that
happens is an instruction told to someone:

1. Click **on the map** — on the stand (the person or group) you are telling.
2. Click **on the dashboard** — the order button for what they should do.

Then back to the map, then back to the dashboard. Always exactly one, then
the other. Building a building is telling an engineer to build it. Attacking
is telling a stand to attack.

This is on purpose. The dashboard is large, and sits in the middle. Every
order brings your eyes back to the center, and every time they come back,
they pass over the surrounds — so you see the whole state of your world many
times a minute, redirect your focus, and train your short-term memory of
where everything is.

Once given, a **courier** leaves the hub and runs out to the stand; the order
only takes effect when it arrives. The courier is visible on the map. If the
situation changes while it travels, you tell the stand something new and a
second courier follows the first.

Order kinds (first set): advance, attack, hold, fall back, flank left, flank
right, deploy shield (plant a glass shield dome where the stand is, which
others can fall back behind and then press out from the side of), follow
(the next map click names whom), build (engineers), dismantle (engineers),
adventure (heroes).

The vision's own example of why transit matters: "okay now everyone flank
left" — "okay deploy those shields and fall back on that other front then
press out from the side of the shields". Each of those is several orders,
one per stand, each with its own courier, each arriving at its own time.

## Seeing far: merged stands

Far from the hub, and wherever many units crowd together, units merge on the
map into one marker carrying two numbers: their **average level** and their
**count**. The marker's color shows the balance of the fight it is
contesting (how its strength compares to the threat it faces), and small
triangles beside it show the same difference by shape — pointing up and more
numerous when ahead, down when behind — so the information never depends on
seeing color.

## Production

Factories are built by telling an engineer to build one. When a factory is
built its **waypoint path** is set once and then locked. Every unit the
factory makes walks that path when it leaves, then joins a stand at the end
of it. To change a locked path, tell engineers to dismantle the factory
(they walk there, and work for a time), get back part of its cost, and
rebuild something else with a new path.

## The team table

A team is 1 to 4 (later more) **stand-ins**, each owning one quadrant. In
hot-seat play one person switches between stand-ins; seats not being played
keep running their standing orders.

The team shares one treasury. Two kinds of vote decide how it is spent:

- **Distribution vote** — for each resource, each stand-in proposes how it
  should be split (between production, upgrades, heroes, reserve). The result
  is the weighted average of the proposals, where each proposal counts as much
  as that stand-in's **priority weight** for that resource.
- **Next-purchase vote** — candidate purchases are listed; each stand-in
  spreads their weight across the ones they want; the top one is bought when
  affordable.

Every stand-in has the same total weight to spread across ballots, so caring
a lot about one resource means caring less about another.

The **calendar** paces the table: votes (among other things) happen on its
boundaries. A dial shows the month and the weekday; one level lower, a
number. A button beside it switches the calendar's pace between day and
month; some players will press it often and routinely.

## Center to outer, and below

In every direction there is one foe. The foe's forces sit in tiers: an outpost
at tier 1, a bigger one at tier 2, and so on. A **front** is decided when one
side's outpost at the current tier falls.

When a front is decided, **both** sides **level up**: each gains resources and
is offered choices. The winner advances: the next fight in that direction is
against the foe's next tier out, played by the same foe, who has levelled up
too — differently, because they chose differently.

Side-to-side movement is the flanking game: forces sent around the circle to
help a neighbouring quadrant's front, or to hit a foe from the side.

**Heroes** are told to adventure a number of tiers deep. They fight, gather
aether and return.

The map is not to scale. Each tier band takes about the same time to cross
(**tier-time**). The circle on screen is a distortion of a grid that lies on
a sphere: the hub at one pole, tiers as bands of latitude outward from it.
The sphere has two faces — the surface, and the inside: the **underworld**,
where (in the w7 world's prehistory) the monsters were pushed, holding their
own realm.

The map is not linear: no lanes. Terrain in each band is generated.

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
- A choice can be **held** for later. The model is Symbeline's, which takes
  it from City of Heroes: you **slot enhancements** into powers and **dole out
  inspirations**. A held choice that is an enhancement for a power you do not
  have yet waits in your tray; when the power is acquired, it slots in and
  strengthens it. (See [open-questions.md](open-questions.md).)

## Art

No AI-generated artwork. Units and buildings are small 3D models. Effects —
auras, shields, sparks, magic — are clouds of very small voxels, each placed
by a formula rather than drawn by hand, and hidden when not directly in view
of an opponent. An aura keeps enough saturation to read from far away.

The scene sits impossibly far from the camera and is still rendered
accurately: a very long lens, so the world looks almost flat and evenly
scaled like a map, with the precision problems that distance brings solved
rather than ignored (see [visual-language.md](visual-language.md)).

## Players

Phase by phase: first hot-seat with AI foes; AI teammates for unplayed seats;
then networked play where each stand-in can be a different person on a
different machine. See [roadmap.md](roadmap.md).
