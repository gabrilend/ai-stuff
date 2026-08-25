# 803 — A Bot That Places Upgrades

| | |
| --- | --- |
| Phase | 8 — Six Players |
| Blocked by | 108, 502, 509 |
| Blocks | 804, 805 |
| Reads | [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | none |

## Current behavior

A match with no commands runs perfectly symmetrically to a stalemate or to
whichever side a seeded coin flip favours. There is nothing to play against and
nothing to run ten thousand matches with.

## Intended behavior

A bot that issues commands through the same door a human does. **It has no
special access.** It reads snapshots and writes commands, exactly like a viewer
with no window, which is the sharpest possible test of whether the command
interface is complete: anything the bot cannot express is something a human
cannot express either.

**This is the measuring instrument, and only that.** *Settled; see
[open questions](../docs/020-open-questions.md), E7.* Its job is to make ten
thousand matches mean something, which means it wants to be **cheap,
deterministic, and dull** — it runs overnight, and every quality that would make
it interesting to play against makes it slower and noisier as a measurement.

The bot built to be **played against** is a different program and lives in phase
9. The two are kept apart deliberately and neither should grow into the other: a
measuring bot that started making surprising choices would ruin the numbers, and
an opponent that was perfectly consistent would be no fun at all.

Three levels, because they answer different questions:

| Level | What it does | What it is for |
| --- | --- | --- |
| **Random** | Places every drawn upgrade somewhere legal, buys a hero when it can afford one. | A floor. Proves the interface works and nothing deadlocks. |
| **Greedy** | Places into whichever lane's push depth is worst, buys the hero that counters what is in front of it. | The balance opponent. Issue 804 runs this against itself. |
| **Committed** | Picks a strategy at match start — stack one lane, build stone, bank for heroes — and follows it through the surges. | The one worth playing against, and the one that reveals whether the strategies the design promises are actually distinct. |

The third level is the interesting one and it is a design instrument as much as a
feature. If a bot committed to stacking one lane and a bot committed to building
stone win at roughly the same rate through different play, the design works. If
one dominates, the balance ledger has work to do. If they turn out to be the same
strategy in different clothes, an issue file has work to do.

The bot must obey the same refusals a human gets and must handle them the same
way — including the surge, during which every chest command is refused, and the
one-wave transit on every placement. A naive bot will trip on both constantly.

## Suggested implementation steps

1. Write the bot as a snapshot reader and command writer with no other access.
   Enforce that by construction, not by discipline.
2. Write the random level and run it for a thousand matches, looking for
   deadlocks and for commands that can never legally be issued.
3. Write the greedy level against the push-depth numbers already in the snapshot.
4. Write the committed level as three strategy tables, each a list of (condition,
   preferred action) rows — a dispatch table, not a decision tree.
5. Have the bot log every refusal it receives. A refusal a bot hits constantly is
   a rule a human will hit constantly, and the log is free playtesting.

## Related documents and tools

- [Players, teams, and commands](../docs/016-players-teams-and-commands.md)
- The headless runner from issue 108

## Still open

How good does the bot need to be? If the game ships with single-player, the
answer is "good enough to be worth beating," which is a much larger project than
"good enough to generate balance data" and probably deserves its own phase.
