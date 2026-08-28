# 704 — Locks, Objections, and Refusals Are Loud

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | 412, 413, 703 |
| Blocks | 805 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | the ping rate limit |

## Current behavior

Every refusal arrives at the bottom of the panel in the colour of a warning and
fades over several seconds. Transits are listed with where they are going and how many
waves out. A sign-post changed recently gets a halo in the world.

Locks and objections are not built and will not be: they were replaced by ownership,
contributing and dismissing.

## Intended behavior

Three people share one chest and mostly cannot talk about it in words. Everything
they can say to each other is six verbs — the canonical list is in
[the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md):

| | Says | Opt-in? | Drawn by |
| --- | --- | --- | --- |
| **Lock** | *I am doing something here.* | yes | this issue |
| **Objection** | *I would like you to stop.* | yes | this issue |
| **Cursor** | *I am about to touch this.* | **no** | issue 703 |
| **Marked-to-move** | *This is going there.* | **no** | issue 703 |
| **Ping** | *Look at this place.* | yes | this issue |

**Two of the five are involuntary, and those two carry the most.** So **if this
issue is built well, teams should lock rarely.** A team locking constantly is a
signal that the involuntary two are not readable enough — not that the lock is
working.

### What must be visible

- **Who locked it.** By name, permanently. An anonymous lock is an argument with
  nobody.
- **Who has objected, and how many more are needed.** "1 of 2" on the instance.
  An objection the locker cannot see is a message that was not delivered.
- **When an objection is about to expire**, so the second objector knows there is
  a window.
- **The moment a lock breaks**, loudly, to everyone — including the locker, who
  is about to find their plan dismantled and deserves to know why.

### The map ping

`ping_map`, taking a position, rate-limited, doing nothing else. It took its name
from the lock verb, which is now **object**; the reasoning is in
[open questions](../docs/020-open-questions.md), D6.

It does **not** replace the synced cursor. A cursor is always somewhere and
therefore never means anything by being somewhere; **a ping is the deliberate,
persistent version.** It is also the only one of the six verbs not about the
chest.

### Refusals

Every rejected command, immediately, with its reason **in words**: locked by
someone, already in transit, not during a surge, that upgrade cannot go into
stone, you cannot afford it, there are enemies by that tower.

A command that silently does nothing is the worst possible outcome — the player
learns nothing and concludes the game is broken.

**Refusals are also the game's teaching mechanism.** Nobody reads a rules screen.
A player learns that upgrades take a wave to move by watching one crawl, and that
nothing can be placed during a surge by being refused. What those refusals say is
the only explanation they will ever get.

## Suggested implementation steps

1. Draw lock state and objection counts on every instance in the chest panel and
   in every slot.
2. Draw an objection's remaining life as something decaying, so urgency is
   visible without a number.
3. Announce lock breaks to the whole team.
4. Write the refusal feed: a short queue of recent refusals, in words, **near
   where the action was attempted** rather than in a corner.
5. Write the reason-code-to-sentence table. Real sentences, not codes — this
   table is the game's manual and should read like one.
6. Write the `ping_map` handler and its rate limit. **The rate limit is the whole
   design of the feature**: unlimited pings are noise, and noise is worse than
   silence.
7. Draw a ping as something that decays rather than something dismissed. Nobody
   should have to clean up after a teammate.
8. Do **not** show enemy pings, cursors, marks, locks, or objections. None of it
   is in the enemy's snapshot; there is nothing to leak here, only something not
   to invent.
9. Test by giving three people the game and no explanation, and watching which
   rules they discover.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) — the five
  verbs, locking, and the two-key rule
- [Players, teams, and commands](../docs/016-players-teams-and-commands.md)

## Still open

The ping rate limit is a number, and it is the only one here.
