# The Monsters Of The Delve

Three of them. Each is made of something different, and what each is made of is
what decides how to kill it.

## The stone golem

Made of the maze. It is not standing in the corridor, it *is* corridor, walking.

**Locomotion: `lumbering`** — which turned out to be the ordinary walking step
with `breaks_stone` set and a larger drop limit in its creature row. A new way of
moving was a new row of numbers rather than a new function, which is what
[the locomotion table](012-locomotion-is-a-dispatch-table.md) was for and was not
guaranteed.

**It walks through walls.** A golem that meets stone it cannot climb takes one
layer off the top of it, and its column and the four around it have their
surfaces recomputed on the spot. It is the only thing in the project that changes
the stone after generation, and it is the reason for two decisions made in phase
one that cost nothing at the time: the surface array is *recomputed* rather than
assumed constant, and nothing anywhere caches the surface graph. A cached graph
would be a second copy of the maze to invalidate right here.

It takes the top layer off rather than boring through, so the columns stay
height-shaped and the validator's check for that still passes. A golem that bored
a tunnel through the middle of a wall would be the first thing in the project to
make a column with a hole in it — and that check has been waiting since phase
one for exactly that day.

**Fire does nothing to it. A blade chips it. Weight tells.** A party without a
dinosaur is not going to win this one.

Two things about it took finding, and both are recorded where they happened. It
counted its work on the shared `timer` field, which is also the idle clock — the
idle reset it before it ever reached the threshold, so no golem ever broke a
wall, with nothing raised and nothing in any counter. And a three-by-three golem
can never be *adjacent* to a wall, because its own footprint keeps it a cell
away; it reaches one cell past itself, which is also what lets it make its own
space.

## The vine monster

**Locomotion: `creeping`** — the walking step with a drop limit of ninety-nine. A
vine falls down a cliff face and keeps growing, because a drop is not a problem
for it.

**It entangles.** A body it reaches is held: it cannot move and it cannot swing,
which is the one thing in the mode that stops a fight rather than deciding it. A
held body is a body anybody can hit.

The hold is a clock on the body rather than a row in the locomotion table, so it
works for anything that can be held rather than only for the kinds somebody
remembered. It is the same shape as a duel and a shared idle — the third instance
of a record with a clock and participants held by generation.

**Fire ruins it.** Three and a bit times over. It is the most flammable thing in
the maze, and the party's torches are what it is for.

## The wooden machine automaton

Not steam powered. A machine made of wood, and its power is **ignite**.

**Ignite is a state, not a projectile.** It sets a body burning, and burning
persists, consumes fuel and spreads. There is no travel time and there is no
explosion.

**It does not check whose side you are on.** It is a machine; it sets alight
whatever flammable thing is beside it. That is both what it should do and what
makes the best thing in the mode possible — because it is *made of wood*, and a
machine standing in a thicket it has just ignited catches fire from its own work.

Nothing in the code arranges that. It falls out of fire spreading to flammable
neighbours and the automaton being one of them, and
`tests/066-the-delve.lua` asserts it happens with **no code path called "self"**.
If there had to be one, the fire model was built at the wrong level.

**Everything works on it**, and fire works well. Wood splits under a blade, burns
readily, and ends under a stone fist.

## The chart, stated once

| | blade | fire | blunt |
| --- | --- | --- | --- |
| golem | 0.20 | 0.00 | 1.00 |
| vine | 1.00 | 3.20 | 0.35 |
| automaton | 1.40 | 2.60 | 1.80 |

A human carries fire; a dinosaur carries weight. Neither is an answer to all
three, which is what makes a party a party.

The numbers live in each monster's `resist` field in the creature table and
nowhere else. This table is the same thing gathered up so a person can read it,
and it will go stale the moment somebody tunes one — so the creature table is
what to trust.

## Related documents and tools

- [The delve](021-the-delve.md)
- [Riding and being ridden](022-riding-and-being-ridden.md)
- [Fencing](017-fencing.md) — the duel machinery all of this fights with
