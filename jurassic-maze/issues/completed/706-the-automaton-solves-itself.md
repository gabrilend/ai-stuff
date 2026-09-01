# 706 — The Automaton Solves Itself

| | |
| --- | --- |
| Phase | 7 — The Delve |
| Blocked by | 701, 703 |
| Blocks | 707 |
| Reads | [the monsters of the delve](../../docs/023-the-monsters-of-the-delve.md) |
| Open questions | none |

## Current behavior

The creature row: wooden, flammable, walking, with an `ignite` action on a
cooldown that sets alight anything of another side near it.

**No code was written for the self-immolation case**, and there is a test
asserting it happens: an automaton adjacent to vines it has ignited catches fire
within a bounded number of ticks. It falls out of fire spreading to flammable
neighbours and the automaton being one of them.

That test is the one that says the fire model was built at the right level. If it
had needed a code path, it would have said the opposite.

## Intended behavior

A machine made of wood. Not steam powered. Its power is `ignite`, which is
[a state, not a projectile](703-fire-is-a-state-that-spreads.md) — it sets a
target burning, with no travel time and no explosion.

**It is made of wood, so it burns.** An automaton standing in the vines it just
ignited has solved itself, and **nothing in the code arranges that.** It falls
out of fire spreading to flammable neighbours and the automaton being one of
them. If this issue needs any code to make that happen, issue 703 was built at
the wrong level and that is the finding, not this.

**Its solution is to be smashed** — wood against a stone fist.

**What it is for:** it is the only fire in the maze. A party with a vine problem
and no automaton has no answer and must go and find one, which is what makes this
mode about routing rather than about fighting.

## Suggested implementation steps

1. Add the creature row: wooden, flammable, walking, with an `ignite` action on a
   cooldown.
2. Add the meet entries: automaton to anything flammable is an ignition;
   automaton to golem is a smashing.
3. Write nothing at all for the self-immolation case, and write a **test** that
   asserts it happens: an automaton adjacent to vines it has ignited catches fire
   within a bounded number of ticks, with no code path named "self".
4. Count ignitions by source and automatons lost to their own fire. The second
   number is the funniest line in the report and it is also the check that the
   fire model is general.

## Related documents and tools

- [The monsters of the delve](../../docs/023-the-monsters-of-the-delve.md)
- [Fire is a state that spreads](703-fire-is-a-state-that-spreads.md)
