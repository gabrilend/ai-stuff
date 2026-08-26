# 413 — Staking a Die to Share

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 412, 411 |
| Blocks | 703 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | F30 — the resource kinds this stakes; F37 — what a staked die costs when it resolves |

## Current behavior

A stone contributed to the communal pool sits there until somebody places it. If
nobody wants it, nobody does anything, and it stays.

## Intended behavior

**The failure mode of a communal pool is not theft, it is neglect** — three
people each quietly assuming somebody else is handling it. So a player can say
*not my problem*, and saying it costs something.

### Dismissing, and what it stakes

A player marks a communal stone **shared instead of bothering me with it**. It
disappears from their view and nobody else's.

**Saying it stakes a die.** The player commits some of one bounty colour, and how
much they commit sets the size of the die staked:

| Committed | Die staked |
| --- | --- |
| 1 | d4 |
| 2 | d6 |
| 3 | d8 |
| … | … |

Nothing is spent yet. The stake sits on the stone.

### And when everybody has dismissed it, it rerolls

> **When every player has staked on the same stone, it is rerolled** — replaced
> by the next stone from the deck — and **the staked dice are consumed.**

That is the whole mechanism and it is worth reading twice, because it merges two
systems that were separate.

**A stone nobody wants converts into a different stone**, rather than sitting in
the pool being ignored or bouncing back to everybody. The cost is paid by exactly
the people who did not want it, in proportion to what each of them committed.

**And one person dismissing costs nothing at all.** *"There's no loss if you
share it once, and everyone else keeps it around."* You can decline to care about
a stone for free; you only pay when the whole team declines together, and then
you get something new for it.

Two players dismissing means two dice at risk, which does not resolve either —
the stone still needs the last holdout. So the pressure builds visibly: a stone
with two stakes on it is a stone the team has nearly given up on, and the last
player can see that before deciding.

### Why this replaces both the lock and the old reroll

**It replaces the lock** because it is a disclaim rather than a claim. A lock says
*I am doing something here*, which a teammate must take on trust. A dismissal says
*I am not doing anything here*, which is simply true when made — and it cannot be
forgotten, because forgetting it is what makes it resolve.

**It replaces the old reroll** — a player spending resource to push a stone to the
bottom of the deck — with something that cannot be done alone. Rerolling was one
player deciding the team's holding was wrong. This is the team agreeing.

Whether the *solo* reroll from issue 411 survives alongside it is F37's problem.

## Suggested implementation steps

1. Add `stake` to the instance record: per player, which colour and how much.
   Zero for players who have not dismissed it. Communal stones only.
2. Write `dismiss_upgrade`: refuse if the stone is not communal, refuse if this
   player has already staked, refuse if they cannot afford the commitment.
3. **Hide the stone from the dismissing player's frame and from nobody else's.**
   This is a per-player view difference and it is the first one in the project —
   check that the frame builder can express it before building anything else here.
4. Check the resolve condition **on every dismissal**, not on a timer: if every
   player has staked, consume the stakes, reroll the stone, raise an event loud
   enough that all three see what they collectively just bought.
5. Write a test that one dismissal costs nothing and two dismissals cost nothing,
   on a three-player team.
6. Write a test that the third dismissal spends all three stakes and produces a
   different stone.
7. Write a test at **team size two**, where the resolve fires on the second
   dismissal, and at **team size one**, where it fires immediately — that last one
   is degenerate and should probably be refused rather than allowed to resolve
   instantly.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)
- Issue 412 — contributing, which is what puts a stone in reach of this
- Issue 411 — the solo reroll this partly replaces
- `issues/will-not-implement/407` — the two-objection design this replaced
