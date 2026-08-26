# 107 -- The validator refuses to guess

**Phase:** 1, the world holds still
**Blocked by:** [102](102-the-world-is-flat-arrays.md) through
[106](106-names-live-in-one-pool.md). It checks all of them.
**Blocks:** [108](108-a-world-writes-itself-down.md), and every later phase's
right to skip null checks.
**Documents:** [the world and its tick](../docs/004-the-world-and-its-tick.md),
[the shape of the code](../docs/014-the-shape-of-the-code.md)

## Current behaviour

Nothing exists.

## Intended behaviour

One pass over a whole world that establishes every invariant the rest of the
program is allowed to assume. It runs when a world is loaded, after any
structural change, and in every test.

**This file is what buys the absence of null checks everywhere else.** The
project's rule is that nothing in the world is ever nil, and index 0 is a
reserved empty record. That rule is worth nothing unless something checks it, and
checking it ten thousand times a tick in a loop is the thing it was supposed to
avoid. So it is checked here, once.

### What it establishes

| Invariant | Why the rest of the program needs it |
| --- | --- |
| Every index field is within its block's count | Accessors can skip bounds checks in release builds. |
| Index 0 of every block is the zero record and nothing claims it | "Zero means nothing" is true rather than hoped. |
| Every region's parent chain terminates, within the depth limit | The permission walk in phase 6 is a loop with no cycle guard. |
| No wall has zero length | The sweep in phase 2 divides by segment length. |
| Every region polygon is closed, non-self-intersecting, and consistently wound | Point-in-polygon means something. |
| Every light's `thing` points at a thing with `EMITS_LIGHT` set | The two representations of the same fact agree. |
| Every thing's `region` is the deepest region actually containing it | Motion in phase 3 maintains this incrementally and would otherwise drift silently. |
| Every string offset is within the pool and its length does not run past the end | No scan runs off the end. |

That last column is the important one, and every future invariant added here
should come with an entry in it. **An invariant nobody depends on is a check
nobody should be paying for.**

### What a failure looks like

A sentence naming the block, the index, the field, the value found, and what was
expected. Then it stops. It does not repair, it does not clamp, it does not
substitute a default, and it does not continue to find more problems -- the first
failure is the one worth reading, and a wall of thirty consequential failures
buries it.

A fallback here would be the worst possible fallback in the project, because
every later phase's performance decisions are written on the assumption that this
pass was honest.

## Suggested implementation steps

1. Write the checks in the order of the table above -- cheapest and most
   fundamental first, so that a world which is badly wrong fails on the simple
   thing rather than deep inside polygon winding.
2. Make the failure message a function that takes block, index, field, found,
   expected. One function, so every message has the same shape and none is
   written in a hurry.
3. Wire it into world loading, into the test harness, and into a standalone
   command-line tool that takes a world file and says yes or why not. The
   standalone tool is what a person uses when a generated world will not load.
4. Write the companion `.info.md`, listing every invariant, because that list is
   the actual specification of what a valid world is.
5. Test each invariant by deliberately breaking it and asserting the message
   names the right field.

## Related

The standalone checker is the first of this project's validators. The pattern --
refuse loudly, name what was missing and where -- is in
[strategems](../strategems/patterns-that-keep-working) and applies to the
generator's checker in [806](806-the-generator-checks-its-own-work.md) too.
