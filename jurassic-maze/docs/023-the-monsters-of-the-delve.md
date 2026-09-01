# The Monsters Of The Delve

Three of them. Each is a lock, and the key to each is one of the others.

## The stone golem

Made of the maze. It is not standing in the corridor, it *is* corridor, walking.

**Locomotion: `lumbering`.** The row that raises the climb limit and lets a body
break a wall rather than route around it. A golem that meets stone it cannot
climb clears the bits and walks through, and the surfaces for those columns are
recomputed on the spot. It is the only thing in the project that changes the
stone after generation, which is why
[the surface array](002-the-stone-and-what-is-inferred.md) is recomputed rather
than assumed constant, and why nothing anywhere caches the graph.

**Its solution is to be held still.** Nothing a party carries hurts stone. A
golem that is entangled stops, and a stopped golem is a wall — one that is
standing somewhere it was not before, which is occasionally exactly where a party
wanted a wall.

**What it is for.** A golem walks through walls. A party that arranges to be
behind one when it does gets a route that the generator never carved. It is the
mode's only way of changing the maze, and it is a monster rather than a tool
because it does not care what the party wanted.

## The vine monster

**Locomotion: `creeping`.** It moves along walls rather than along floors,
ignoring the drop limit entirely — a vine falls down a cliff face and keeps
growing. Its stance is a surface like anything else's; what differs is which
neighbours it considers, and it considers vertical faces.

**It entangles.** A body it reaches is held: its locomotion is suspended and it
does not move until the hold is broken. That is the same mechanism as
[a duel](017-fencing.md) — a record referencing two bodies with generations —
because being held and being in a fight are the same shape of thing.

**Its solution is fire.** It is the most flammable thing in the maze and it is
the only monster with a solution that is not another monster's body.

**What it is for.** Holding the golem.

## The wooden machine automaton

Not steam powered. It is a machine made of wood, and its power is **ignite**.

**Ignite is a state.** It sets a body or a cell burning, and burning persists,
consumes fuel, and spreads to flammable neighbours. It is not a projectile, it
has no travel time, and there is no explosion. See
[the delve](021-the-delve.md) for the `burn` pass this needs.

**It is made of wood.** So it burns. So an automaton standing in the vines it
just set alight is an automaton that has solved itself, and nothing in the code
arranges that — it falls out of fire spreading to flammable neighbours and the
automaton being one of them.

**Its solution is to be smashed.** Wood against a stone fist.

**What it is for.** It is the only fire in the maze. A party with a vine problem
and no automaton has no answer, and has to go and find one — which is what makes
this a mode about routing rather than about fighting.

## The cycle, stated once

| This | Undoes this |
| --- | --- |
| golem | automaton |
| automaton | vines |
| vines | golem |

Three monsters, three solutions, no fourth thing needed. A party's contribution
is not damage. It is **arranging the meeting** — getting two monsters into one
place, which means knowing where they are, knowing the maze, and being able to
survive the trip. Which is what
[riding](022-riding-and-being-ridden.md) and
[the party's two body sizes](021-the-delve.md) are for.

## What the party can actually do

Not nothing, but not much directly:

- **Move.** Being somewhere is most of it.
- **Lure.** A monster that can see a body follows it. Line of sight is
  [already built](018-line-of-sight-through-stone.md), and luring is walking
  where you can be seen.
- **Block.** A dinosaur with a long weapon holds a corridor, which decides which
  way a monster goes.
- **Carry fire.** Once something is burning, something flammable carried past it
  catches, and can be carried elsewhere. The `burn` pass does not care what is
  holding the burning thing.

That last one is the whole spread mechanic reused as a party ability without
being written as one, which is the test of whether the fire model was built at
the right level.

## Related documents and tools

- [The delve](021-the-delve.md)
- [Riding and being ridden](022-riding-and-being-ridden.md)
- [Locomotion is a dispatch table](012-locomotion-is-a-dispatch-table.md) — `lumbering` and `creeping`
