# 036-locomotion

The dispatch table of ways to move, and the machinery its rows share.

Read this page rather than the source, and read
[locomotion is a dispatch table](../docs/012-locomotion-is-a-dispatch-table.md)
before either.

## What it is for

Two kinds of motion were asked for by name — continuous with momentum for the
balls, a smoothed graph walk for the little guys — with the instruction to
accommodate multiple. So there is no "how bodies move" in this project. There is
a table, and each row is one way of moving.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new_table(Rolling, Walking)` | the two built rows' modules | the seven-row dispatch table |
| `check_needs(rows, bodies)` | | raises if a row names a body field that does not exist |
| `surface_top(layer)` | | the height of a body's feet when standing on that layer |
| `settle_stance(Stone, store, bodies, id)` | | brings `cell` and `layer` back into agreement with the position |
| `floor_under(Stone, store, bodies, id)` | | the height of the stone directly beneath, or -1 over the void |
| `apply_falling(Stone, store, bodies, id, kind, dt)` | | one tick of falling; true while airborne |
| `check_in_world(Stone, store, bodies, id, row_name)` | | raises, naming the row that let a body leave |
| `unbuilt(what)` | | a row body that raises by name |

## A row

`name`, `advance`, `parallel`, `needs`.

**`advance` takes a range of bodies, not one body.** A per-body function forces
an indirect call once per body per tick; a range is what a thread pool takes.
Each row has a roster — a contiguous array of the ids currently using it — and
the pool splits that array into one chunk per core.

Five of the seven rows are unimplemented and **raise by name** if reached. A row
that errors saying "lumbering is not built yet — phase 7" is a far better failure
than a nil index three calls away, and it means the shape of the design is
visible in the code and not only in the documents.

## `surface_top` is `layer + 1`, and getting it wrong is invisible

A block occupying layer L spans heights L to L+1, so the thing being stood on is
its top. Off by one, every body is buried half a layer inside the stone it is
standing on — which looks like nothing at all, because the block it is inside is
exactly the same colour as the one it should be on top of.

## Falling is written once

Identical for a ball that went over a cliff, a little guy that walked off a
terrace, a rider dropped when its mount died, and a vine that let go. Writing it
twice is how they start disagreeing about what a fall is.

`bounce_floor` is not a nicety: without it a bouncing body's vertical velocity
approaches zero without reaching it, and the body spends the rest of the run
performing several hundred infinitesimal bounces a second — each one a landing
event, none of them visible, all of them costing.
