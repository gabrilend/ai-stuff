# 707 — A Monster Is A Lock

| | |
| --- | --- |
| Phase | 7 — The Delve |
| Blocked by | 403, 405, 602, 604, 701, 703, 704, 705, 706 |
| Blocks | nothing. This is the capstone. |
| Reads | [the delve](../docs/021-the-delve.md), [the monsters](../docs/023-the-monsters-of-the-delve.md) |
| Open questions | 3 (does "solve" mean solve) |

## Current behavior

The solution table is data, in the creature table, and `Delve.meets` is the one
function every pairing among the delve's creatures goes through — because a rule
per pair is nine rules that have to agree with a table of three.

The cycle runs, and the test asserts all three arms of it: automatons set vines
alight, vines hold golems still, golems smash automatons.

**What is not built is the part that makes it a mode rather than an aquarium.**
The party has no goal, does not lure, does not block a corridor with a long
weapon, and does not carry fire on purpose — the humans wander like everything
else, and the monsters solve each other whether anybody is watching or not. The
report does not count how many solutions happened with a party member nearby,
which was going to be the measure of whether the party was needed at all.

That is the honest state of it, and it rests on
[open question 3](../docs/026-open-questions.md): whether "solve" was meant
literally decides whether the party's contribution is *arranging the meeting* —
in which case all of the above is the mode — or whether the monsters are enemies
with health, in which case most of it is not wanted. It is not built on a guess.

## Intended behavior

The word the mode turns on is **solve**. Not fight, not kill. A monster is a lock
and the keys are each other:

| This | Undoes this |
| --- | --- |
| golem | automaton |
| automaton | vines |
| vines | golem |

Three monsters, three solutions, no fourth thing. A party carrying no answer to a
golem does not lose the fight — **it has no fight to have**, and must go around,
or go and find one.

The party's contribution is not damage. It is **arranging the meeting**, and the
four things it can do toward that are all mechanisms that already exist:

- **Move.** Being somewhere is most of it.
- **Lure.** A monster that can see a body follows it. Line of sight is issue 602
  and luring is walking where you can be seen.
- **Block.** A dinosaur with a long weapon holds a corridor it cannot itself
  enter, which decides which way a monster goes. Reach is the equipment field
  that changes behaviour rather than numbers.
- **Carry fire.** Issue 703, reused without being written as an ability.

This issue is the capstone because it adds almost nothing. If it needs new
machinery, one of the nine issues it depends on was built too specifically, and
finding that out is what a capstone is for.

## Suggested implementation steps

1. Write the solution table: monster kind to the condition that undoes it, as
   data.
2. Write the monster brains as goals over that table rather than as scripts: a
   monster pursues, a monster avoids what solves it if it can perceive it.
3. Write the party goal: reach a place, with monsters as terrain rather than as
   targets.
4. Write the delve's report: encounters, solutions achieved by each pairing,
   party members lost, and **how many solutions happened without a party member
   nearby** — the last being the measure of whether the monsters solve each other
   on their own, which is either the best thing in the mode or a sign the party
   is not needed.
5. Write a scenario per pairing, in `scenarios/`, each one a hand-built maze with
   two monsters and a corridor between them.
6. Test: each of the three pairings resolves as the table says, in a scenario, in
   a bounded number of ticks.

## Related documents and tools

- [The delve](../docs/021-the-delve.md)
- [The monsters of the delve](../docs/023-the-monsters-of-the-delve.md)
- [Open questions](../docs/026-open-questions.md) — question 3, which decides this whole issue

## Still open

Open question 3. If "solve" was meant loosely, this issue becomes a much smaller
one about monsters with health, and the solution table becomes a damage-type
chart. The design above is the literal reading and it is the more interesting
mode, but it is an interpretation of one word.
