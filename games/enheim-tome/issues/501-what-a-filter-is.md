# 501 — What a Filter Is

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 204 |
| Blocks | 502, 503, 504, 506, 509, 602 |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | — |

## Current behavior

The identity buffer knows which place each pixel belongs to. Nothing shades it.

## Intended behavior

A **filter** is a way of looking at the city. The word *layer* and the word
*overlay* are not used — they suggest something laid on top, and the interesting
cases here pass through each other.

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | what is being asked — fire hazard, shade, what is known of the guilds |
| `colour` | three numbers | what its lines are drawn in |
| `angle` | number, degrees | which way its lines run. **Adjustable by hand at any time.** |
| `mode` | one of three | where it sits relative to the others — see [504](504-the-three-modes-and-the-order.md) |
| `parameters` | list of named controls | anything this filter alone needs |
| `reading` | (person, place) → 0..1, or nothing | the answer — see [502](502-a-reading-takes-a-person.md) |

Spacing carries the value: **tighter lines mean more**.

### Reading and drawing are separated

The **reading** is data generation; the **hatching** is data viewing. They live in
different files and the reading must be computable and checkable with nothing on
screen at all.

That split is the project's general rule applied here, and it pays immediately: a
filter that shades wrongly is either giving wrong answers or drawing them wrongly,
and with the split you can tell which in one step rather than staring at pixels.

### Filters are declared, not compiled in

A filter is a record, so filters can be listed in a table and loaded rather than
written as code — at least the ones that look values up. Filters that *compute*,
like shade, need code, and should still present the same record so nothing
downstream can tell the difference.

### Identity is threefold, on purpose

A filter is known by its **colour**, its **angle**, and its **name**, and all
three are carried wherever it is shown. That redundancy is the colour rule from
[what this game is](../docs/001-what-this-game-is.md) being paid: a filter whose
meaning is only findable by recognising a colour is a filter somebody cannot use.

## Suggested implementation steps

1. Define the record. Keep the reading as a function reference so looked-up and
   computed filters are indistinguishable to callers.
2. Load declared filters from a table in `assets/`.
3. Provide a way to evaluate a filter over every place with no window open, and
   print the results, so readings can be checked as data.
4. Keep angle and colour mutable at runtime; nothing may cache them per frame
   without noticing a change.
5. Test that a filter's reading over the fixture city gives the expected numbers
   before anything is drawn.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md)
- [The shape of the code](../docs/010-the-shape-of-the-code.md)
