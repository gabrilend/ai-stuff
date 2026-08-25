# 901 — What a Bot Is Allowed to See

| | |
| --- | --- |
| Phase | 9 — An Opponent Worth Playing |
| Blocked by | 107, 701 |
| Blocks | 902, 903, 904, 905, 906 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md) · [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | none |

## Current behavior

Nothing reads the world except the renderer and the measuring bot from issue 803,
which is handed whatever it asks for because nobody is playing against it and it
does not matter.

## Intended behavior

**A bot is handed the same viewer frame a human's screen is drawn from, and
nothing else.** One function, one argument, no second path into the world.

This is the foundation of the whole phase and it is worth building before any bot
behaviour exists, because it is the thing that cannot be retrofitted. A bot that
grew up reading the world directly will have a hundred small dependencies on
information a person does not have, and no amount of later discipline finds them
all.

**The good news is that the hard half is already done.** Under the networking
model the enemy's chest, wallets, and sign-post directions are not on the machine
at all — see F7. A bot opponent running in the same process cannot read them
because they do not exist to read. What this issue adds is the rest of the fence:
no reading the opposing team's record, no reading the world's soldier store
directly, no consulting a random stream, no looking at the tick to time something
a person would have to feel.

**What a bot may see, exactly:**

- its own team's viewer frame, the same structure issue 701 draws from
- the commands it has issued and their refusals
- nothing else

**What it may not see, and each of these is a real temptation:**

- the enemy's chest, slots, wallets, or sign-posts
- any soldier field the frame does not carry — cooldowns, targets, generations
- the seed, or any random stream
- the phase table's future rows, which would let it play toward a surge with
  perfect timing rather than by watching the clock every player can see

## Suggested implementation steps

1. Define the bot interface as a single function taking a viewer frame and
   returning zero or more commands. Nothing else is passed in and nothing is
   returned but commands.
2. Run the bot behind the **same command door** as a human, with the same
   refusals. A bot that could issue an illegal command is a bot that is playing a
   different game.
3. Write the fence as a **test, not a convention**: construct a world where the
   enemy's chest is populated and assert that the frame handed to a team 2 bot
   contains no team 1 chest data at any depth. Conventions rot; this one is
   load-bearing for whether difficulty means anything.
4. Give the bot a small amount of **deliberate latency** — it does not act on the
   frame it was handed until a configurable number of ticks later. A bot that
   reacts on the tick a thing happens is not hard, it is inhuman, and the
   difference is the first thing a player notices.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md) — what a frame carries
- [Players, teams, and commands](../docs/016-players-teams-and-commands.md) — the
  one door, and why nothing bypasses it
