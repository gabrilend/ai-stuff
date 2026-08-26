# 308 -- The turn is a window

**Phase:** 3, the world ticks
**Blocked by:** [302](302-motion-is-intent-then-resolve.md),
[306](306-the-command-log-is-the-replay.md)
**Blocks:** [309](309-taking-a-turn-back.md)
**Documents:** [the turn is a transaction](../../docs/019-the-turn-is-a-transaction.md)

## Current behaviour

The world ticks continuously. Nothing groups ticks together.

## Intended behaviour

A turn: a window in which declarations accumulate, a moment when it closes, and a
simultaneous resolution.

The server understands a turn as **a transaction with an undo**. It understands
nothing else about it -- no initiative, no rounds, no opinion on acting twice.
Those belong to a ruleset. A ruleset that wants continuous play sets the window to
one tick and nothing in this file ever does anything interesting.

### What a turn record holds

| Field | Meaning |
| --- | --- |
| `number` | Which turn. What a rollback names. |
| `first_tick` | Where it began, so the log can find its head. |
| `snapshot` | Index into the ring of head snapshots. See [309](309-taking-a-turn-back.md). |
| `declared` | A bit per viewer: have they sent `DECLARED`. |
| `state` | `OPEN`, `RESOLVING`, or `CLOSED`. |

### Simultaneity is already built

Declarations accumulate as intent and settle when the window closes -- which is
exactly what [302](302-motion-is-intent-then-resolve.md) already does per tick, at
a smaller scale. **This file does not implement simultaneity. It chooses when the
resolve happens.**

That is worth being clear about, because the instinct is to build a whole
declaration system. There is no declaration system. There are commands, buffered as
intent, and a decision about which beat resolves them.

### Declarations are not revealed early

A viewer is not sent what other viewers have declared. That is a filtering rule and
it belongs with the others in
[406](406-commands-run-a-gauntlet.md) rather than being enforced here.

People will talk to each other while they decide, and that is a tabletop and the
point of one. The server's job is not to prevent it -- only to avoid being the thing
that leaks.

## Suggested implementation steps

1. Add the turn record and the turn's transition to the tick's dispatch table as
   its own row, so *when* a turn closes is visible in the same table as everything
   else about ordering.
2. Implement window closing. Three triggers, not exclusive: everybody has sent
   `DECLARED`; a timer expired; a GM said so. Which of these a session uses is
   configuration. See [3.5](../../docs/016-open-questions.md) -- undecided, and a
   timer is both the thing that keeps a session moving and the thing that cuts
   somebody off mid-thought.
3. Take the head snapshot when a window opens, not when it closes.
4. Record the turn boundary in the log.
5. Make the one-tick window work and be tested. It is the continuous-play case and
   it must not be a special path -- it is the same code with a window of one.
6. Write the companion `.info.md`.
7. Test: a window closing on all-declared, on timer, and on command. A viewer who
   never declares. A viewer who disconnects mid-window.
