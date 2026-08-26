# 033-validate

One pass that establishes everything the rest of the program assumes, so that
nothing else has to check.

The project's rule is that nothing in the world is ever nil and index 0 means
nothing. That rule is worth nothing unless something checks it — and checking it
ten thousand times a tick inside a loop is exactly what it was meant to avoid.
So it is checked here, once, at load and after any structural change. Everything
downstream then reads indices without bounds tests and dereferences without null
tests, and is entitled to.

Measured at about 7 microseconds for the two-room fixture; the phase 1 demo
reports the current number rather than this file quoting a stale one.

## The functions

| Function | In | Out |
| --- | --- | --- |
| `world_validate` | world, `*failure` | 1 when every invariant holds; 0 with `failure` filled in |
| `validation_failure_describe` | failure, buffer, size | the buffer, holding a sentence |

`struct validation_failure` holds the block name, the index, the field name, the
value found, and what was expected in words. The strings are literals owned by
the validator, so the record can be copied around freely.

## The invariants, in the order they are checked

Cheapest and most fundamental first, so a badly wrong world fails on "this index
points nowhere" rather than deep inside polygon winding, where the message would
be true and useless.

1. Index 0 of every block is untouched.
2. Every index field points inside its block; no region is its own parent.
3. No wall has zero length.
4. Every region has at least three vertices, inside the vertex block.
5. Every parent chain terminates within `REGION_MAX_DEPTH`.
6. Every region polygon has area, winds counter-clockwise, and does not cross itself.
7. Every light's thing exists and has `THING_EMITS_LIGHT` set.
8. Every thing's `region` is the deepest region actually containing it.
9. Every name offset is well formed and inside the string pool.

**An invariant nobody depends on is a check nobody should be paying for.** Each
one above exists because some later file skips a test on the strength of it —
number 3 because the sweep divides by segment length, number 5 because
`region_is_within` has no cycle guard, number 8 because the motion pass maintains
that field incrementally and would otherwise let it drift silently.

## It stops at the first failure

And it does not repair, clamp, or substitute a default. The first failure is the
one worth reading; thirty consequential ones bury it.

A failure here would be the worst possible fallback in the project, because every
later phase's performance decisions are written on the assumption that this pass
was honest.
