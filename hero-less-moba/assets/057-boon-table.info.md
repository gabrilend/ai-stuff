# 057-boon-table

The three named monsters, the boons killing two of them pays, and how long each
stretch of a match lasts.

## What it is for

**Three challenges in a match, always the same three, in the same order.** A fixed
named sequence rather than a random draw: a player who has played one match knows
what is coming in the next and can build toward it — the same reasoning that put the
surge on a visible clock. The escalation is the point: the first two can be beaten,
and then the third one cannot.

## Exports

| Name | Meaning |
| --- | --- |
| `challenge` | Which body walks out, and whether killing it pays. |
| `timing` | Every duration in the shape of a match, in ticks. |
| `stream` | The surge's spawn interval. |
| `boon` | What killing a monster pays. |
| `boon_offer` | How many a player is offered. Two. |

## The sequence

| | | |
| --- | --- | --- |
| 1 | the Pillar Orc | killable, pays a boon |
| 2 | the Field Dragon | killable, pays a boon |
| 3 | **the Eternal Golem** | **cannot be killed, pays nothing, ends the match** |

**The deadline is the walk.** There is no separate timer, because a timer is a
number on a panel and a monster walking down the centre lane is a thing you can see.
A player who has never read a rules screen knows exactly how long is left, because
the time left is distance.

## The stream is one timer, not three

All lanes fire at the same instant, so a surge produces bodies in threes. That is
not tidiness — it is what makes the dealing possible, because at every spawn there
are exactly three new bodies and the whole holding can be split across them.

## Why boons are allowed where lane upgrades are not

A boon is not in a lane and has no slot, so **there is no placement decision for it
to multiply with.** A lane upgrade that also pumped the heroes standing in it would
let a team stack one lane, buy every hero into it, and compound a decision it only
had to make once. A boon is a modifier on the commander that radiates out to
everything that team fields, heroes included — and monsters get none, having no team
to belong to.

Two offered rather than three: a choice between two is a decision and a choice
between six is a menu.
