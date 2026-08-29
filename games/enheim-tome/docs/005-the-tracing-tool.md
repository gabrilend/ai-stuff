# 005 — The Tracing Tool

A **separate program** from the game, sharing the canvas code and nothing else.
It writes the fence network; the game only ever reads it.

This split is not fussiness. Defining the city is data generation and playing it
is data viewing, and keeping them in different programs means the tracing tool
can have whatever dense, ugly, keyboard-heavy interface makes it fastest to use,
because no player will ever see it. It also means the game cannot corrupt the
network, because it has no code that writes one.

The trade is that noticing a bad trace while playing means leaving the game to
fix it. A pin the game can drop for the tool to pick up as a worklist would soften
that, and is not currently planned.

## What the work actually is

Hand-defining a city of roughly two thousand blocks and ten thousand buildings
over a painting 6148 by 4092 pixels. This is the single largest piece of manual
labour in the project, and every feature below exists to make it survivable
rather than to make it elegant.

Blocks are traced **one loop at a time**: click around a block until it closes,
name it, move to the next. This gives total control over what counts as a block —
an odd wedge, a whole square treated as one place — at the cost of every street
being approached twice, once from either side.

## The click has three outcomes, and that is the whole design

What happens when you click depends entirely on what is under the cursor:

| Under the cursor | What the click does |
| --- | --- |
| empty painting | makes a new vertex |
| an existing vertex | adopts it, becoming a shared junction |
| an existing edge | adopts **the entire run**, reversed |

That third row is what makes per-block tracing work at all, and it is worth being
explicit about why.

Suppose block A is traced and you are now on the far side of a curving lane,
tracing block B. Even with perfect snapping onto A's two corner vertices, the
stretch between them is a fresh set of clicks. A traced that curve with five
shape points; you trace it with four, in slightly different places. Now two
hairlines run down the same lane with slivers of painting showing between them —
and, silently, the two blocks do not share an edge, so they are not neighbours,
so nothing will ever propagate between them.

Adopting the whole edge instead is one click rather than five, and the two blocks
become adjacent because they are literally naming the same edge record. Identical
by definition rather than by luck.

Because the outcome depends on what is beneath the pointer, this dispatch belongs
in a table keyed on what was hit, not in a chain of if-else.

## The pointer must say which is about to happen

Silent mis-snapping is the failure mode that costs a day of retracing to find,
because it produces a network that looks completely correct on screen. So before
any click commits:

- a vertex about to be adopted **lights up**
- an edge about to be adopted **lights up along its whole length**, so you can see
  exactly how much you are taking
- empty ground shows the new vertex as a ghost where it would land

## Snapping is measured on the screen, not on the painting

The grab radius is a fixed distance in screen pixels — somewhere around eight —
and therefore covers a large area of painting when zoomed out and a tiny one when
zoomed in. That is correct rather than a compromise: it matches how precisely a
person can actually point at that moment.

It does mean that at the whole-city view, an eight-pixel radius covers roughly
forty painting pixels and will happily snap to the wrong vertex. The tool should
refuse to place or drag vertices below some zoom rather than allow imprecise work
that looks fine until someone zooms in.

## Four other things it authors, none of them tracing

Drawing block loops is the loudest part of the job but not the whole of it. The
tool is also where these happen, and each is cheap next to the tracing:

- **Naming intersections.** A corner becomes an intersection when somebody names
  it. See [the fence network](004-the-fence-network.md).
- **Placing building zones.** A rough shape over each roof — five to seven per
  block, seconds each, not traced outlines. Around ten thousand of them, which is
  real work but an order of magnitude below tracing them properly.
- **Assigning membership.** Which district each block is in, and which quadrant
  each district is in. Two thousand small decisions, and they buy every boundary
  above the block for free, since those outlines are computed from membership
  rather than drawn.
- **Listing houses and buildings.** Names and purposes, with no geometry attached.

Everything in that list can be done long after a block is traced, and most of it
will be. The tool should make it easy to come back to a place and add one more
thing rather than demanding a place be finished before you move on — because
[the fill-in-forever plan](009-events-and-what-people-know.md) means most places
will be revisited for years.

## What it must check

Every save should run the network validator described in
[the fence network](004-the-fence-network.md), and refuse or loudly warn on:

- an edge named by three or more blocks, which is impossible
- an edge named by no block, which is stranded
- a block whose loop does not close
- a block with no name
- two vertices closer together than the snap radius at native zoom, which is
  almost always a mis-snap rather than an intention

It should also report **coverage** — blocks traced, blocks named, fraction of the
painting fenced — since that is the only honest measure of how far the heroic
effort has got.

Whether the tool needs undo, and how deep, is undecided. See
[open questions](012-open-questions.md).

## Related documents

- [The fence network](004-the-fence-network.md) — the structure this writes
- [The map surface](002-the-map-surface.md) — the canvas code it shares with the game
- [Open questions](012-open-questions.md)
