# 006 — Factories and Patterns in the Sand

A tank game built with a factory game. What a factory is, what a line is, and
how a route drawn once governs everything that ever leaves.

## A factory is a line you did not design

The vision's phrase: production lines that "you don't have to design them,
they're already pre-factored built. just construct them." A **factory** is a
building on a held cell with a **domain** — land, air, or sea — and a **line**:
an ordered list of unit kinds it produces, drawn from the catalogue of lines the
game ships with. The player picks a line the way a player of the parent game
picks a factory type; the player does not compose it.

A line is a queue. It produces its entries in order, and when it reaches the end
it starts again unless it was placed as one-shot. Each entry draws mass, energy,
and build power as a [stream](005-territory-mass-and-energy.md), and emits the
unit when the stream has delivered the whole cost.

A sea factory must sit on the shore — a land cell with water beside it — and its
output appears on the water. An air factory's output goes to
[the cloud](007-the-cloud.md) and follows no pattern. A land factory's output
follows the pattern below.

Factories are placed with build power like anything else, and a factory under
construction is a factory with no line yet. Placement is a command; it carries
the cell, the domain, the line, and the pattern, all at once, because the
pattern must exist before the first unit does.

## A pattern is drawn once

When a land or sea factory is placed, the player **draws in the sand** the route
its output will take: a list of points on the field, in order, starting at the
factory. That is the pattern. Every unit the factory ever emits carries a copy of
it and walks it leg by leg, and when it reaches the last point it holds there and
fights.

**The pattern cannot be redesigned after it is laid.** Not edited, not extended,
not re-pointed. The vision is explicit and it is the design: a player who
cannot fiddle with a route has to think about the route before drawing it, which
is what turns a real-time game into a planning game. To send units somewhere
else, build another factory and draw another pattern.

What can be done afterwards is **stop the line** — a command that halts the
factory's production without touching its pattern — and **resume it**. A stopped
factory's units keep following the drawing they left with.

The pattern is validated when the placement command is applied: every point must
be on the field, a land pattern must not cross water and a sea pattern must not
leave it, and the first point must be the factory's cell. A pattern that fails is
a refused command, named to the player, and the factory is not placed. Nothing
is repaired.

## What a unit does with a pattern

A unit copies the pattern's points at birth and remembers which **leg** it is on.
Each tick it moves along the current leg at its speed, adjusted for slope,
turning to the next leg when it reaches a point. It fires at whatever it can
[see](002-the-dunes-and-the-sightlines.md) the whole way. It does not stop to
fight, does not chase, does not turn back. At the end it holds.

The vision's "land units engage according to patterns drawn in the sand ... they
can't re-design it after it's done, so they're encouraged to take the most
strategic attack routes they can find" is the whole tactical game: a route along
a trough is safe and slow and sees nothing; a route along a ridge is fast and
seen from everywhere. The player chooses, in advance, with a finger.

## Everything can be queued

The vision calls this an invariant and it is enforced as one. **Every** command —
a factory placed, a line stopped, an energy level chosen, a truck moved, a plane
launched — is a record with a tick stamp, appended to one queue, applied at its
tick. There is no command that takes effect on the instant it is issued. The
[network](011-other-players.md) is built on this: a command stamped for a later
tick can arrive from anywhere before that tick and the game does not care where.

## Few things can be moved

The command truck moves on command. Nothing else does. Not units, which follow
patterns; not factories, which are buildings; not the roster, which has no
position. This is the rest of the vision's sentence: "Everything can be queue'd
up, this is an invariant. Few things can be moved, like command trucks."

## What the demo ships

Lines for the six demo kinds, one factory domain each, and the enforcer's line
as the demo's single tier-two production. The experimentals'
[carriers](009-enforcers-and-experimentals.md), which are factories that move,
are designed but not in the demo.

Related: [a unit](004-a-unit-and-what-it-carries.md) ·
[the economy](005-territory-mass-and-energy.md) · [the views](010-the-views.md)
