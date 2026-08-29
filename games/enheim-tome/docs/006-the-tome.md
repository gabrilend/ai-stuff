# 006 — The Tome

The right-hand column. It holds **every word in the game**, because
[the map holds none](001-what-this-game-is.md).

It is permanent. The map never covers it and it never covers the map. That costs
roughly a quarter of the window's width forever, and buys a game where the
written half and the drawn half are always both in sight — which for a game about
understanding a city rather than commanding one is the right trade.

## Three regions

```
┌────────────────────────────┬─────────────────────┐
│                            │  the hour  ───●───  │  ┐
│                            │  ● ● ● ● ● ● ● ●    │  │ welded
│                            │  ─────────────────  │  │
│                            │  shade              │  │ the focused
│        the map             │  angle   ◜   47°    │  │ filter's
│        pans and zooms      │  mode    [inter ▾]  │  │ controls
│        here                │                     │  ┘
│                            ├─────────────────────┤
│                            │   ▣  ▣  ▣  ▣  ▣     │  ┐ welded
│      ~~~ river ~~~         │   ▣  ▣  ▣  ▣  ▣     │  │ fixed
│                            │   ▣  ▣  ▣  ▣  [GO]  │  ┘ positions
│                            ├─────────────────────┤
│                            │  Tanner's Row       │  ┐
│                            │  forty-one souls    │  │ scrolls
│                            │  nine households    │  │
│                            │  owes the guild     │  ┘
└────────────────────────────┴─────────────────────┘
```

| Region | Behaviour | Holds |
| --- | --- | --- |
| **top** | welded, fixed height | the hour; the filter chips; the focused filter's controls; the search field when you press space |
| **middle** | welded, fixed positions | the icon buttons, the move queue, and go |
| **bottom** | scrolls | text, black ground, coloured words |

The controls that affect the map sit closest to the map. That is the principle
that puts the hour and the filters at the top rather than anywhere else.

## The top: chips, and one filter's controls

Any number of filters can be active at once — see
[filters and the weave](005-filters-and-the-weave.md) — and a fixed-height region
cannot hold controls for an unbounded number of them. So it holds two things:

- **one small chip per active filter**, in a wrapping row. Twelve filters is
  still one or two rows, so the height barely grows.
- **the full controls for whichever chip you last clicked** — its angle, its
  mode, and its own parameters.

Adjusting two filters means clicking between them. That is the cost, and it is
small next to the region staying a fixed size.

Each chip must carry its **name and its hatch angle**, not only its colour, per
[the rule about colour](001-what-this-game-is.md). How a chip stays legible at
chip size while carrying three channels is undecided; see
[open questions](010-open-questions.md).

**The hour lives here too, above the chips**, because it is not a filter
parameter. Both the shade filter and the whereabouts of every person read it, and
a value two unrelated systems consult belongs to neither of them. See
[the day and the curve](007-the-day-and-the-curve.md).

## The middle: buttons, the queue, and go

A fixed pane of icon buttons in **stable positions**, learned by hand rather than
by reading. A button the current place does not afford is dimmed rather than
removed, so the pattern of what is lit is itself information about the block —
you can read what kind of place this is from the shape of the lit buttons before
reading a word.

Selecting a block does not produce something to *read*. It produces the set of
things you can *do* here. What those things are is mechanics and is not decided.

**The move queue lives among the buttons that made it.** Queued moves show on the
button that produced them, and go is one more button in the pane. No new region,
and the queue is displayed in the same language as the actions that fill it.

The tension in that: a queue is a *sequence*, and buttons in fixed positions have
no order. The pane can show that one button has two moves pending and another has
one, but not which happens first. Whether the ordering needs to be visible at
all, and how, is undecided. See [open questions](010-open-questions.md).

## The bottom: the text

Scrolling. Black ground, coloured words, stylable and configurable by the player —
the prototype's black-and-colour scheme is a starting point rather than the
design.

Colour here signifies something about the text **that is also in the text**. It
exists to make the right line leap off the page. It never says anything the words
do not.

What the colour categories are is undecided. See
[open questions](010-open-questions.md).

Since the map carries no labels, this pane is where a block's name, its
buildings, and everything known about it actually appears. Buildings are a
positionless list — see [the fence network](003-the-fence-network.md) — so this is
the only place they exist at all.

## Going somewhere by name

Press **space** and type. The welded top becomes a search field, and reverts to
the filter controls when you are done. The results have the whole tome column to
spread into.

This is how you reach a place without labels on the map. Because buildings have
no position of their own, searching for one resolves to the block that holds it —
so the positionless list stays findable.

## Related documents

- [What this game is](001-what-this-game-is.md) — why the map has no text
- [Filters and the weave](005-filters-and-the-weave.md) — what the chips control
- [The day and the curve](007-the-day-and-the-curve.md) — the hour, and what sweeps it
- [Open questions](010-open-questions.md)
