# 607 -- The phase six demo

**Phase:** 6, control is a dial
**Blocked by:** every other issue in phase 6.
**Blocks:** nothing. The capstone.
**Documents:** [the roadmap](../../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` offers phases 1 through 5.

## Intended behaviour

**One server, four connections, four different points on the dial, all in the same
room at the same time.**

| Seat | Scope |
| --- | --- |
| A player | One body, `LIST` of one, `DRIVEN`. |
| A commander | Four bodies, `LIST`, `ORDERED`. |
| The tavern | A `REGION` over one room, `ORDERED`, `SEES_REGION`. |
| A GM | `REGION` over the whole map, `SEES_ALL`, `MAY_EDIT_WORLD`. |

### What it must show

**That they are the same mechanism.** For each seat, print how many things it
contains, which rule decided, and what its holder can see. Four rows of one table
rather than four descriptions.

**That the gauntlet refuses across seats.** The player tries to move a coffee cup.
The tavern tries to move the player. Both refused, in words, showing the sentence.

**That the tavern needed no new code.** Say so, and say what would have been true
if it had — that one of the earlier issues was wrong.

**The patrol crossing.** Walk a body from the tavern into open ground and show
which scope contains it before and after, on the beat it crosses. That is
[6.1](../../docs/016-open-questions.md) made visible so somebody can form an opinion
about whether it is what they want.

**A handover.** Give the tavern to somebody else and show the old holder being
refused and the new one accepted.

### And the numbers

| Reported | Why |
| --- | --- |
| Bodies per scope | The dial's positions as sizes. |
| Sweeps per beat, per viewer | A commander with six goblins runs the sweep six times. |
| Cost with and without `SEES_ALL` | Whether the flag is an optimisation or a necessity. |
| Cost with and without `SEES_REGION` | The same question for the middle of the dial. |

Those last two are what [4.3](../../docs/016-open-questions.md) — how large a table
can get — has been waiting for.

## Suggested implementation steps

1. In-process, several viewers, no browser. The claim is about permission, and a
   browser proves nothing about it.
2. Build the four scopes as configuration and print them as a table.
3. Provoke each refusal deliberately and show the sentence.
4. Report the sweep costs at each dial position.
5. Confirm `./run-phase-demo 6`.
