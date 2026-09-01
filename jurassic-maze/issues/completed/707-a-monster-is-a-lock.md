# 707 — A Monster Is A Lock

| | |
| --- | --- |
| Phase | 7 — The Delve |
| Blocked by | 403, 405, 602, 604, 701, 703, 704, 705, 706 |
| Blocks | nothing. This is the capstone. |
| Reads | [the delve](../../docs/021-the-delve.md), [the monsters](../../docs/023-the-monsters-of-the-delve.md) |
| Open questions | 3 (does "solve" mean solve) |

## Current behavior

**The premise of this issue was answered and it went the other way.** "Solve" was
meant loosely: the monsters are enemies with health, a party fights them, and the
cycle between the three of them is a damage-type chart rather than the point of
the mode. The intended behaviour below is left exactly as it was written, because
it is the design that was *not* chosen and the record is worth more than the
tidiness.

What is built instead:

**The chart.** Every monster has a `resist` field, a multiplier per damage type.
Fire does nothing at all to stone and ruins a plant; weight ends a wooden machine
and is most of what tells against a golem. A human carries fire and a dinosaur
carries weight, and **neither alone is an answer to all three** — which is what
makes a party a party, expressed as a table rather than as a rule.

**The fighting is the fencing.** Two bodies of opposing sides that can hurt each
other start a duel: the same record, the same buffered damage, the same four
endings, the same camera verdict as two fencers in phase five. Generalising that
machinery beyond fencers is what turned this mode from a design into a running
thing in an afternoon — it already existed, already worked, and already had
tests.

The one thing that had to change in it: each side now uses its **own** numbers. A
duel between two fencers is symmetric and it did not matter; a duel between a
human with a torch and a stone golem is not, and reading both sides' stats off
whichever body happened to be stored first would have given the golem a human's
skill depending only on array order.

**A dinosaur's weapon has reach two.** It can strike a body two cells away, which
means it can fight down a corridor it cannot itself enter — the mounted party's
answer to the narrow places it cannot go, and the one field here that changes
behaviour rather than numbers.

**What is deliberately not built**, and is not wanted under this reading: the
party has no goal, does not lure, and does not block corridors on purpose. Those
belonged to the other design, where the party's whole contribution was arranging
a meeting between two monsters. Here the party's contribution is being equipped,
and it is.

## Intended behavior — **the design that was not chosen**

Kept verbatim. The question underneath it was asked and answered in the other
direction; see the current behaviour above and
[open question 3](../../docs/026-open-questions.md), which records both readings.



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

- [The delve](../../docs/021-the-delve.md)
- [The monsters of the delve](../../docs/023-the-monsters-of-the-delve.md)
- [Open questions](../../docs/026-open-questions.md) — question 3, which decides this whole issue

## Settled

Open question 3 is answered: loosely. This issue became the smaller one about
monsters with health, and the solution table became a damage-type chart.

Worth recording what survived the change, because it is an argument about where
to put things. The three monsters, their locomotion, the fire model, the
entangling, the wall-breaking and the automaton catching fire from its own work
were all built for the *other* reading and every one of them stayed — because
none of them was about who was fighting whom. What was thrown away was a set of
rules saying which monster undoes which, and it was thrown away in favour of a
table of nine numbers.
