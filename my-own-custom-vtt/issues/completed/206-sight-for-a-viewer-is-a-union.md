# 206 -- Sight for a viewer is a union

**Phase:** 2, the world can be seen
**Blocked by:** [204](204-the-visibility-polygon.md),
[205](205-the-fog-is-a-bitmap.md)
**Blocks:** [404](404-one-function-writes-to-a-socket.md)
**Documents:** [sight and what it remembers](../docs/007-sight-and-what-it-remembers.md),
[who controls what](../docs/008-who-controls-what.md)

## Current behaviour

Nothing exists.

## Intended behaviour

A viewer's sight is the union of what every body they command can see.

A player driving one character sees from one pair of eyes. A commander with six
goblins sees from six, unioned. That is the honest answer for sight-as-security --
you know what your goblins know -- and it is also why a large scope is expensive.

### The shortcuts, which are flags rather than patience

| Flag | What it does | When it is right |
| --- | --- | --- |
| `SEES_ALL` | Skip the sweep entirely; everything is visible. | A GM. Without it, a GM would run the sweep for every creature on the map, every tick. |
| `SEES_REGION` | See the whole region rather than only from the bodies' eyes. | Plausibly the tavern's commander -- they *are* the tavern, and a tavern knows where its own crockery is. |

`SEES_REGION` is the interesting one, and it is a design question wearing a
performance costume. Computing one region's interior once beats computing thirty
overlapping wedges and unioning them -- but whether the tavern's commander *should*
be blind to the corner their crockery cannot see is a question about what it feels
like to play a building, not about cost. Not settled.

### The union does not have to be a polygon

Three consumers, and only one of them wants a merged shape.

The filter asks "is this point visible to this viewer", which is "is it inside
*any* of the fans" -- a loop over fans with early exit, no merging. The fog folds
each fan into the bitmap in turn, which unions in the bitmap for free.

Only the renderer wants a single merged outline, and even it may be happier
compositing several fans than receiving one complicated polygon.

**So do not merge.** Keep a viewer's sight as a list of fans, one per commanding
body, and let each consumer union in whatever way suits it. Polygon union is
difficult, slow, and full of degenerate cases, and nothing here actually needs it.
That reasoning belongs in the source, because merging is the obvious thing to
reach for.

### This is the parallel pass

A viewer's sight depends on the walls and the bodies and on **no other viewer**.
There is no shared mutable state in the whole computation. Twelve viewers is twelve
independent problems handed to [201](201-the-thread-pool.md) with a loop and no
locks.

It is also the most expensive pass in the tick, which is the pleasant case: the
slow thing is the parallel thing.

## Suggested implementation steps

1. Walk a viewer's scopes, then each scope's members, gathering bodies with a
   non-zero `sight_range`. A body in two of a viewer's scopes is swept once.
2. Run [203](203-the-angular-sweep.md) per body into a per-viewer fan list sized
   at startup.
3. Implement the two flags as early exits before any sweeping.
4. Write the "visible to this viewer" query as a loop over fans with early exit.
5. Hand the whole pass to the pool, one viewer per work item.
6. Write the companion `.info.md`.
7. Test: a viewer with two bodies in different rooms sees into both. A viewer with
   `SEES_ALL` sees a thing behind a wall. A viewer whose only body has zero sight
   range sees nothing, and that is not an error.

## Open questions this touches

[2.2](../docs/016-open-questions.md) -- does a viewer with many bodies see the
union, or switch between them? The union is what this file builds and what the
security argument assumes, but six overlapping cones may simply be a strange thing
to look at.

---

## Current behaviour, as of the close of phase 2

**The per-body half is built and tested.** `042-sight.c` computes what one body
can see, and `044-fog.c` folds it into a viewer's memory. The expensive part is
done, measured, and running on the thread pool.

**The union half is not, and cannot be yet**, because it is a union across *the
bodies a viewer commands*, and neither viewers nor scopes exist until phases 4
and 6. Building a union over a list that has no source would mean inventing the
list, and then rebuilding it once scopes arrived.

So this issue stays open, and it is the one place phase 2's work stops short of
what this file describes. What remains:

- Walking a viewer's scopes to gather the bodies with eyes.
- Running the sweep once per such body, into a per-viewer list of fans.
- `SEES_ALL` and `SEES_REGION` as early exits before any sweeping.
- The "visible to this viewer" query as a loop over fans with early exit.

The decision **not to merge the fans into one polygon** still stands and is worth
restating, because merging is the obvious thing to reach for: the filter asks
"inside any of them", which is a loop with early exit; the fog folds each in turn
and unions in the bitmap for free; and only a renderer might want one outline,
and even it may prefer compositing several. Polygon union is difficult, slow, and
full of degenerate cases, and nothing here needs it.
