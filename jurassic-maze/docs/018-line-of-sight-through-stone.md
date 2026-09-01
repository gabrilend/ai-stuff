# Line Of Sight Through Stone

Hiding is the point of [the habitat](019-dinosaurs-in-a-habitat.md), and hiding
is meaningless unless not-being-seen is a fact the program can establish.

## The question

Can the body at surface A see the body at surface B?

Answered by marching along the straight line from A to B in three dimensions,
sampling the stone, and stopping at the first solid layer. If the march reaches B,
there is sight. If it hits stone, there is not.

The march visits cells, not points. Step along the line in increments small
enough that no cell is skipped — at most half a cell — and at each step ask
whether the column at that cell has stone at the current height. That is one
array read and one bit test, which is why this is affordable to ask often.

The height along the line is interpolated between A's layer and B's, both raised
by an **eye height** of one layer, so that a creature can see over a wall that is
exactly level with the floor it is standing on. Without the eye offset, two
bodies on the same terrace cannot see each other across a completely open plaza,
because the line runs exactly along the surface and clips every block it grazes.

## What it costs and what bounds it

The march is proportional to the distance, and the distance is bounded by the
creature's `sight_range`. Beyond that the answer is no without any marching, and
the range check is two subtractions and a comparison.

Sight is asked in the `decide` pass, which is parallel-safe: the march reads the
stone and writes nothing. Many creatures can be asking at once and none of them
can interfere.

It is **not** asked every tick for every pair. A creature re-checks sight on a
cadence — every `sight_interval` seconds, offset per body so that the whole
population does not check on the same tick and produce a periodic stall. That
stagger is a real technique and it is worth naming: work that must happen
regularly but not immediately is spread across ticks by giving each body a phase,
so that the cost is flat instead of spiky.

## What it deliberately does not model

- **No cone of vision.** A creature sees in every direction within its range. A
  facing-based cone would mean creatures could be snuck up on from behind, which
  is a game mechanic, and this is not a game.
- **No light.** The maze is outdoors in the reference picture and lit uniformly.
  [The delve](021-the-delve.md) is indoors and may want darkness, and darkness
  would go here, as a per-cell light level sampled along the same march.
- **No memory.** A creature that loses sight of another forgets immediately.
  Remembering where something was last seen is what makes a search look
  intelligent, and it is
  [an open question](026-open-questions.md) rather than an omission.

## Related documents and tools

- [Dinosaurs in a habitat](019-dinosaurs-in-a-habitat.md) — who asks
- [The stone and what is inferred](002-the-stone-and-what-is-inferred.md) — the bit test the march performs
