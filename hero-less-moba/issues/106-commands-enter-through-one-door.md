# 106 — Commands Enter Through One Door

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 104 |
| Blocks | 107, 404, 406, 407, 505, 508, 801 |
| Reads | [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | none |

## Current behavior

There is no way for a person to affect the world, and no discipline in place to
stop the first person who needs one from reaching in and setting a field.

## Intended behavior

**Nothing a player does touches the world directly.** Clicking a sign-post does
not turn a sign-post; it appends a **command record** to a queue. At the top of
the next tick the command pass applies every queued command in a fixed order —
by player number, then by arrival index within that player — and clears the
queue.

The command record is four integers: tick, player, verb, and three arguments.
Sixteen bytes. A whole match of them fits in memory, which is what lets a replay
be the command list itself rather than a compressed approximation of one.

The verb indexes a **dispatch table** of handler functions. Adding a verb is
adding a row and a function, never a branch in a conditional chain.

Every handler either applies its effect or returns a **reason code** for
refusing, and the refusal is recorded as an event the viewer will show. A command
that silently does nothing is the worst possible outcome: the player learns
nothing and concludes the game is broken. Refusals are loud, always, and they say
why.

The verbs, complete — if it is not on this list it is not a thing the game lets a
player do, and any future feature proposal has to add a row here first:

`place_upgrade`, `withdraw_upgrade`, `cancel_move`, `contribute_upgrade`,
`dismiss_upgrade`, `offer_upgrade`, `choose_boon`, `reroll_upgrade`, `ping_map`,
`set_signpost`, `spawn_hero`, `choose_boon`.

There is no verb for moving a soldier, attacking, or using an ability. Those are
the simulation's business.

## Suggested implementation steps

1. Write the command record as a flat array of four integers per entry, with a
   preallocated queue and a write cursor.
2. Write the dispatch table with all eleven verbs as stubs that refuse with a
   "not implemented yet" reason. Phases 4 and 5 fill them in.
3. Write the ordering: stable sort by player number then arrival index. Note in a
   comment that resolving conflicts by player number rather than arrival time is
   deliberate — arrival time means whoever has the better connection wins.
4. Write the reason-code table as named constants, and a text lookup for the
   viewer.
5. Write a test that queues conflicting commands from two players in both arrival
   orders and asserts the outcome is identical.

## Related documents and tools

- [Players, teams, and commands](../docs/016-players-teams-and-commands.md)

## Still open

How many players per team? Everything here is written against a team-size
constant rather than the literal number three, and the lock rule is phrased as
"everyone but the locker has objected" rather than "two people have objected" — so
that changing team size is changing a number. But the number still has to be
chosen, and whether 1v1 and 2v2 are supported at all is undecided.
