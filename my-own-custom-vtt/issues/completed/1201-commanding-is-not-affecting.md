# 1201 -- Commanding is not affecting

**Phase:** 12, the table as it is actually played
**Blocked by:** phase 11 complete.
**Blocks:** [1206](../1206-the-phase-twelve-demo.md)
**Documents:** [who controls what](../../docs/008-who-controls-what.md),
[the rules layer](../../docs/011-the-rules-layer.md)

## Current behaviour

**Done.** `VERB_INTERACT` carries a subject and an intent number, and it skips the
membership gate entirely.

The gate that replaces it is **what the outbound filter told you about**. The
session keeps one bit per viewer per thing, written by the only function allowed
to put a thing on a socket and cleared at the top of every update. So it is the
same decision, remembered — not a second one that agrees most of the time.

That mattered more than it looked. Recomputing visibility in the command path
would have been easy and would have created two answers to *can this person see
that*, which is how a permission model develops a hole nobody can find. It is
also free, because the answer was already computed this beat to decide what to
send.

Stated as the thing it actually is: **you may act on what you were told about.**

### It is performed by the session, and has no handler in the verb table

Deliberately. It needs the record of what a viewer was told and it needs the
ruleset, and only the session has both. The row in the verb table is a null, and
`command_perform` refuses a null by name rather than crashing into it — so the
scripted path with no session behind it cannot perform an interaction at all,
which is correct rather than a hole.

### Four refusals

| Refusal | When |
| --- | --- |
| `REFUSED_SUBJECT_IS_NOTHING` / `NO_SUCH_SUBJECT` | the index is wrong however you meant it |
| `REFUSED_CANNOT_SEE_IT` | you were not told it is there |
| `REFUSED_NO_RULES_FOR_THAT` | there is no ruleset attached at all |
| `REFUSED_BY_THE_RULES` | the ruleset declined, in its own sentence |

A ruleset with no `on_interact` hook refuses every attempt and says so, which is
correct: a table with no rules about poisoning drinks is a table where you cannot
poison a drink.

### The sample ruleset has four intents

Poison the drink (a saving throw), spring a trapdoor, refuse them mead, and offer
a bounty on bugbears. The last one changes nothing about the subject at all,
which is there on purpose: an interaction is not required to be an attack, and a
ruleset that only allowed attacks would have quietly turned this into a combat
system.

## Intended behaviour

**Ownership is the right to move a piece. It is not a fence around it.**

That distinction was missing from the documents and from the code, and it is the
answer to the question this project had been carrying since phase 6: when a
goblin patrol walks out of the forest and into the tavern, whose is it?

> It is owned by the forest, it obeys its commands, but if the person controlling
> the tavern wants to do something to it — activate a trap door, poison their
> drinks, offer a bounty on bugbears, decline them mead — it can do so. Player
> ownership in this case refers to the ability to move the pieces on the board and
> wield them to do things. It does not determine who is able to affect other
> things — you can absolutely kill the goblins, tavern-owner. **But you better
> explain how.**

### Two different questions, and they had one gate between them

| Question | Gate | Answer |
| --- | --- | --- |
| May I *move* this? | membership | Only if it is in a scope you hold. |
| May I *act on* this? | sight, then the ruleset | If you can see it, you may try. The ruleset decides what happens. |

The first is unchanged. The second is new, and it is one verb.

### "But you better explain how" is the ruleset's job

That sentence is the whole design. The server must not decide whether poisoning a
drink works — it does not know what a drink is. What it knows is:

**You can see it**, which is the gate, and it is a gate that already exists in a
different form: the outbound filter already computes, per viewer, exactly which
things are visible. Acting on something you cannot see is refused for the same
reason you are not told it is there.

**You said what you were doing**, as a number the ruleset understands. The verb
carries an *intent* the ruleset catalogues, not an English sentence — a closed
set, the same shape as the paintbrush.

**The ruleset says what happens**, through the `on_interact` hook, which has been
in the hook table since phase 7 and has never been called by anything.

### Why this is one verb and not a family

Because the server has no opinion about what acting on something means, so it has
nothing to distinguish one from another. `VERB_INTERACT` with an intent number is
the whole of what the server can honestly express.

A ruleset that wants twelve kinds of interaction gives them twelve numbers. A
ruleset that wants none never registers the hook and every attempt is refused,
which is correct: a table with no rules about poisoning drinks is a table where
you cannot poison a drink.

### What it must refuse

| Refusal | Because |
| --- | --- |
| you cannot see it | The same rule as not being told it is there. Otherwise this is a way to probe the dark. |
| there is no ruleset | Nothing knows what your intent means, and guessing would be the server having opinions. |
| the ruleset declined | With the ruleset's own sentence, the way gate 6 already works. |

**The sight gate is a security boundary, not a convenience.** It must be computed
the same way the outbound filter computes it, from the same data, or there are two
answers to "can this person see that" and they will disagree.

## Suggested implementation steps

1. `VERB_INTERACT`, with the subject and an intent number.
2. A gate that asks whether the sender's viewpoint contains the subject, using
   the same visibility the outbound filter uses.
3. Call `on_interact`, and refuse with its sentence when it declines.
4. Test: a viewer can act on something they can see and do not own; cannot act on
   something they cannot see; and gets a refusal naming the ruleset when there is
   none.
5. Say all of this in [who controls what](../../docs/008-who-controls-what.md), which
   currently describes ownership as though it were the only permission there is.
