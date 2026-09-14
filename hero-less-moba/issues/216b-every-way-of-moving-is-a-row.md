# 216b — Every Way of Moving Is a Row

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 216a |
| Blocks | 216c |
| Reads | [the shape of the code](../docs/018-the-shape-of-the-code.md), [standing off and falling back](../docs/022-standing-off-and-falling-back.md) |
| Open questions | M4 |

## Current behavior

**The movement policy is the order of nine early returns inside one function.**

A guard never marches, so it returns first. Then a body walking off the map during a calm.
Then the Golem, which walks and does nothing else. Then a hero committed to a connector.
Then anything with a target, which becomes closing. Then a hero with a turn left, which
consults its sign-post. Then a body with a reach and no shot, which fans out. Then a hero
with no wave, which walks its lane alone. Then, finally, marching in formation.

Every one of those is correct. The problem is that the list is only visible by reading it,
the order between any two of them is a decision nobody wrote down, and adding a tenth way
to move means choosing a place in a sequence whose meaning is positional.

There is a dispatch table one level up — the brain's states — and this is the thing it
does not cover, because all nine of these are the *same* state.

## Intended behavior

**A movement pattern is a row. It places a goal and a pace, and that is all it may do.**

A pattern may not move a body, may not look at whether anything is in the way, and may not
know how fast the body will actually travel. It answers one question — *where do I want to
be* — and everything else belongs to the layer underneath.

| Pattern | Places its goal at | Pace |
| --- | --- | --- |
| `march` | its place in its wave's formation | by how far out of place it is |
| `charge` | its target's position | hurry |
| `stand_off` | back along its own lane | relax |
| `orbit` | out along its own rank, or in toward the enemy's mass | normal |
| `patrol` | a neighbour node inside its leash | relax |
| `leash` | the tower it guards | hurry |
| `chase` | its target, inside its leash | hurry |
| `lane_walk` | straight down its lane | normal |
| `cross` | the far end of the connector it is on | normal |
| `withdraw` | back down its lane and off the map | hurry |
| `hold` | its own feet | — |

### The gain is not tidiness

Three things become possible that are not possible today.

**A pattern can be tested on its own.** Give a body a pattern, run one tick, and assert
where its goal landed. No world full of other bodies, no question of whether it got there.

**A pattern can be named on screen.** The proving ground already prints which mechanics a
scene declared; printing what each body is trying to do is the same idea one level down,
and it is the difference between watching bodies move and watching them decide.

**The order stops being policy.** Which pattern a body takes becomes a lookup rather than
a position in a sequence, so two patterns that could both apply have to be resolved
explicitly rather than by whichever `return` came first.

### The Golem is a row, not an exception

It walks and it attacks whatever it walks into and it stops for neither. Today that is a
test near the top of the function and a paragraph explaining that somebody should find it
before wondering why the Golem parks. As a row it is `lane_walk` and nothing else, and the
reason it never fights is that nothing ever gives it another pattern.

## Suggested implementation steps

1. Write the table with every pattern that exists today, each placing a goal and a pace
   and doing nothing else.
2. Replace the run of early returns with the choice of a row. Keep the same order of tests
   at first, so the change is provably behaviour-preserving before anything is redesigned.
3. Then look at the order as a thing, now that it is one, and settle M4.
4. Name the pattern on the body's record rather than recomputing it, so it can be drawn
   and asserted on.
5. A scene per pattern in [the proving ground](111-the-proving-ground.md). Eleven of them
   is eleven mechanics that currently have no test at all, which
   [the census](../scripts/census-the-mechanics) will say out loud.

## Related documents and tools

- [216a](216a-a-goal-and-a-step.md), the layers these are written against
- [037 — the brain](../src/037-the-brain.info.md), the dispatch table one level up
- [062 — the rest of the brain](../src/062-the-rest-of-the-brain.info.md), which owns
  standing off and orbiting
