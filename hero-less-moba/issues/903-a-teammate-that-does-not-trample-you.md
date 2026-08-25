# 903 — A Teammate That Does Not Trample You

| | |
| --- | --- |
| Phase | 9 — An Opponent Worth Playing |
| Blocked by | 902, 406, 407, 806 |
| Blocks | 906 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

There is no bot teammate. A single player alone has a chest nobody else touches,
which is not this game.

## Intended behavior

**This is the hard problem in phase 9 and the one that does not exist in the games
this one is subtracted from.** An opponent bot only has to play well. A teammate
bot has to play well *and* work out what a person is trying to do, from the only
evidence available, and then not get in the way of it.

Playing alone in a 3v3 means five bots and **two of them share your chest.**

### What a teammate bot can read of a person's intent

Exactly what a human teammate can, which is the whole design of the six verbs:

| Signal | Says |
| --- | --- |
| a **lock** | *I am doing something here* — explicit, and binding |
| an **objection** | *I would like you to stop* |
| a **cursor** hovering | *I am about to touch this* |
| an upgrade **marked to move** | *this is going there*, for a whole wave |
| a **ping** | *look at this place* |
| **chat** | anything at all |

A lock is the only one that is binding, and a bot must never test it — the
two-objection rule exists for humans disagreeing with each other deliberately,
and a bot that objects to a person's locks is a bot arguing with its owner.

**The rule: a bot teammate objects to nothing a human locked. Ever.** It may
object to another *bot's* lock, which is how three-bot teams stay unstuck.

### The failure on both sides

**Too eager** and it re-places the human's arrangement every wave, and the shared
chest becomes a thing that fights you. **Too passive** and it never places
anything, and single-player is solitaire with spectators.

The shape that avoids both: **a bot teammate works the lanes the human is not
touching.** It reads which lanes have the human's cursor, locks, and recent
placements on them, treats those as spoken for, and spends its attention on the
rest. When the human has touched nothing for a while it widens; when they are
actively arranging a lane it stays out of it entirely.

That is also how a good human teammate behaves, which is a sign it is right.

### It should say things

Since issue 806 exists, a bot teammate has words, and the moment it most needs
them is the same moment a human team does — **the boon pick**, where nothing is
on the board and three people are guessing what the others will take. A bot that
announces which of the two it intends to take, before taking it, turns the one
blind negotiation in the game into a solvable one.

Keep the vocabulary small and fixed. A bot that says "taking the left one" is
useful. A bot with a personality is a different project and a worse one.

## Suggested implementation steps

1. Write **intent inference** first: from a frame, produce the set of lanes the
   human appears to be working. Cursor position, locks held, instances placed in
   the last few waves.
2. Write the placement behaviour to operate only on the complement of that set,
   and widen the set only after a period of human inactivity.
3. Wire the hard rule as a **refusal inside the bot**, not as a preference: a bot
   may not issue `object_upgrade` against an instance locked by a human player.
   Assert it in a test.
4. Give it the boon announcement, with a fixed phrase per option.
5. Write the test that matters and is easy to skip: **run a match where the human
   places into one lane every wave and never speaks, and assert the bot never
   moves anything in that lane.**
6. Watch one. This is a behaviour that is either obviously right or obviously
   maddening within about two minutes, and no test tells you which.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) — the six
  verbs, the lock, the two-objection rule
- Issue 806 — the chat channel this uses
- Issue 902 — the board readings it decides from
