# 303 — Locomotion Is A Dispatch Table

| | |
| --- | --- |
| Phase | 3 — The Rolling |
| Blocked by | 107, 301, 302 |
| Blocks | 304, 305, 306, 401, 601, 702, 704, 705 |
| Reads | [locomotion is a dispatch table](../../docs/012-locomotion-is-a-dispatch-table.md) |
| Open questions | none |

## Current behavior

Seven rows, two built. The five unbuilt ones raise by name — "lumbering, which
breaks walls rather than routing around them — phase 7" — rather than being
absent, so the shape of the design is visible in the code and a mistake gets a
message instead of a nil index three calls away.

`check_needs` runs once at startup against the arrays the store actually has.

The shared machinery is `surface_top`, `settle_stance`, `floor_under`,
`apply_falling` and `check_in_world` — called by the rows, not inherited.

## Intended behavior

Two kinds of motion were asked for by name — continuous with momentum for the
balls, a smoothed graph walk for the little guys — with the instruction to
accommodate multiple. So there is no "how bodies move" in this project. There is
a table, and each row is one way of moving.

Row fields: `name`, `advance`, `parallel`, `drop_limit`, `needs`. The full list
of rows is in [the document](../../docs/012-locomotion-is-a-dispatch-table.md).

**`advance` takes a range of bodies, not one body.** A per-body function forces
an indirect call once per body per tick; a range is what a thread pool takes.
Each row has a **roster** — a contiguous array of the ids currently using it —
and the pool splits that array into one chunk per core.

**Rolling and walking are not two settings of one system.** A walker asks the
stone which of four answers applies; a roller never asks that at all — it has a
position on no grid, integrates a velocity, and collides against wall faces. They
disagree about falling: a three-layer drop is a wall to one and the interesting
part to the other. Unifying them produces a function with two halves and a branch
at the top, which is a dispatch table with one row and worse ergonomics. This is
written down because the refactor will look correct to somebody who has not read
that page.

What they *do* share is shared as functions the rows call: keeping the stance in
agreement with the position, falling, and the leaving-the-world check.

## Suggested implementation steps

1. Write the table with the seven named rows, five of them unimplemented and
   raising a clear message if reached, rather than absent. An unimplemented row
   that errors by name is a better failure than a nil index.
2. Write the `needs` check, run once at startup against the arrays the store
   actually has. A row naming a field that does not exist is a typo caught at
   load rather than a nil in the inner loop.
3. Write the shared helpers: `settle_stance`, `apply_falling`, `check_in_world`.
4. Write the move pass as a walk of the table calling each row's `advance` over
   its roster.
5. Test: a body whose locomotion changes moves between rosters correctly and is
   in exactly one. A row with an unsatisfied `needs` fails at startup.

## Related documents and tools

- [Locomotion is a dispatch table](../../docs/012-locomotion-is-a-dispatch-table.md)
- [Ways this could go wrong](../../docs/027-ways-this-could-go-wrong.md) — somebody unifies rolling and walking
