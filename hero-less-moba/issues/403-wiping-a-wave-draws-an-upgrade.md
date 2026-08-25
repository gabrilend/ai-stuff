# 403 — Wiping a Wave Draws an Upgrade

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 105, 208, 306, 402 |
| Blocks | 404, 804 |
| Reads | [waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md), [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | B7 — whether the catalogue has kinds whose value changes across a match |

## Current behavior

Waves are noticed being wiped and towers are noticed being felled. Both events
fall on the floor.

## Intended behavior

**There is one deck for the whole match, and both teams draw from it in the same
order.** Team 1's fifth draw and team 2's fifth draw are the same kind.

The deck is a flat array of kind ids, generated once at match start from the
catalogue's weights using the `deck` stream, long enough that no match reaches the
end of it. Each team holds an **index** into that sequence, not a stream of its
own.

Two events draw:

| Event | Draws |
| --- | --- |
| A wave fully defeated | **one** to the killing team |
| A guard tower felled | **three** to the destroying team |

Boons are not draws. They come from a separate catalogue, are chosen from three
offers by each player in the calm after a challenge is slain, and never touch the
deck. See issue 605.

The routine, for both events:

1. Read the kind at that team's deck index.
2. Append an instance with `slot_kind = 0`. It lands in the chest, unplaced.
3. Advance that team's index by one.
4. Raise an event so the viewer can announce it.

### Why one shared sequence

**It removes the last source of asymmetry that is not a decision.** The map is
exactly symmetric, the spawn intervals are identical, the surge is on a clock both
teams can see — and now the upgrades are the same upgrades in the same order. If a
team is ahead, it is ahead because of **placements**, and there is no match where
somebody simply drew better.

It also makes the enemy's chest legible with no interface for it. A team four
draws behind is holding **your own chest from two minutes ago**. You know exactly
what they have, because you had it. What you do not know is where they put it —
and that is the only thing worth not knowing.

A team killing more reaches its fifth draw sooner. The leader is **ahead on the
same track** rather than holding different cards, which is a race, and a race is
legible in a way a lottery is not.

The cost is real: the roguelike texture of *this run went strangely* disappears,
and two evenly matched teams get identical resources with no variance to break a
stalemate. Whether that matters is what issue 804 is for.

**Draws are never automatically placed.** An upgrade in the chest is doing
nothing for anybody, and that uselessness is the pressure that makes a team look
at its chest. Auto-placing would remove the only moment the game forces three
players to talk to each other.

The one way to leave the shared sequence is to **pay** — see issue 411.

## Suggested implementation steps
1. Write the deck generator: walk the catalogue's weight table against a
   prefix-sum built once at load, emitting a long flat array of kind ids. Generate
   it once at match start from the `deck` stream and never touch it again.
2. Give each team an index and a tail. A draw reads, appends, advances.
3. Wire the wave-wiped and tower-felled events to it.
4. Raise `upgrade_drawn { team, instance_id, kind, reason, deck_index }` — the
   report wants draws broken down by source, and the deck index is what makes
   "how far ahead is the other team" answerable in one subtraction.
5. Write a test: wipe a wave, assert one instance in the right team's chest.
6. Write a test: fell a tower, assert three.
7. Write a test that both teams, drawing the same number of times, hold the same
   kinds — and that a reroll is the only thing that breaks it.

## Related documents and tools

- [Waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md)
- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)

## Settled

**The killing team draws**, from one deck both teams read in the same order, with
replacement. Rerolling — issue 411 — is the only way off that shared sequence.

See [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) for why one
shared sequence removes the last source of asymmetry that is not a decision.

## Still open

**Does this snowball, or is it a race?** Both readings are in play and issue 804
has to settle it. A team that is winning draws faster, which is a snowball — but
they draw the *same cards* faster, so the gap is legible as position on a track
rather than as a difference in kind. Whether a legible snowball is a tolerable
one is exactly the sort of thing that has to be watched rather than argued about.
