# 704 — Finding each other

| | |
| --- | --- |
| Phase | 7 — Other Players |
| Blocked by | 703 |
| Blocks | 708 |
| Reads | [other players](../docs/011-other-players.md) |
| Open questions | A6 |

## Current behavior

Nothing. A match's peers, seed and start tick are read from `input/` by hand,
and there is no way for two machines that have not been told about each other
to meet. `tests/025-other-players.lua` looks for a `discovery` stem with
`announce`, `heard`, and `age_pass`.

## Intended behavior

A machine looking for a match **announces itself** on a broadcast: its name,
the seed it proposes, the tick rate and delay it will run, and the protocol
version. It listens for the same. The announcement repeats on a periodic
counter — the [pair of integers](../docs/003-the-tick-and-the-timers.md) on
the wire — and a peer that stops announcing is aged out of the list when
enough increments have passed since it was last heard.

Machines that hear each other form a **lobby**: a record holding the peer list,
one agreed seed, and a start tick. The rule that makes it one record on every
machine: **the peer that announced first proposes**, and the others agree by
echoing the proposal in their own announcements. Ordering is by the announced
start-of-listening time and then by name, which every machine can compute from
what it has heard, so no machine has to be told who is first. When every peer
in the lobby has echoed the same seed and start tick, the match opens.

The lobby announcement carries a team as well as a name, because the roster,
the menu and the cloud are per team (A6). Two players naming the same team
share them. The prototype is one against one, and the lobby refuses a third
peer by name rather than guessing what a third team would mean.

## Suggested implementation steps

1. Claim `discovery`. Exports: `announce(transport, self)`, `heard(lobby,
   datagram)`, `age_pass(lobby, counter)`, and `agreed(lobby)`.
2. Add the discovery datagram kinds to the encoder from issue 703: `announce`
   carrying name, team, proposed seed, tick rate, delay, version, and the
   listening-since stamp.
3. Write the lobby record: peers by id, each with name, team, last-heard
   increment, and echoed proposal; the proposer's id; the agreed seed and start
   tick, zero until agreed.
4. Write the ordering rule as one function over the peer list, so every machine
   computes the same proposer.
5. Write `agreed`: true when every peer's echoed proposal equals the proposer's.
6. Hand the agreed lobby to `open_match` (issue 701). The seed goes where
   `input/seed` would have put it, and is logged the way a random seed is.
7. Test in one process with two loopback transports: both announce, one is
   first, both agree, the match opens with the same seed on both.

## Related documents and tools

- [Other players](../docs/011-other-players.md)
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md) — the
  counter the announcement repeats on
- `tests/025-other-players.lua`

## Still open

- **A6.** How many players and how many teams. The lobby is written for two
  teams and any number of players per team, with the prototype refusing more
  than two peers; the answer decides what the refusal becomes.
- A version mismatch between two announcements: refuse to lobby, and say which
  side is older. Whether that is enough, or whether the newer side should say
  what changed, is a question for the first time it happens.
