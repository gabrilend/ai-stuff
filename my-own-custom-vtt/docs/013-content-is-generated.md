# Content is generated

No wall in this project is typed in by hand. Maps, dungeons, towns, patrol
routes, and the props scattered through them all come out of generators, and the
generators are the thing that gets maintained.

The rule underneath it: **make the tool, not the thing.** A hand-edited map is a
map nobody dares regenerate, and a map nobody dares regenerate slowly stops
matching the tool that made it, until eventually the tool is abandoned and every
map is hand-edited. That process takes about two months and is very hard to
reverse.

## A description in, a world out

A generator reads a **description** -- a small declarative file saying what kind of
place this is and how big and how connected -- and writes the arrays that
[the map](006-the-map-is-geometry-not-a-picture.md) describes: walls, regions,
lights, and things.

The chain is deliberately staged, and each stage is a separate program:

| Stage | In | Out | Why it is its own stage |
| --- | --- | --- | --- |
| **Validate** | The description | Accept, or a sentence naming what is wrong | A bad description should fail before anything expensive, and fail by saying which field and what was expected. |
| **Lay out** | The description, a seed | Rooms and corridors as an abstract graph | This is where the interesting decisions are, and it is easier to reason about a graph than about geometry. |
| **Realise** | The graph | Wall segments, region polygons | Turning topology into coordinates. Mechanical, and testable against the graph it came from. |
| **Furnish** | The geometry, the ruleset's catalogue | Things standing in it | Lights, doors, crockery, patrols. Needs to know what a tavern contains, which is the ruleset's business, not the layout's. |
| **Write** | Everything above | The world file the server loads | One format, one writer. |

Splitting layout from realisation is the load-bearing one. Nearly every question
worth asking about a generated dungeon -- is it connected, is there a loop, is the
treasure behind the guard -- is a question about the graph, and is answerable in a
few lines against the graph and nearly unanswerable against a pile of segments.

## The same seed gives the same map, forever

A generator takes a seed and is otherwise deterministic. Same description, same
seed, same world, byte for byte, on any machine.

This is not a nicety. It is what lets a map be *referred to* rather than *stored*:
a description plus a seed is a few hundred bytes that names a whole dungeon
exactly. A GM can hand that to somebody. A test can assert against it. A bug
report can include it.

The same discipline as the ruleset's, for the same reason -- named streams, no wall
clock, no unordered iteration. See [the rules layer](011-the-rules-layer.md).

## Generated does not mean random

Most of what a generator does is obey constraints, not roll dice. "This tavern
has a cellar", "the forest has exactly one clearing", "no corridor is longer than
this" are all statements in the description, and the generator's job is to produce
something satisfying them, using randomness only where the description does not
care.

A generator that ignores its description and produces noise is not a generator, it
is a random number visualiser. So the validator runs *after* generation too,
checking the output against what was asked for, and failing loudly when they
disagree.

## What a GM does instead of drawing

If nothing is hand-placed, what does a person do when they want a specific room?

They **edit the description and regenerate**, and if the description cannot say
what they want, that is a missing feature in the description language and it gets
added there. The `EDIT_WORLD` command from
[commands](010-commands-enter-through-one-door.md) exists for the live case --
knocking a hole in a wall mid-session because somebody cast a spell -- and those
edits are recorded as commands, in the log, on top of a generated world.

So a session's world is always "this description, this seed, plus these edits",
and all three parts are small, and none of them is a binary blob nobody can
regenerate.

## Where a wandering generator gets its taste

A generator needs to know that a tavern has tables and a bar, and that is
game-specific knowledge, so the catalogue of what-furnishes-what lives in the
ruleset directory beside the rules. Swap the ruleset and the same layout
generator furnishes a spaceship instead of a tavern, because the layout stage
never knew what a tavern was -- it produced a room with a certain shape and a
certain connection to its neighbours, and something else decided that meant a bar.

## Read next

- [The shape of the code](014-the-shape-of-the-code.md).
- [The roadmap](015-roadmap.md) -- when each stage above gets built.
