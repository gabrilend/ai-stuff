# 801 — Reconciling Across Machines

| | |
| --- | --- |
| Phase | 8 — Six Players |
| Blocked by | 106, 107 |
| Blocks | 802, 805 |
| Reads | [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | cycle length |

## Current behavior

Every player's commands come from one process. There is no second machine.

## Intended behavior

**Peer-to-peer, three channels, no permanent host.** The model and the reasoning
behind it are in
[players, teams, and commands](../docs/016-players-teams-and-commands.md); what
follows is what has to be built.

### Channel 1 — choices

Every command a player issues is sent to every peer over TCP and applied on
arrival. **Authoritative from whoever made it, never rolled back**, no scheduling
window, no rollback-and-replay.

This is the load-bearing rule of the whole networking design. Positions may lie a
little; choices may not lie at all.

### Channel 2 — continuous state

**Positions and health. Nothing else.** One peer publishes about once a second
and **whose turn it is rotates**, derived from a cycle counter every machine
agrees on, so there is nothing to negotiate.

Everything downstream — deaths, wave wipes, draws, the chest — is *derived* from
health and therefore converges on its own without crossing the wire. That chain
is the reason the payload is this small, and it is written up in the datapath
document.

Incoming values are **sanity-checked for causality, not magnitude**:

1. Only examine values that **differ** from the local simulation.
2. For each, find what was in range of that body on the checking machine's own
   view.
3. Reject any difference **no in-range body could have caused**.
4. Keep the local value and log it.

### Channel 3 — presence

Every player's cursor, continuously. A few bytes, and one of the eight verbs a
team has for talking about the chest.

## Not lockstep

Machines are not required to agree bit for bit and will not. Three consequences
worth carrying into the code as comments:

- **Floating point is fine.** No fixed-point rewrite.
- **A replay is not just a seed and a command list** — it records accepted
  snapshots too. See issue 107.
- **The determinism test does not underwrite the network.** It is still the best
  regression test on one machine and proves nothing about two.

## Suggested implementation steps

1. Write the command channel first, over TCP, applied on arrival. **Test it with
   two machines and nothing else running** — if choices are reliable and
   immediate, the game is playable before channel 2 exists at all.
2. Write the rotation: a shared cycle counter and a rule mapping cycle number to
   whose turn it is.
3. Write the snapshot as exactly two arrays — position and health — plus body ids
   and generations. **Assert in a test that nothing else is in it.**
4. Delta-encode against the last accepted snapshot. That is where the bandwidth
   is.
5. Write `could_have_affected(world, body_id, elapsed_ticks)`, returning the
   maximum health change any in-range body could have caused. Build it on the
   milestone buckets from issue 204 — it is the retarget pass's neighbourhood
   query asked about the past instead of the present.
6. Make snapshot acceptance **unable** to raise a death, a wipe, or a draw as a
   side effect. Health is written; the ordinary resolve pass notices the zero on
   the next tick and everything downstream follows the normal path.
7. Write the presence channel. Small, independent, and worth having early because
   it makes two-machine testing much easier to watch.
8. Write the missed-turn behaviour: if the peer whose turn it is does not
   publish, the turn passes to the next rather than the cycle stalling.
9. Log every rejection with body, claimed value, local value, and the bound
   exceeded. **Rejections are the only evidence this system will ever produce**,
   so they must be readable after a match.
10. Log the mean and worst-case correction distance. **If bodies visibly snap,
    the cycle is too long or the divergence is bigger than floating-point
    rounding explains** — and the second of those is a bug, not a tuning problem.
11. Write a test with a hand-built malicious snapshot: a body healed from
    nothing, and a body killed by an attacker never in range. Both refused, local
    values survive.
12. Test across two machines with different processors before believing any of it.

## Related documents and tools

- [Players, teams, and commands](../docs/016-players-teams-and-commands.md) — the
  three channels, the rotation, and the causality check
- The world-hash function from issue 107, useful here as a cheap "how far apart
  are we" measurement even though nothing halts on it

## Still open

**Cycle length, and whether it scales with player count.** With six players
rotating on a one-second cycle, each peer publishes once every six seconds and
each machine runs up to six seconds of uncorrected drift between its own turns.

The causality check catches the impossible, not the improbable. A cheater
inflating damage *within* what an in-range attacker could plausibly have dealt is
undetectable, and that is the accepted stopping point.
