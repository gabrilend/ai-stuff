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

**The map is not the city. It is your model of the city.**

Every rule in this project falls out of that sentence, and when a decision is
hard, this is the sentence to hold it against.

- A block drawn with no data on it is not an empty block. It is a block **you do
  not know about**. Ignorance renders as bare painting.
- You can read a person's day only if they are one of your people or someone
  you've come to know. You cannot model a stranger.
- Dragging the hour to three in the afternoon does not travel there. It shows you
  **what you believe would be true then**. It is planning, not time travel.
- Consequently **the time is only ever now**, and the world advances only when you
  make a move or push go on moves you queued. Nothing happens behind your back,
  and no reading on screen ever needs to be marked as hypothetical, because none
  of them were ever a live camera.

## The two surfaces

The screen is split, permanently, and neither half ever covers the other.

| | |
| --- | --- |
| **The map** | The painting, pannable and zoomable. Carries no words of any kind. See [the map surface](002-the-map-surface.md). |
| **The tome** | A column down one side. Carries every word in the game. See [the tome](006-the-tome.md). |

The map is forbidden text — no labels, no tooltips, no place names, nothing.
This is not a stylistic preference. The painting is already at maximum visual
density; its roofs, water, gardens and stone leave no quiet ground for a typeface
to sit on, and anything written across it would both damage the art and be hard
to read. Refusing text also means label collision — a genuinely hard problem
that produces flickering, mediocre results — never has to be solved at all.

To reach a place by name you press space and type. See
[the tome](006-the-tome.md).

## Vocabulary

These words mean exactly one thing each, throughout the project. Where a document
uses one of them, it means this and not a synonym.

| Word | What it is |
| --- | --- |
| **the painting** | The single image the whole game is played over. One file in `assets/`. |
| **block** | The smallest thing you can click. The area enclosed by streets. The unit the game plays at. |
| **the cage** | All the fences drawn together — the one-pixel lines along the streets that show where the blocks divide. See [the fence network](003-the-fence-network.md). |
| **fence** | One block's boundary. |
| **edge** | One run of fence along one street, shared by the blocks on either side of it. |
| **junction** | A vertex where edges meet. Shared. Moving it moves every fence that runs into that corner. |
| **shape point** | A vertex in the middle of an edge that makes a curved street curve. Private to its edge. |
| **adjacency** | Two blocks are neighbours when they list the same edge. This is the only notion of nearness the game has. |
| **filter** | A way of looking at the city. Reads each block as a number, or as nothing at all. Draws as hatching. See [filters and the weave](005-filters-and-the-weave.md). |
| **the glow** | Warm breathing light on a block, meaning *this one*. |
| **time-curve** | A person's day plotted as activity. Sweepable. See [the day and the curve](007-the-day-and-the-curve.md). |
| **the hour** | The global time axis that filters and people both read. Not owned by any filter. |

Words deliberately **not** used: *layer* and *overlay* (they are filters), *tile*
(the painting is not tiled), *unit* and *entity* (there are people, and there are
blocks).

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

The mechanics. This document set describes an **interface**, worked out before
the systems it will eventually show. What a move is, what unites a
neighbourhood, what the buttons in the tome actually do — none of that is
decided, and the documents do not pretend otherwise. Where a mechanic would be
needed to finish a thought, the thought is parked in
[open questions](010-open-questions.md) instead of guessed at.

This ordering is intentional. The interface's shape is knowable from the painting
and the vision alone, and knowing it constrains the mechanics usefully — a game
whose map cannot carry text and cannot express a radius is a different game from
one that can.
