# 804 — A Knowledge Filter

> **Superseded.** Kept for the record rather than deleted &mdash; see
> [phase 8 progress](../phase-8-progress.md) for what replaced it and why, and
> [the scaffold](../../docs/009-the-scaffold.md) for the design that stands now.
>
> An axis and a filter are the same record, so there is no separate knowledge
> filter to build. Every minted axis already is one.

| | |
| --- | --- |
| Phase | 8 — Events, and What Is Known |
| Blocked by | 502, 503, 803 |
| Blocks | — |
| Reads | [the scaffold](../../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

People hold events. Nothing draws that.

## Intended behavior

A filter whose reading is **a count of the events this person holds at this
place**, and **nothing where they hold none**.

That is the entire implementation. It is a few lines, because
[502](../502-a-reading-takes-a-person.md) and [503](../503-nothing-is-a-value.md)
already did the work — the reading already takes a person, and absence is already
a value that draws as bare painting.

### What it looks like

The hatched parts are what this person knows. **The bare parts are their
blindness, and the painting shows through there** — so the map is most beautiful
exactly where they are ignorant.

That is not an accident to be corrected. A city you have not learned should look
like a city, not like a grid of grey unknowns.

### It draws the social horizon without being asked to

Because knowledge accumulates where a person actually goes, and because a quadrant
is the scale at which two people never meet —
[403](../403-quadrants-four-to-a-group.md) — a citizen's holdings come out **shaped
like their quadrant**: dense inside it, thinning at the edges, blank across the
divide.

Nothing renders that boundary. It appears because it is true. Turning this filter
on for a servant and then for a bargeman shows two different cities, and the
difference between them is the shape of two lives.

### Which count, and how it normalises

A raw count does not map cleanly onto nought-to-one, since a block with forty
houses can hold far more than a block with five.

**Working ruling: hold against what is there** — the events this person holds at
this place, over the events that exist there. So the reading answers *how much of
what is here do you know*, which is the question worth asking, rather than *how
much do you know in absolute terms*, which mostly measures how big the block is.

Where nothing exists to be known, the answer is **nothing** — indistinguishable
on the map from a place this person has never been, which is correct: from the
inside, a place with no secrets and a place whose secrets you have not found look
identical. That is not a flaw to fix.

### More than one such filter

Knowledge is not one thing. What you know of the guilds, of who owes whom, of what
is hidden — these are separate questions and want separate filters, each counting
a subset of events by kind, each with its own angle and colour, woven together.

So events want a **kind**, and this issue is really a small family of filters
built from one function.

## Suggested implementation steps

1. Add a kind to the event record.
2. One reading function, parameterised by kind, counting held-over-present.
3. Return nothing when nothing is present, and nothing when nothing is held.
4. Declare several filters from it in the filter table, each with its own kind,
   colour and angle.
5. Test that a person holding two of four events in a block reads as half, that a
   person holding none reads as nothing, and that a block with no events of that
   kind also reads as nothing.

## Related documents and tools

- [the scaffold](../../docs/009-the-scaffold.md)
- [Filters and the weave](../../docs/006-filters-and-the-weave.md)
