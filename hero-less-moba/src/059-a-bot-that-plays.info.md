# 059-a-bot-that-plays

Somebody to make the decisions, when nobody is at the keyboard.

## What it is for

**This is the measuring bot, not the opponent.** The distinction matters: a bot
built to produce balance numbers wants to be cheap, deterministic and dull; a bot
built to be played against wants to be varied, surprising, and occasionally wrong in
the way a person is wrong. This is the first, and everything in it is a rule of
thumb applied the same way every time.

It exists for two reasons and the second is the surprising one.

The obvious one: ten thousand matches overnight need somebody to play them.

The other: **without it a match does not demonstrate its own premise.** Left alone
the chest fills up and nothing happens, because nothing is placing it — so the one
thing the whole design is about is the one thing an unattended match never shows.
That is not a stalemate the design predicted; it is an empty chair.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world, teams)` | array of team numbers | — Puts a bot behind each. |
| `run(world)` | | — Every bot looks at the board, on its own slow clock. |

Which teams are bot-played comes from `input/bots`, which is the one input file
allowed to be missing — "nobody is a bot" is a real answer rather than an unmade
decision.

## The whole policy

**Reinforce where you are losing, unless you are losing nowhere, in which case press
where you are winning.**

That is it. Both halves are read off push depth, which is how the game measures
everything, and neither is a distance. A person would do more. A measuring bot
should not, because every extra rule is another thing that has to be held constant
while something else is being measured.

Stone gets every fourth placement, on a fixed rotation rather than a judgement, so
that both halves of the placement decision appear in the numbers rather than only
the one the bot happened to prefer.

Heroes go to the library — the slow, safe destination — unless the losing lane is
already past its midpoint, in which case they go to whichever tower in it will still
accept one. It never picks the wave, because arriving at the frontline is the
aggressive read and a measuring bot should not be making aggressive reads.

Boons: it takes the first offered. **Deliberately not a choice.** Whichever it
preferred would become an invisible constant in every number a balance run produced.

## What it goes through

The ordinary command queue, on the same tick, in the same fixed order a person's
click uses. A bot with a private path into the world would be a second door, and the
whole point of the first one is that there is only one.

It thinks every ninety ticks, not every tick — cheap, human-paced, and slower than
the waves that read what it places.

## What it does not do

**Three bots sharing one chest.** That is phase nine's problem and a genuinely hard
one: a teammate that tramples a person's arrangement every wave, or is so passive
that the shared chest becomes single-player. This bot plays a whole side, which
sidesteps it entirely — and says so rather than pretending the problem is solved.

**Anything a player could not see.** It reads the world table directly rather than a
snapshot, which is a shortcut a networked bot could not take, but it takes no
decision a player could not take from what is on their screen.

## What it produced on the first run

From one seed, both teams bot-played: **team 1 wins at about thirteen minutes**, with
128 upgrades drawn and only 9 of them still unplaced. Push depths of 7/7/2 against
0/0/5 — two lanes taken and one held. Which is the first time this project has
produced a match with a shape somebody could describe afterwards.
