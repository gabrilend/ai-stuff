# 805 — One Event Per Block

| | |
| --- | --- |
| Phase | 8 — Events, and What Is Known |
| Blocked by | 309, 801 |
| Blocks | 806 |
| Reads | [events and what people know](../docs/009-events-and-what-people-know.md) |
| Open questions | — |

## Current behavior

Events can exist. None have been written.

## Intended behavior

**Every block gets its own hand-written event before the game is played.** These
are the ones the city cannot do without — they are what makes any block worth
entering.

### The arithmetic that makes this the shipping line

| | How many | At thirty a day |
| --- | --- | --- |
| **one per block** | ~2,000 | **one to two months** |
| at least one per house | ~20,000–40,000 | two to four years |

Two months is a campaign somebody finishes. Two to four years is not something to
wait on before anybody plays, including the author.

So the block events are the release condition and the house events are
[fill-in-forever](806-houses-fill-in-forever.md).

### The writing is looking, not inventing

Each one is written by **looking at one real place on the painting** and asking
what would be true of it. A block by the tanning vats and a block in the terraced
gardens are different places and want different facts, and the painting already
says which is which in considerable detail.

That is what makes two thousand of them possible without them turning into two
thousand variations of one idea, and it is why they cannot be generated.

### This is a tool, not just a plan

Two thousand items over two months is thirty a day, and the difference between
finishing and abandoning is almost entirely in the friction of the workflow.

What it needs:

- a **worklist** — which blocks have no event, in an order that groups nearby ones
  so a session covers a neighbourhood rather than jumping across the city
- the **painting at that block**, since the writing is looking
- what is already known about the place — its buildings, its corners, its
  neighbours — because a fact should fit its surroundings
- **plain text in**, with no interface between the thought and the page
- a **count and a rate**, so progress is visible — see
  [309](309-the-coverage-report.md)

The rate matters more than it sounds. A two-thousand-item backlog with no measure
is a wall; the same backlog with "about eleven weeks at your current pace" is a
schedule.

## Suggested implementation steps

1. A worklist of blocks with no event, ordered by walking the neighbour graph so
   consecutive entries are adjacent.
2. A writing view: the painting framed on that block, its known facts beside it,
   and a text field.
3. Save straight into the corpus; validate the address on save.
4. Record the count and the date so a rate can be computed.
5. Report the remaining count and the projected finish.
6. Test the worklist ordering actually walks a neighbourhood rather than jumping
   about, since that is what makes a session coherent.

## Related documents and tools

- [Events and what people know](../docs/009-events-and-what-people-know.md)
- [The tracing tool](../docs/005-the-tracing-tool.md)
