# 106 — Commands Enter Through One Door

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 104 |
| Blocks | 107, 404, 412, 413, 505, 508, 801 |
| Reads | [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | none |

## Current behavior

Every command enters through one queue and is applied at the top of a tick, sorted
by player and then by arrival so that two machines resolve the same tick the same
way. The verbs are a dispatch table.

Every refusal is returned, named, and raised as an event the panel shows. An unknown
verb stops the program, because that is a programming error rather than a player one.
The bot goes through the same door.

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

## Settled

**How many players per team? Three for the prototype, and a variable everywhere.**
This was already answered elsewhere and the question here had not caught up:
[A3 and F10](../docs/020-open-questions.md) settle three a side as what the prototype
is balanced against, and [players, teams and commands](../docs/016-players-teams-and-commands.md)
derives the map from the number — lanes equal players per team, towers equal lanes
times three — so a team size is a parameter (`team_size`) and nothing here assumes 3.

**Are 1v1 and 2v2 supported?** Decided: **by construction, yes; by balance, no.** The
map builder emits a two-lane map for two a side, and every verb here addresses players
by number up to twice the team size, so a smaller match is a different number rather
than different code. It is not balanced or tested: 016 says plainly that 3v3 is the
shape the prototype is balanced against, and nothing else is promised. The lock rule
this paragraph worried about is gone — ownership, contributing and dismissing replaced
it — and the verbs that replaced it work at any size ("everybody has dismissed it").

Nothing is left open here.
