# The Delve

A mode, not a phase of the aquarium. Humans and dinosaurs go into the maze
together, and the maze has things in it that were put there to be **solved**.

## What was asked for

> *"another mode where it's humans and dinosaurs trying to solve Dungeons and
> Dragons monsters. The humans can ride the dinos and the dinos can use weapons.
> But only when they're navigating the dungeon. This one has stone golems, vine
> monsters, and wooden machine automatons (not steam powered, but with fire
> powers like 'ignite' and not like 'fireball')"*

The word the whole mode turns on is **solve**. Not fight, not kill, not defeat.
A monster here is read as a lock rather than as a health bar, and a party
carrying no answer to a stone golem does not lose the fight — it has no fight to
have, and must go around, or go and find the answer.

That reading is an interpretation of one word and it might be the wrong one.
It is written down as [an open question](026-open-questions.md), and the design
below is what follows if it is right.

## Monsters as locks

Each monster has a **solution**, and the solutions are each other. See
[the monsters](023-the-monsters-of-the-delve.md) for what each one is; the shape
of it is:

| Monster | Made of | Undone by | Which is useful for |
| --- | --- | --- | --- |
| stone golem | the maze itself | being held still | opening walls, because it walks through them |
| vine monster | growing plant | fire | holding things still, because it entangles |
| wooden automaton | wood, and it sets things alight | being smashed | fire, because it is the only source of it |

Read the last column downward and it is a cycle: the golem breaks the automaton,
the automaton burns the vines, the vines hold the golem. A party's job is not to
out-damage any of them. It is to get them into the same room.

That cycle is not an invention layered on top of what was asked for. It is what
falls out of three monsters that are respectively stone, plant, and *flammable
wood that starts fires*, once you take seriously that the third one's power is
`ignite` and not `fireball`.

## Ignite is a state, not a projectile

The distinction was made explicitly and it decides how fire is built.

A **fireball** is an event: it happens at a place, at a moment, and then it is
over. It would be a function call.

**Ignite** is a state that persists and spreads. A body or a cell that is
burning stays burning, loses something every tick, and sets fire to flammable
things beside it. That is a `burn` pass in [the tick](010-the-tick.md) — one row
inserted before `resolve` — sweeping a list of burning things, decrementing their
fuel, and rolling to spread.

| Burns | Does not burn |
| --- | --- |
| vine monsters | stone |
| wooden automatons, including the one that started it | golems |
| whatever a party is carrying that is flammable | the maze |

The automaton burning is the important row. A machine whose power is to set
things alight, made of wood, in a corridor full of vines it has just ignited, is
a machine that has solved itself. Nothing enforces that; it falls out of fire
spreading to flammable neighbours and the automaton being one.

## The party

A party is a small set of bodies that share a goal and are indexed together. Two
kinds in it:

- **Humans** — one cell wide, can go anywhere, weak
- **Dinosaurs** — several cells wide, cannot fit down every corridor, strong

That difference is the mode's whole geometry. The corridors the humans can use
alone are the ones the dinosaurs cannot follow them down; the terraces where a
dinosaur is useful are the open ones where everything can see everything. A
party moving through the maze is constantly choosing which of those it wants.

[Riding](022-riding-and-being-ridden.md) is what lets them choose the other one.

## "Only when they're navigating the dungeon"

Riding and dinosaur-borne weapons belong to this mode and not to
[the habitat](019-dinosaurs-in-a-habitat.md). A dinosaur in the habitat is an
animal playing games; a dinosaur in the delve carries a weapon and a rider.

That is the reading taken, and it is a reading — the sentence could also mean
that a dinosaur carries its weapon while walking and puts it down to fight,
which would be a strange rule but is a possible one. Recorded in
[open questions](026-open-questions.md); the mode flag is written so that either
answer is a one-line change.

## What the delve reuses unchanged

Everything. The stone, the generator, the projection, the renderer, the camera,
the body store, the tick, the locomotion table, sight, meeting, and games. The
delve adds rows: creature kinds, locomotion rows, meet-table entries, one tick
pass, and one game.

If the delve needed to change any of the above rather than add to it, that would
be a finding about the earlier design rather than a requirement of this one, and
it would be worth stopping over.

## Related documents and tools

- [Riding and being ridden](022-riding-and-being-ridden.md)
- [The monsters of the delve](023-the-monsters-of-the-delve.md)
- [Two bodies meeting](016-two-bodies-meeting.md) — where a delver meets a monster
