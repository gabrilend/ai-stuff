# 058-phases

The shape of a match.

## What it is for

Four phases, each changing what spawns, where it goes, and what it carries. The grid
lives in one document and is built here as one table — a table copied into three
places is a table that will disagree with itself, and this one already had.

| | spawn | goes to | carries | towers | chest grows |
| --- | --- | --- | --- | --- | --- |
| **normal** | waves per lane | its own lane | lane slots | normal | yes |
| **surge** | a stream, in threes | its own lane | **a deal** | bare, unkillable | **no** |
| **challenge** | waves per lane | **the centre** | its **spawning** lane | normal | yes |
| **calm** | nothing | home | — | normal | — |

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — |
| `advance(world)` | | — The match clock. Once a tick. |
| `stream_pass(world)` | | — The surge's spawner. |
| `total_holding(world, team, into)` | | Everything a team owns, wherever it sits, as a flat list. |
| `monster_died(world, assigned_team, archetype)` | | — |
| `choose_boon(world, player, boon_id)` | | A verdict. |
| `spawn_lane_for(world, lane)` | | Where a wave raised for this lane actually walks. |

## The surge, in one idea

**Arrangement stops mattering, without anything being taken away.**

Nothing is confiscated, moved, emptied, or held back. Whatever a team slotted into
the top lane stays slotted there for the whole surge, and placement stays open the
entire time — it simply has no effect until the surge ends, which is exactly when
the challenge starts and a completely different kind of fight needs a completely
different board.

What the surge does instead is **stop reading slots**. Every spawn, the team's whole
holding — placed, slotted, unplaced, indistinguishable — is dealt across the three
bodies leaving that instant, from a random start, one upgrade at a time. Half a
second later it happens again, from scratch.

An earlier draft had the surge confiscate the board and hand it back. Watching your
arrangement come apart without touching it was frustrating in a way nothing bought
back. **Upgrades are never moved except by a player's own hand.**

Two consequences fall out rather than being written: a team **cannot hold upgrades
back** before a surge to protect them, because there is nothing to protect them
from; and **the chest cannot grow**, because a stream body belongs to no wave, "wiped"
is a statement about a group, and towers are unkillable for the duration.

## The challenge, in one idea

The whole match compresses into one corridor. Waves come back — not the stream — and
every lane's production goes into the middle.

**The lull between waves is the point.** A stream would pin a monster in place
forever, because there would always be another body arriving. Waves give it room to
**lurch**: it walks while the lane is empty and slows when the next wave lands on
it, and a challenge you can watch advancing in stages is readable in a way a
continuous grind is not.

A funnelled body carries **the upgrades of the lane it was spawned for**, not the
centre's — so placing into the top lane during a challenge still means something.
The cost is legibility: three bodies walking side by side can have wildly different
strength, which is why the snapshot carries each body's spawning lane separately.

**Push depth is ignored outright**, because the only bodies left in the side lanes
are each team's own guards at their own towers, and the number would read a team's
stone back at it.

## A monster is on nobody's side

Team 3. Allied with nobody, hostile to everything, including the other monster.
Without that, one aimed at team 1's base would be functionally an ally of team 2 for
the whole phase — fighting alongside them, in their direction, at no cost.

Each is nevertheless **assigned** to one team: the one whose base it walks at, and
whose test it is. That is bookkeeping rather than allegiance and decides exactly one
thing — the assigned team is paid the boon, whoever landed the blow. A team cannot
reach into the middle, finish the enemy's monster, and take their reward.

## The calm

Everything on the field turns round and walks home. Leaving the map is a thing the
brain already knows how to do, so this is a flip of two fields rather than a new
behaviour. Wave units vanish on arrival; **heroes hand back what they cost.**

That refund is narrow on purpose and applies to nothing else. What it buys is that
throwing everything you have at a monster is the correct move rather than a gamble
against your own next three minutes — the one fight designed to be fought all-in is
the one you are allowed to go all-in on.

## An offer outlives the calm it was made in

A boon still unchosen when the calm ends **stays on offer**. Nothing is taken for
anybody, here or anywhere else in the project.

Three ways of handling it were considered and two are worth recording because each
looked reasonable:

**Take it for them** breaks the rule the rest of the design keeps absolutely — every
refusal is named and handed back, no spawn is redirected, no upgrade moves except by
somebody's own hand.

**Take it, but allow a swap later** is worse, and worse in an instructive way: it
makes never choosing the correct play. Let the timer run out, see how the match
develops, then swap into whatever turned out to matter. A rule that rewards not
answering teaches an awkward, bent way of playing.

**Letting it lapse** punishes a team for one player looking away.

So the calm is simply long enough to choose in, and the offer stays open. Being slow
costs you the use of it in the meantime and costs your team nothing.
