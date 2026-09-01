# 001 — What This Game Is

A strategy game played over one painting of one city, at the scale of blocks and
neighbourhoods. You are an ordinary person living in it. Nothing is on fire.
There is no war and no coming disaster — the city's problem is that life in it is
**rigid**. You must work a job, you must marry late, you must not wear that
colour on a Sunday. The whole game is the wish to loosen that, one block at a
time, by bringing people together.

See [the vision](../notes/vision) for where this came from, in the author's own
words. Read it first; everything in `docs/` is downstream of it.

## The one idea everything else follows from

**The map is not the city. It is one person's model of the city.**

Every rule in this project falls out of that sentence, and when a decision is
hard, this is the sentence to hold it against.

- A block drawn with no data on it is not an empty block. It is a block **that
  person does not know about**. Ignorance renders as bare painting.
- Their day is legible; a stranger's is not. You cannot model somebody you have
  never met.
- Dragging the hour to three in the afternoon does not travel there. It shows you
  **what they believe would be true then**. It is planning, not time travel.
- Consequently **the time is only ever now**, and the world advances only when you
  make a move or push go on moves you queued. Nothing happens behind your back,
  and no reading on screen ever needs to be marked as hypothetical, because none
  of them were ever a live camera.

### Which person, is a thing you choose

You may select any house in the city and play as whoever lives in it — the way a
Paradox game hands you any character on the map.

And because the map was always *somebody's* model rather than the city itself,
switching person **repaints the entire map**. The hatching rearranges. Blank
ground moves. Different days become readable, different buttons light up, and
your whereabouts equation becomes theirs.

This costs one parameter. A filter's reading was never really *block → a number*;
it is **(person, block) → a number, or nothing**, and that was implicitly true
before anybody noticed. The whole of character switching falls out of making it
explicit.

It buys something no other map does: you can **look at somebody else's
ignorance**. Switch to a servant in the eastern mansions and the harbour goes
blank. Switch to a bargeman and the river lights while the walled quarter goes
dark. For a game about a rigid city, being able to see the shape of what a person
is not allowed to know is the point rather than a flourish.

## The two surfaces

The screen is split, permanently, and neither half ever covers the other.

| | |
| --- | --- |
| **The map** | The painting, pannable and zoomable. Carries no words of any kind. See [the map surface](002-the-map-surface.md). |
| **The tome** | A column down one side. Carries every word in the game. See [the tome](007-the-tome.md). |

The map is forbidden text — no labels, no tooltips, no place names, nothing.
This is not a stylistic preference. The painting is already at maximum visual
density; its roofs, water, gardens and stone leave no quiet ground for a typeface
to sit on, and anything written across it would both damage the art and be hard
to read. Refusing text also means label collision — a genuinely hard problem
that produces flickering, mediocre results — never has to be solved at all.

To reach a place by name you press space and type. See
[the tome](007-the-tome.md).

## Vocabulary

These words mean exactly one thing each, throughout the project. Where a document
uses one of them, it means this and not a synonym.

| Word | What it is |
| --- | --- |
| **the painting** | The single image the whole game is played over. Currently `inspiration-pictures/vision-map.png`, which is **a stand-in that cannot ship** — see [the notice](../inspiration-pictures/NOTICE.md). |
| **group** | The city, or one megastructure. The top; has no parent. |
| **quadrant** | A quarter of a group. Also the scale at which two people simply never meet. |
| **district** | A set of blocks. Its outline is derived, never traced. |
| **block** | Five to seven buildings around an intersection, and the community they make. Bounded by street runs. |
| **building** | One freestanding stone structure. Unrestricted to anyone. What roots people. |
| **house** | An apartment inside a building, three to five rooms, one family or one person. Almost always restricted. Has no geometry at all. |
| **intersection** | A corner where street runs meet. Named, and listed with everything it connects to. |
| **the cage** | All the fences drawn together — the one-pixel lines that show where places divide. See [the fence network](004-the-fence-network.md). |
| **edge** | One run of fence along one street, shared by the blocks on either side. |
| **junction** | A vertex where edges meet — the structural form of an intersection. Shared, so moving it moves every fence into that corner. |
| **shape point** | A vertex in the middle of an edge that makes a curved street curve. Private to its edge. |
| **adjacency** | Two blocks are neighbours when they share an edge. The only notion of nearness the game has. |
| **filter** | A way of looking. Reads a block, for a person, as a number or as nothing. Draws as hatching. See [filters and the weave](006-filters-and-the-weave.md). |
| **event** | An occurrence, not a possession. People in a place at an hour. Computed, never stored. See [the scaffold](009-the-scaffold.md). |
| **actor** | A person or a place. Anything that has a character and a status. |
| **open** | Open to being **changed**. Receives. Drawn as a circle. |
| **closed** | Not open to being changed. **Gives** — the closed is the source, not the withholder. Drawn as a vertical line. |
| **axis** | One named dimension of character, minted when it is needed rather than declared. Also a filter; they are the same record. |
| **arc** | What two closed actors make when they are intent on each other. Where it lands is context. |
| **gathering** | The actors in one place at one hour, the place counted as one of them. Each is one share of N+1. |
| **interaction** | One axis, across everyone in a gathering. Shared, strained, offered, withheld, or asserted. See [the scene](010-the-scene.md). |
| **scene** | The record of a gathering where something changed: who, where, when, which axes, and what moved. Data, not prose. |
| **narration** | Words rendered from a scene. Decides nothing; the city runs without it. |
| **history** | An actor's append-only record — axis changes, narrations, and mintings. Never edited. |
| **public** | A fact anyone may read. |
| **private** | A fact only somebody who knows it may read. Included in the thinking phase always, in a narration only when the reader knows it. |
| **the glow** | Warm breathing light on a place, meaning *this one*. |
| **time-curve** | A person's day plotted as activity. Sweepable. See [the day and the curve](008-the-day-and-the-curve.md). |
| **the hour** | The global time axis that filters and people both read. Not owned by any filter. |

Words deliberately **not** used: *layer* and *overlay* (they are filters), *tile*
(the painting is not tiled), *unit* and *entity* (there are people, and there are
places).

## What the game never claims

Positions are stored as **pixel coordinates in the painting** and nothing else.
The painting is an oblique aerial view with a horizon, so its scale is not
uniform — ordinary townhouses measure roughly 12 to 20 pixels across up by the
northern wall and roughly 40 to 70 down in the harbour, a swing of three or four
times across the frame that grows worse toward the horizon. Any distance or area
computed from those pixels would be wrong by a factor that changes depending on
where you measured.

So the game **never claims a distance**. There is no radius, no range in feet, no
area of a district. Where a real game would say "everything within two hundred
feet," this one says "one block along, then another" — walking the adjacency
graph. That is a better model anyway for a city with walls in it: a rumour
travels down a lane and a rampart genuinely stops it, because the blocks on
either side of a wall do not share an edge.

The hand-traced fences carry the perspective for free. A block near the horizon
is small because you traced it small. Nothing needs correcting.

## The rule about colour

**Colour never carries a fact the words don't also carry.**

Every distinction a colour makes must also be present in the text. Colour exists
to make the right line leap off the page, never to mean something the page does
not say. A dimmed button must be dimmed *and* say why. A filter chip must carry
its name and its hatch angle, not only its colour.

This has a real cost — it constrains chips, badges and the text pane all at once —
and it is paid deliberately, for the people who would otherwise be locked out.

## What is deliberately absent

**Some of the mechanics — no longer all of them.** This document set was written
interface-first, on the argument that a map which cannot carry text and cannot
express a radius constrains the mechanics usefully. That held until the mechanics
arrived, and [the scaffold](009-the-scaffold.md) is now the part that moves: what
an event is, how character travels between people and places, and where a new way
of looking comes from.

What is still undecided is what a **move** is and what any particular button in
the tome does. Where a mechanic is needed to finish a thought, the thought is
parked in [open questions](013-open-questions.md) rather than guessed at.

That ordering was intentional and it paid. The interface's shape was knowable from
the painting and the vision alone, and knowing it constrained the mechanics
usefully — a game whose map cannot carry text and cannot express a radius is a
different game from one that can. When the mechanics did arrive, "nearby" could
only mean adjacency, because there are no distances, and that constraint came from
the interface rather than being imposed on it.
