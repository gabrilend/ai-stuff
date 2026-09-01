# What This Is

A maze made of stacked stone, drawn from one fixed corner-on angle, with a
simulation living inside it that nobody is playing and nobody wins.

The maze is the constant. What moves around inside it is not, and that is the
whole arrangement: one piece of geometry, built once and understood thoroughly,
and then a succession of increasingly alive things put into it to see what
happens. Balls first, because a ball is the simplest thing that can be wrong in
an interesting way. Then people, then people with swords, then dinosaurs, then a
mode where humans ride the dinosaurs into a dungeon and fight things made of
stone and vine and burning wood.

It is called jurassic-maze because the reference picture has volcanoes in it.

## The thing on the screen

A very large rectangle of stone, seen corner-on, so that it reads as a diamond.
The stone is not one solid mass — it is layers, stacked, each layer a flat sheet
of rectangular blocks laid on the one below. Where a column of that stack is
tall, you see a wall. Where it is short, you see a floor. The corridors are the
short places, running between the tall ones, and staircases are the places where
the height changes one layer at a time so that something with legs can climb it.

Nothing inside the stack is ever represented. If a block is buried under three
other blocks, the program has no opinion about it, does not draw it, and does
not simulate it. **Only the exposed top surfaces and the exposed side faces
exist.** The interior is inferred, which is a decision about data structures
disguised as a decision about scenery — see
[the stone and what is inferred](002-the-stone-and-what-is-inferred.md).

## What lives in it

Nothing here is trying to accomplish anything. There is no exit, no score, no
end condition, and no run that can be said to have finished. It is an aquarium.
The measurements that a test takes off it — how many bodies got stuck, how far
the average one travelled, whether anybody fell through the floor — are
diagnostics about whether the machinery works, not outcomes of a game.

The things that live in it arrive in this order, and each one is a phase:

| What | What is new about it |
| --- | --- |
| Balls | Continuous motion. Real velocity, gravity down a slope, rebound off a wall face, and falling off a ledge onto whatever is beneath. |
| Little guys | Motion as a walk on a graph, smoothed for the eye. Idling. Two of them noticing each other. |
| Fencers | Two bodies agreeing to be in a duel, and a duel being a thing with a beginning and an end. |
| Dinosaurs | Bodies that are bigger than one cell. Seeing, and not being seen. Games with rules the creatures follow without being told. |
| The delve | Humans and dinosaurs, together, against stone golems and vine monsters and burning wooden automatons. Humans ride. Dinosaurs carry weapons. |

Those five are not a sequence of replacements. They accumulate. A ball still
rolls correctly after the dinosaurs arrive, and it rolls using exactly the same
code it always did, because **how a body moves is a property of the body and not
of the program** — see
[locomotion is a dispatch table](012-locomotion-is-a-dispatch-table.md).

## What this is for

Software design. Not a product, not a game somebody ships. The maze is an
excuse to build a thing where a great many independent bodies move through a
shared piece of geometry, which is the shape of problem that rewards being
careful about memory layout, about determinism, and about which work is allowed
to depend on which other work.

The pieces that are actually interesting, and the pages that cover them:

- One integer per cell holds an entire vertical stack —
  [the stone](002-the-stone-and-what-is-inferred.md).
- Corridors and staircases are carved rather than placed, so the maze is always
  connected without anybody checking —
  [carving the maze](003-carving-the-maze.md).
- Every body's motion goes through one indexed table of functions rather than a
  chain of tests, so a new kind of creature is a new row —
  [locomotion](012-locomotion-is-a-dispatch-table.md).
- The same simulation runs with a window, in a terminal, or with nobody watching
  at all — [seeing it without a window](009-seeing-it-without-a-window.md).

## Where it came from

[The vision](../notes/vision), in the author's own words, is four sentences
long. Everything above is an unpacking of it, and where the unpacking made a
choice the vision did not make, that choice is written down in
[open questions](026-open-questions.md) rather than quietly assumed.

The picture that started it is in `inspiration/`, along with
[a notice](../inspiration/NOTICE.md) about what may and may not be done with it,
and the list of numbers that were measured off it.
