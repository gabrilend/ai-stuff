# 706 — Dropping and rejoining

| | |
| --- | --- |
| Phase | 7 — Other Players |
| Blocked by | 109, 703 |
| Blocks | 708 |
| Reads | [other players](../docs/011-other-players.md) |
| Open questions | none |

## Current behavior

Nothing. A peer that stops sending stalls the others forever, by the rule in
issue 701, and nothing distinguishes "slow" from "gone". The replay half of
issue 109 can play a command log forward from a seed at full speed, on one
machine, from a file. `tests/025-other-players.lua` asserts that a missing
batch stalls; nothing yet asserts a return.

## Intended behavior

A peer that drops leaves behind its **last acknowledged tick** — the highest
tick every other machine holds a batch from it for. The match stalls there,
saying so, and stays stalled: no timeout ends a match, because a match that
ended because somebody's radio hiccuped is worse than one that waited.

When the peer returns it does not receive a snapshot. It asks for **the command
log from its last tick to now**, and each machine that hears the request
answers with the slice it holds — every batch, from every peer, for every tick
in the range. The returning peer files them, replays them locally at full speed
through the same runner loop the live match uses, and is at the current tick
with the same world as everybody else, because the world is nothing but the
seed and the commands. Then the others resume. Nothing was ever sent but
commands, so nothing was ever lost but time.

Every machine therefore keeps the whole command log for the match — not only
its own batches, as issue 703 already requires for resending, but every batch
it has received. The log is small; it is the same log the replay file holds.

Two datagram kinds carry this: `resume-from`, naming the tick the returning
peer last holds, and `log-slice`, carrying a run of batches. A slice is
answered by whichever machines hear the request; duplicates are filed once,
because a batch is keyed by tick and sender.

## Suggested implementation steps

1. Add the received-batch log to the match record from issue 701: every batch
   filed, by tick then sender, never dropped during the match.
2. Add `resume-from` and `log-slice` to the encoder from issue 703.
3. Write the stall-with-a-name: after the threshold, the runner reports which
   peer and which tick and keeps waiting; the viewer shows it.
4. Write the rejoin path on the returning peer: send `resume-from`, file every
   slice that arrives, run the replay loop until the log has no gaps up to the
   highest tick heard, then re-enter the live loop.
5. Write the answering path: a machine that hears `resume-from` sends its log
   from that tick in slices sized under the largest datagram the transport
   carries.
6. Test with three loopback worlds: one is silenced for a run of ticks, the
   other two stall, the silenced one returns, replays, and all three hashes
   agree at the next interval.

## Related documents and tools

- [Other players](../docs/011-other-players.md)
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — snapshots
  and replays
- `tests/025-other-players.lua`

## Still open

- A peer that returns as a different process — a restarted program with the
  same name — has no log at all and must replay from the seed. The design
  covers it (the log starts at tick zero), but the lobby must recognise the
  name as the same peer. Whether a name is enough, or whether the lobby should
  hand out a token, is open.
- How large a `log-slice` may be on the handheld is one of the pending radio
  numbers in issue 707.
