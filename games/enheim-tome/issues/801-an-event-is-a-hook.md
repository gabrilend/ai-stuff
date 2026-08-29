# 801 — An Event Is a Hook

| | |
| --- | --- |
| Phase | 8 — Events, and What Is Known |
| Blocked by | 407 |
| Blocks | 802, 803, 805 |
| Reads | [events and what people know](../docs/009-events-and-what-people-know.md) |
| Open questions | **16** — what holding one lets you do |

## Current behavior

The city has places and people. Nothing is hidden in any of it.

## Intended behavior

One concrete, hidden, local fact. The shape of it, in the author's own words:

> there's a secret key in a box in the living room on one of the endtables that
> opens a chest in the block on the other side of the yard

### The rule that keeps this from becoming a story

> Just keep it from becoming a massive story. People live in cities, so what?

Written down because it is exactly the kind of constraint that erodes one
well-meaning quest chain at a time.

**Every event is local, ordinary, and consequential only nearby.** No arcs, no
chosen ones, no chains where the key opens the chest that holds the map that names
the heir. A key opens a chest. In the chest is something a person in this block
would plausibly have put there. That is the end of it.

The variety comes from there being tens of thousands of them, each written by
looking at one real place on the map and asking what would be true of it — **not
from any one of them being remarkable**.

Anything that would be interesting to describe to somebody who has not played is
probably too big.

### The record

| Field | Type | Meaning |
| --- | --- | --- |
| `text` | string | the fact, in prose. The whole of what it says. |
| `block` | integer | where it is |
| `building` | integer or none | narrower, if known |
| `house` | integer or none | narrower still |
| `reaches` | an address, or none | what it points at elsewhere — see [802](802-an-event-crosses-an-address.md) |

### The prose does the fine detail

Addressed only as far as the house. **The living room, the endtable, the third
shelf are words, not structure.**

Nothing can query what is in a cellar, because cellars are not a thing the program
knows about. That is a deliberate saving: structuring rooms and furniture would
multiply the authoring by an order of magnitude and buy queries nobody has asked
for.

The writing stays free, which matters when there are tens of thousands to write.

### What holding one lets you do

Mechanics, and not decided. See open question 16. This issue builds the record and
the writing pipeline, not the consequences.

## Suggested implementation steps

1. Define the record with the narrower addresses optional.
2. Store events in a plain text format, editable by hand — this is a corpus a
   person will write in an editor, not through an interface.
3. Validate that addresses resolve, and that a narrower one is inside its broader
   one.
4. Provide a count per place for [309](309-the-coverage-report.md).
5. Test that an event addressed to a house is found when asking about its
   building, and about its block.

## Related documents and tools

- [Events and what people know](../docs/009-events-and-what-people-know.md)
- [Open questions](../docs/012-open-questions.md) — question 16
