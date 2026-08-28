# 404 — Placing an Upgrade Into a Lane

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 106, 402, 403 |
| Blocks | 405, 412, 408, 703 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

Placing names a stone and a destination, and it **takes a full wave to get
there**, applying at its old slot the whole way — so a placement lands two waves after
the command. Cancelling is free until it lands.

The move announces itself for that whole wave, and nobody opted into that: you cannot
move a stone quietly.

## Intended behavior

Three verbs — `place_upgrade`, `withdraw_upgrade`, `cancel_move` — applied in the
command pass at the top of a tick.

**A placement does not arrive when you issue it.** The instance is marked to
move, keeps applying at its **old** slot for one full wave, and lands with the
wave after. Two waves from command to effect, with one wave of unchanged
behaviour in between.

That one wave does three jobs, and the datapath document explains why each
matters. Briefly: it is the only cost of moving an upgrade, so **there is no
reassignment cooldown to build**; it makes a placement a commitment worth locking
and objecting over; and it announces itself to every teammate for the duration,
which is one of the two involuntary verbs the team has for talking about the
chest.

**A transit can be cancelled freely, any time before it lands**, at no cost. The
instance simply stays where it was.

Placement is refused, with a reason code the viewer shows, when:

- the instance is locked by another player
- the instance is already in transit
- the destination is where it already is
- the instance is inside the freeze window before a queued destination takes
  effect

**Never for being the wrong kind of upgrade**, and never because a siege-surge is
running — see F28 and F12. Any upgrade may go into any slot, in any phase.

**No cap on how many upgrades a lane holds.** The vision blesses stacking one
lane explicitly, and any player may place any of their team's unlocked
instances; there is no ownership by whoever drew it.

The transit fields on the instance record, and the reasoning behind all of the
above, are in
[the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md).

## Suggested implementation steps

1. Write the three verb handlers in the command dispatch table from issue 106.
2. On a successful placement, set the transit fields rather than changing the
   slot. The slot changes on arrival, not on command.
3. Resolve arrivals in the spawn pass, **before** stamping, so a wave never
   spawns half-updated.
4. Order the refusal checks cheapest first and return the **first** reason that
   applies, not the last.
5. Do not build a reassignment cooldown. The transit is the cost.
6. `cancel_move` clears the transit fields and leaves the slot alone.
7. Call `rebuild_masks` from exactly one place, after any successful change.
8. Write a test per refusal reason.
9. Write a test that places, then asserts the next wave carries the **old**
   arrangement and the one after carries the new.
10. Write a test that stacks every instance a team owns into one lane and asserts
    it is allowed — the vision blesses it and it should be impossible to
    accidentally forbid.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) — placement,
  transit, and what the enemy can see
- [Players, teams, and commands](../docs/016-players-teams-and-commands.md) — the
  command pass and the full verb list

## Notes for the viewer

Two things this issue owes issue 703, both of which are easy to build weakly:

- **The marked-to-move indicator must be noticeable**, not subtle. It is the only
  warning a teammate gets before an upgrade moves.
- **Its disappearance on cancel must be as visible as its appearance.** A mark
  that silently vanishes is worse than one that never appeared, because a
  teammate may already have acted on it.
