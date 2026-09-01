# The Delve

A mode, not a phase of the aquarium. Humans and dinosaurs go into the maze
together, and the maze has things in it that will kill them.

## What was asked for

> *"another mode where it's humans and dinosaurs trying to solve Dungeons and
> Dragons monsters. The humans can ride the dinos and the dinos can use weapons.
> But only when they're navigating the dungeon. This one has stone golems, vine
> monsters, and wooden machine automatons (not steam powered, but with fire
> powers like 'ignite' and not like 'fireball')"*

**"Solve" was meant loosely.** The monsters are enemies with health and the party
fights them. That was asked and answered; the alternative — a monster as a lock
whose key is another monster — is written up in
[open question 3](026-open-questions.md), which records both readings and which
one was chosen.

What survives from the other reading, and survives because it was worth having on
its own terms, is that the three monsters are made of different things and are
hurt by different things.

## The chart

Every monster has a `resist` field: a multiplier per damage type.

| | blade | fire | blunt | |
| --- | --- | --- | --- | --- |
| **golem** | 0.20 | 0.00 | 1.00 | stone. Only weight tells. |
| **vine** | 1.00 | 3.20 | 0.35 | a plant. Fire ruins it; a hammer pushes it about. |
| **automaton** | 1.40 | 2.60 | 1.80 | wood. Everything works, and fire works well. |

And what the party brings:

| | carries | good against | useless against |
| --- | --- | --- | --- |
| **human** | fire — a torch | vines, automatons | golems |
| **dinosaur** | weight — a heavy weapon | golems, automatons | vines |

**Neither one alone is an answer to all three.** That is the whole of what makes a
party a party, and it is a table rather than a rule.

## The fighting is the fencing

Two bodies of opposing sides that can hurt each other start a **duel** — the same
record, the same buffered damage, the same four endings, the same camera verdict
as two fencers in [phase five](017-fencing.md). Generalising that machinery
beyond fencers is what turned this mode from a design into a running thing in an
afternoon: it already existed, it already worked, and it already had tests.

Each side uses its **own** numbers. A duel between two fencers is symmetric and
it did not matter; a duel between a human with a torch and a stone golem is not,
and reading both sides' stats off whichever body happened to be stored first
would give the golem a human's skill depending only on array order.

## The party

- **Humans** — one cell wide, go anywhere, weak, and carry the only fire the
  party has.
- **Dinosaurs** — several cells wide, cannot fit down every corridor, strong, and
  their weapon has **reach two**: they can strike a body two cells away, which
  means they can fight down a corridor they cannot themselves enter.

That difference is the mode's geometry. The corridors the humans can use alone
are the ones the dinosaurs cannot follow them down; the plazas where a dinosaur
is useful are the open ones where everything can see everything.
[Riding](022-riding-and-being-ridden.md) is what lets a party choose between them.

## "Only when they're navigating the dungeon"

Riding and dinosaur-borne weapons belong to this mode. A dinosaur in
[the habitat](019-dinosaurs-in-a-habitat.md) is an animal playing games; a
dinosaur in the delve carries a weapon and a rider.

In practice this needs no flag anywhere: a dinosaur's combat numbers are in its
row all the time, and outside the delve there is nothing of another side to swing
at, so nothing happens. **A mode is which creature kinds spawn.** It is not a
branch in the simulation, and no file under `src/` other than the creature table
names one.

## Ignite is a state, not a projectile

The distinction was made explicitly and it decides how fire is built.

A **fireball** is an event: it happens at a place, at a moment, and it is over. It
would be a function call.

**Ignite** is a state that persists and spreads. A body that is burning stays
burning, loses fuel every tick, and sets fire to flammable things beside it —
which is a `burn` pass in [the tick](010-the-tick.md), sweeping what is alight,
decrementing its fuel, buffering its damage into the same accumulator the duels
use, and rolling to spread.

| Burns | Does not burn |
| --- | --- |
| vine monsters | stone |
| wooden automatons, including the one that started it | golems |
| humans, a little — they carry things that burn | the maze |

**The automaton does not check whose side you are on.** It is a machine; it sets
alight whatever flammable thing is beside it. Restricting it to the other side
was the tidy thing to write and it silently deleted the best behaviour in the
mode, because the automatons and the vines are both monsters — so nothing ever
lit a vine, and a wooden machine standing in a thicket it had ignited stopped
being possible.

Three things fall out of fire being a state that nobody wrote, and the third is
the test of whether it was built at the right level:

1. **The automaton burns.** It catches from the fire it started, and there is a
   test asserting that with no code path called "self".
2. A burning corridor is a corridor nobody wants to use, which is terrain.
3. Something flammable carried past a burning thing catches, and can be carried
   elsewhere.

All three survived the mode being rewritten from a puzzle into a fight, which is
most of the argument for having built fire this way: none of it was ever about
who was fighting whom.

## What the delve reuses unchanged

The stone, the generator, the projection, the renderer, the camera, the body
store, the tick, the locomotion table, sight, meeting, games, and **the duels**.
The delve adds creature rows, one locomotion row that turned out to be an
existing one with different numbers, three tick passes, and a table of
multipliers.

## Related documents and tools

- [Riding and being ridden](022-riding-and-being-ridden.md)
- [The monsters of the delve](023-the-monsters-of-the-delve.md)
- [Fencing](017-fencing.md) — the duel machinery this mode fights with
- `./run-maze --scene delve`
