# 806 — Three People Can Finally Talk

| | |
| --- | --- |
| Phase | 8 — Six Players |
| Blocked by | 801, 704 |
| Blocks | nothing |
| Reads | [players, teams, and commands](../docs/016-players-teams-and-commands.md) · [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | F26 — what a chat channel does to the argument for locks |

## Current behavior

There is no way for a player to say anything to a teammate. Everything a team can
communicate is expressed by doing something to the board: a lock, an objection, a
cursor hovering, an upgrade marked to move, a ping dropped on the map.

That is workable for everything that *is* on the board, and it collapses
completely for one moment in the match. **When a boon is chosen, three teammates
look at the same two options and each has to guess what the others will take.**
Nothing is on the board to lock, object to, hover over, mark, or point at,
because the thing being decided does not exist in the world yet. It is the only
decision in the game a team has to coordinate blind, and every one of the five
verbs is useless for it.

Spreading two-and-one is usually right. Everybody piling onto the stronger option
is a coordination failure. Neither is currently sayable.

## Intended behavior

**A simple team text chat, carried on the same immediate TCP channel as every
other choice a player makes.**

- **Team-only.** A player sends to their own team and nobody else. This is not a
  politeness decision — the entire information design of this game rests on an
  opponent learning about you only from what has physically walked into them, and
  a text box that reaches the enemy is the largest hole anybody could punch in
  that. There is no all-chat.
- **On the choice channel, not the sync channel.** A message is a thing a person
  did, so it goes out immediately over TCP to teammates and is never rolled back,
  exactly like a placement. It does not enter the command queue and it does not
  touch the world, because it changes nothing about the simulation — which is why
  it needs no tick number and cannot desync anything.
- **Ephemeral.** Messages scroll and are gone. Nothing about a chat line is world
  state, nothing is snapshotted, and a replay does not need to carry it for the
  match to reproduce. Whether a replay carries it anyway, for people watching
  rather than for the simulation, is worth deciding when replays are built.
- **Legible without being looked at.** The camera rule from D7 applies: anything
  a player must react to has to be readable at the default view. A teammate
  saying something during a calm is a thing to react to, so it belongs where the
  refusals already surface — see issue 704 — rather than in a panel a player has
  to have chosen to watch.

### It is a sixth verb, and that is not free

[The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) carries a table
called **the five verbs of the team's conversation** (six, now), introduced with the line
*"three people share one chest and mostly cannot talk about it in words."*

That sentence is now false, and the table has a sixth row. **The lock system's
justification has to change with it.** It was partly argued for as the only way
to say "I am doing something here"; with a chat channel, that sentence can simply
be typed. What a lock still does that a message cannot is **enforce** — it
physically refuses a teammate's move, it persists without anybody remembering it,
and it does not require the other two people to have been reading.

So the split to preserve, and to write into the table: **chat is persuasion, a
lock is enforcement.** A message asks. A lock refuses. A team that talks well
will lock less, and that is the system working rather than the system being
redundant.

Whether that survives contact with people is F26.

## Suggested implementation steps

1. Add a `chat` message type to the team channel from issue 801 — sender, text,
   nothing else. Not a command record; it has no `tick` and no verb row, because
   it never reaches the simulation.
2. Cap the length and rate-limit it, on the sending machine and again on the
   receiving one. A rate limit that only the sender enforces is not a rate limit.
3. Reject anything arriving from a player not on the receiving player's team,
   loudly and into the log, rather than dropping it quietly. A message from the
   other team is not a stray packet; it is either a bug in the channel or a
   modified client, and both want to be visible.
4. Surface incoming messages through the same route as refusals and events —
   issue 704 — so there is one place a player learns that something happened.
5. Add the sixth row to the five-verbs table and rewrite the paragraph above it
   that says a team cannot talk in words.
6. Write a test that a message sent by a player on team 1 never appears in any
   team 2 client's received set, at any latency.

## Related documents and tools

- [Players, teams, and commands](../docs/016-players-teams-and-commands.md) — the
  three channels, and why choices are never rolled back
- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) — the verbs
  table this adds a row to
- [Boons and the challenge](../docs/015-boons-and-the-challenge.md) — the moment
  that motivated it
