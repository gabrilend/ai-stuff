# 005 — Waves, and When One Is Finished

**Datapath document.** Covers the spawn cadence, the bookkeeping that lets the
game know a wave has been wiped out, and the moment that turns a wipe into a draw
from the chest.

## A wave is three kinds of body

A wave is not a column of identical soldiers. It carries **melee bodies, ranged
bodies, and a captain** that is one or the other. *Settled; see
[open questions](020-open-questions.md), F22.*

| | Health | Damage | Reach |
| --- | --- | --- | --- |
| **melee** | 1× | 1× | small, nonzero |
| **ranged** | 1× | 1× | stands off |
| **captain** | **2.5×** | **1.5×** | whichever the captain is |

All three are `flavour = 1`, all three spawn together, and all three are stamped
with the lane's upgrades — including the captain, which is what makes it a
different thing from a hero. See
[a unit and what it carries](004-a-unit-and-what-it-carries.md).

Two consequences land in this document specifically. **The frontline is no longer
one queue** — melee bodies form ranks and ranged bodies hold behind them at their
own reach, which is issue 206's problem. And **a lane's upgrades only reach the
half of a wave they match**, so placing into a lane is a decision about
composition and not only about quantity.

**How many of each, and whether every wave carries a captain, is not settled.**
The numbers belong to B1; whether anybody gets to choose them is **F27**.

## A wave is a group with a name

Ordinary soldiers are not spawned as loose individuals. A **wave** is a record,
and every soldier it spawns carries that record's id for its whole life. Without
this the game could never notice a wave being wiped, because "wiped" is a
statement about a group, and a pile of unrelated bodies has no groups in it.

### wave record

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Monotonic, never reused within a match. |
| `team` | integer | 1 or 2 — the team that *spawned* it. |
| `lane` | integer | 1–3. |
| `spawn_tick` | integer | When it left the base. |
| `member_count` | integer | How many bodies it started with. |
| `living_count` | integer | How many are still alive. Decremented in the reap pass. |
| `killed_any` | integer | 1 once at least one member has been killed by the enemy, else 0. |
| `settled` | integer | 1 once the wave has been accounted for and can be forgotten. |
| `upgrade_count` | integer[kinds] | The lane's upgrade counts at the instant of spawn, copied here for the record. |

Waves accumulate; they are not freed the moment they empty. A settled wave stays
in the array until the end of the match so that the post-match report can say
how many waves each team lost in each lane, which is the single most useful
number for judging whether the upgrade economy is balanced.

## The cadence, in each of the three phases

The spawner is one function reading a different row of a phase table. There is no
separate surge spawner and no separate challenge spawner.

| Phase | Shape | Destination | What each body carries |
| --- | --- | --- | --- |
| **Normal** | a batch per lane, on a long interval | its own lane | that lane's placed upgrades |
| **Siege-surge** | one body per lane, on a very short interval | its own lane | **a share of the chest, dealt three ways** |
| **Challenge** | a batch per lane, at the normal interval | **the center lane, all three** | its **spawning** lane's placed upgrades |

Both teams use the same intervals and counts in every phase, so an unmodified
match is exactly symmetric and any asymmetry on screen is the players' doing.
The figures are balance values held in the wave table and reported by the balance
validator; they are deliberately not written down in prose here.

Three things about that table are worth saying out loud because they are easy to
misread:

- **A surge is a stream, a challenge is not.** A challenge goes back to normal
  wave timing. The lull between waves is what lets a challenge monster lurch
  forward before the next wave lands on it; a stream would pin it in place
  forever, and a challenge that cannot advance is not a challenge.
- **During a surge, guards join the stream.** Towers stop putting patrols on the
  ground and that production emerges from the base as ordinary stream bodies.
- **During a challenge, a soldier keeps its spawning lane's upgrades**, not the
  center lane's, even though it fights in the center. Otherwise a team that had
  invested in the top lane would watch that investment vanish for the duration.

See [the siege-surge](014-the-siege-surge.md) and
[boons and the challenge](015-boons-and-the-challenge.md).

## "Fully defeated"

A wave is fully defeated when **`living_count` reaches zero and `killed_any` is
1.** Both halves matter:

- `living_count == 0` alone is not enough, because a wave can also empty out by
  its members walking into an enemy library and ending the game, or by being
  removed at match end. Neither of those should pay anybody.
- `killed_any` is set the first time a member dies to enemy damage of any kind —
  enemy soldiers, enemy towers, or an enemy challenge monster. A wave that dies
  entirely to towers still counts. The vision does not distinguish, and neither
  does this.

The check runs in the reap pass, immediately after a death is applied, on the
wave record that the dead soldier pointed at. It does not scan all waves every
tick. One death touches one wave.

## Who gets paid

**The team that wiped the wave draws the upgrade — that is, the team that did
*not* spawn it.** Team 1's chest fills up by killing team 2's soldiers. *Settled;
see [open questions](020-open-questions.md), A1.*

The consequence, stated plainly because it shapes everything downstream: a team
that is winning a lane is killing more waves in it and is therefore drawing more
upgrades, which wins the lane harder. **The upgrade economy is a snowball by
design, and the siege-surge is the only thing that brakes it.** Not by taking
upgrades away — the winning team still has more — but by destroying the
*arrangement*, and an arrangement rebuilt under fire by three people who disagree
is worse than one built at leisure.

The wave system's whole responsibility ends at raising one event:

    wave_wiped { wave_id, spawning_team, killing_team, lane, tick }

## The other ways an upgrade arrives

For completeness, because the wave path is only one of them:

1. **Wiping a wave** — one draw to the killing team. This document.
2. **Destroying a guard tower** — three draws at once to the destroying team.
   See [guard towers](007-guard-towers-and-their-guards.md).
3. **Slaying a challenge monster** — each player chooses a **boon** from three,
   in the calm afterwards. Not a draw from the deck; a separate catalogue, and
   the only upgrade in the game that belongs to a person rather than a team. See
   [boons and the challenge](015-boons-and-the-challenge.md).
4. **Rerolling** — a player spends personal resource to send an upgrade to the
   bottom of the deck and draw the next card. This does not *add* an upgrade; it
   trades one. See [the shared upgrade pool](009-the-shared-upgrade-pool.md).
5. Nothing else. There is no shop and no passive income, and resource can never
   buy an upgrade outright — only a reroll. Killing buys upgrades; resource buys
   bodies, and one narrow exchange.

Related: [a unit and what it carries](004-a-unit-and-what-it-carries.md) ·
[the shared upgrade pool](009-the-shared-upgrade-pool.md) ·
[the siege-surge](014-the-siege-surge.md)
