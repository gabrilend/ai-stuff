# 068-the-arena

A small straight square of ground, and a world with only the machinery a test asked for.

## What it is for

See [the proving ground](../docs/024-the-proving-ground.md) for the strategy. This file
is the two halves that make it possible: a map small enough to hold one rule, and an
assembly that hangs a **named subset** of the cast on a world and nothing else.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `build(parameters, options)` | `options.length`, `.width`, `.files` | A map: one straight lane, left to right. |
| `parameters(base, options)` | | The match parameters with the arena's shape laid over them. |
| `assemble(modules, base, want, options)` | `want` is a list of module names | A world with those modules hung on it. |
| `put_a_formation(world, team, along, melee, ranged, heading)` | | The wave id. |
| `put_a_body(world, team, along, across, archetype)` | | The body's id — a stray, in no formation. |
| `verb` | *(table)* | What an arena test may arrange. |

## The ground

One straight lane, no bend, no stone, no junction, no bases. It carries the **real**
milestone count, zone divisions and node structure, so nothing downstream can tell
which builder made it — a body walking here walks under the same numbers it walks under
in a match.

Straight on purpose. A lane's curve is real and has its own instrument in
[the formation sandbox](../tests/060-the-formation-sandbox.info.md); a test about
stepping round an obstacle that is *also* cornering has two candidates when it fails.

The arena is wider than its road by a full lane width on every side. That margin is
where a body goes when it steps aside, and an arena that ran out of room at the edges
would be answering a different question from the one it was built for.

## The subset assembly

`want` names modules as the tick's own cast names them. Those are hung; **nothing else
is**, and reaching for something absent is an error at the moment of reaching rather
than a background influence on a measurement.

Four things are hung whatever a test asks for, because a body cannot come into being
without them and no test is about their absence: the world's own allocate and release,
the event channel, the map builder — which is geometry, not a system — and two empty
lists of boons, because every body reads what its team has won on the way into
existence and an arena has a phase clock nowhere. Borrowing the phase module to get
those lists would also start the phase clock, and a movement test that ran long enough
would silently turn into a siege-surge halfway through.

The spatial grid is built only if `targeting` was asked for, because that is where it
lives. **A scene that wants the frontline queue must name targeting**, and no body in
it ever picks a target — which is a true statement that misleads, so a scene that does
this says so in its note.

## Heading is separate from team

`put_a_formation` takes a heading — +1 for rightward, −1 for leftward — defaulting to
the one the team implies. They come apart on purpose. Making two groups walk into each
other by giving them different teams also switches on every rule about enemies, and
then the picture is of a fight rather than of two bodies of troops sharing a road.

This is what turned up the fact that the formation's own advance re-derived direction
from the team instead of reading the heading off the wave record it had been carrying
all along — identical for every wave the game raises, and wrong for the first wave
anything else raised.

## The arrangement vocabulary

The same shape as [the gate's](063-the-gate.info.md) verb table, taking the world and the
rest of the row, because a test on a short straight road and a test on a whole map should
be arranged by the same kind of sentence.

| Verb | Says |
| --- | --- |
| `formation <team> <along> <melee> <ranged> [heading]` | a body of troops standing that far down the road |
| `body <team> <along> <across> [archetype]` | one body on its own, in no formation: the stray |

Adding something an arena test can arrange is adding a row here, next to the thing being
arranged, rather than a function inside a test file.

## The arena no longer has a tick

It used to. `march_tick` called the same three functions the real brain calls to march a
body, in the same order, and [the proving ground document](../docs/024-the-proving-ground.md)
stated the cost of that plainly: a second place in the project that knew marching is
grid-then-plan-then-step, which would quietly be testing something else the day the real
one grew a fourth step.

That is gone. The march loop lives in [the walking module](034-walking.info.md) beside
the single step it repeats, [the tick](042-the-tick.info.md) has a named row for it, and
a test names the stages it wants. The arena builds ground and puts bodies on it, and
nothing here has an opinion about what a tick is.
