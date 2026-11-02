# 072-the-movement-patterns

Every way a body can want to move, as a table of rows.

## What a pattern is allowed to do

**Place a goal and a pace. Nothing else.**

It may not move a body, may not look at whether anything is standing in the way, and may
not know how fast the body will actually travel. It answers one question — *where do I
want to be* — and everything from there belongs to
[the layer underneath](034-walking.info.md).

That restriction is the entire design. Keeping *where I want to go* apart from *where I
may actually stand* is what lets eleven different behaviours share one mover, and it is
why a pattern can be tested by running one tick and asking where the goal landed, with no
world full of other bodies and no question of whether the body arrived.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `pattern` | *(table)* | The rows, by name. Each has `name` and `place(world, id)`. |
| `order` | *(table)* | Which rows are tried, in which order. |
| `choose(world, id)` | | The row that applied, having placed that body's goal. |

A row's `place` returns `false` for "this does not apply to me right now", which is how
the chooser walks down the order, and `true` once a goal is placed.

## The rows

| Pattern | Places its goal at | Pace |
| --- | --- | --- |
| `leash` | a guard past its rope: the node it is leashed to | hurry |
| `chase` | a guard's target's **skin**, pulled back to the end of its rope | hurry |
| `patrol` | a guard's next node, chosen from the neighbours inside its leash | relax |
| `withdraw` | the far end of its lane, off the map | hurry |
| `charge` | its target's **skin**, or its target structure's | hurry |
| `march` | its place in its wave's formation | relax or normal |
| `lane_walk` | a few paces down its own lane | normal |
| `hold` | its own feet | normal |

The three guard rows come first in the order, and nothing else ever matches them: each asks
for a leash node, which only a guard has — an integer test rather than a flavour test, as
[304](../issues/304-guards-are-leashed.md) asks, so a monster or a hero that should one day
be leashed needs a leash node and nothing more.

**`patrol` is the one row that asks the graph**, and the one row that writes anything but a
goal: on reaching the node it was aiming at, it picks the next. That is a choice of where to
want to be rather than a move, which is this table's question. `leash` and `chase` aim
straight at where they are going, because both destinations are inside the guard's own
ground. See [the walking module](034-walking.info.md) for what "reaching" a node means, and
for why `patrol` and `chase` aim at the side of a building rather than through it.

**`chase` stops at the rope.** A guard's strike point further from its leash node than its
leash allows, less a body's room, is pulled back onto that circle. A guard walks to the edge
of its ground and waits there, rather than stepping over the line, being walked home,
re-acquiring and stepping over it again — which is what makes the edge of a tower's ground a
hard line rather than a gradient. The leash still trips a guard that ends up outside by being
shoved; it no longer walks there on purpose.

## Three things the table changed

**The Golem is a row, not an exception.** It walks and it attacks whatever it walks into
and it stops for neither. That used to be a test near the top of a function with a
paragraph asking somebody to find it before wondering why the Golem parks. Now it simply
never matches `march` — a body that cannot die has no formation to dress — and falls
through to walking its lane, which is the whole of the explanation.

**A charge aims at the skin, not the middle.** Aimed at the centre, a charging body wants
to occupy its target: it is moved off that ground every tick by the rule about standing on
people, and shoves back at a third again its own speed. In a crowded fight that pressure
was enough to leave two bodies a sixteenth of a pace inside each other, which was
measured, and it is the same sentence the range check already makes.

**The order is a list rather than a sequence of returns.** What this replaced was nine
early returns inside one function, every one correct, where the order between any two of
them was a decision nobody had written down. It is still an order and still policy — what
changed is that it is now a thing a person can read, and that two patterns which could
both apply have to be resolved out loud.

## What is still positional

`choose` walks the order top to bottom and takes the first row that applies. Whether that
should stop being a walk down a list, and become something the brain writes down when it
decides what a body is doing, is M4 in
[the umbrella issue](../issues/216-movement-is-a-goal-and-a-step.md) and is not answered.
Keeping the same order as the returns it replaced is what made the change provably
behaviour-preserving before anything was redesigned.
