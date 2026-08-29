# 308 — Assigning Membership

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 301 |
| Blocks | 404, 405 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | **11**, **12** — which structures are megastructures, and how many districts |

## Current behavior

Blocks exist in isolation. There is nothing above them.

## Intended behavior

Saying, per block, which **district** it is in; and per district, which
**quadrant**; and per quadrant, which **group**.

That is the entire cost of the top of the hierarchy. **Every boundary above the
block is computed from membership** — a district's outline is the outer edges of
its blocks — so nothing up there is ever drawn by hand. See
[405](405-boundaries-derived-from-members.md).

Around two thousand small decisions, against two thousand traced loops and ten
thousand placed zones. The cheapest part of the campaign by a wide margin, and it
buys three whole levels.

### It should be fast, because it is repetitive

Assigning one block at a time through a menu would be two thousand menu
interactions. Better: select many blocks and assign them together, since districts
are contiguous and you will nearly always be doing a run of neighbours at once.

Painting membership by dragging across blocks — the way a fill tool works — is
likely the right shape, and the adjacency graph from
[203](203-adjacency-is-a-shared-edge.md) can offer "and everything connected to
this within N hops that has no district yet" as a starting selection to correct
rather than build.

### Groups are named by hand and there are few

The city, and each megastructure. Perhaps six in total. **Which structures count
as megastructures is unconfirmed** — see open question 11 — so the tool must let
groups be created, renamed and merged rather than assuming a fixed list.

### The absence beyond the wall is real

Land outside the wall has **no quadrant at all**. Not an empty one. So a district
may name a quadrant or name none, and the containment chain is a list of the
levels a place has rather than a fixed depth — see
[401](401-the-containment-chain-is-a-list.md).

The tool must be able to express "this has no quadrant" as a positive statement,
distinguishable from "nobody has said yet", or the coverage report cannot tell
finished from unstarted.

## Suggested implementation steps

1. Add district, quadrant and group tables, each with a name and a parent where
   one exists.
2. Multi-select of blocks, and assignment of the selection to a district.
3. A seeded selection from the neighbour graph, offered as a starting point.
4. Explicit "no quadrant" as a value distinct from unassigned.
5. Report unassigned blocks and districts in the coverage report.
6. Test that a district's derived outline matches the outer edges of its member
   blocks on the fixture, including when a member is removed.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [Open questions](../docs/012-open-questions.md) — questions 11 and 12
