# 301 -- The tick is a dispatch table

**Phase:** 3, the world ticks
**Blocked by:** phase 1 and phase 2 complete.
**Blocks:** every other issue in phase 3.
**Documents:** [the world and its tick](../docs/004-the-world-and-its-tick.md)

## Current behaviour

Nothing exists. Sight is computed on demand by a demo; nothing advances.

## Intended behaviour

The heartbeat: an array of function pointers, walked in order, once per beat.

Not a sequence of calls in a function body. **The order of the simulation becomes a
piece of readable data**, and that is the point -- every "does X happen before Y?"
question is answered by looking at one table.

| # | Pass | Parallel over |
| --- | --- | --- |
| 1 | Intake -- drain sockets, decode, refuse or accept | sockets |
| 2 | Intent -- turn accepted commands into intended motion and action | scopes |
| 3 | Motion -- advance what moves, resolve against walls | things |
| 4 | Rules -- the ruleset's slice of the beat | the ruleset's call |
| 5 | Sight -- recompute per viewer | viewers |
| 6 | Memory -- fold sight into fog | viewers |
| 7 | Outbound -- build and send each viewer's filtered update | viewers |

In phase 3 there are no sockets and no ruleset, so passes 1, 4, and 7 are the
empty function and the table still has seven rows. **An empty row is better than an
absent one**, because it is where the later work goes and because the table stays
the whole truth about ordering.

Adding a pass is adding a row. A pass that must run twice appears twice.

## Suggested implementation steps

1. Define the pass signature: takes the world and a range, returns nothing. Every
   pass has the same shape, which is what lets any of them go to the pool.
2. Build the table as static data with the passes named in it, so reading the array
   reads as the order of the simulation.
3. Give each row a flag saying whether it parallelises and over what, so pass 5
   slicing by viewer and pass 3 slicing by thing is data rather than a special case
   in the runner.
4. Write the runner: walk the table, slice, hand to [201](201-the-thread-pool.md),
   barrier, next row.
5. Write the companion `.info.md`, listing the passes in order. That listing is the
   specification of when things happen.
6. Test: a tick with every pass empty changes nothing and the world hash is
   unchanged. That is the null case and it will catch a runner that corrupts
   something by accident.
