# 1206 -- The phase twelve demo

**Phase:** 12, the table as it is actually played
**Blocked by:** every other issue in phase 12.
**Blocks:** nothing.
**Documents:** [the roadmap](../../docs/015-roadmap.md)

## Current behaviour

**Done.** `./run-phase-demo 12`.

A goblin patrol in somebody else's tavern, with both halves of the rule shown as
a pair: the forest moves it and the tavern cannot, then the tavern poisons its
drink, springs a trapdoor under it, refuses it mead and puts a bounty on it —
every one with the sentence the ruleset wrote. Then an intent the game has no rule
for, refused in the game's own words. Then the same attempt with the thing out of
sight, refused for a different reason.

Then the same attempt against the ruleset that has no opinion about acting on
things, refused because nothing knows what the intent means.

Then somebody removed and what they did unwound, compared by checksum against a
world where they sat there, said nothing, and were removed just the same.

Then the dial turned through five settings with its diagram and the world point
each one resolves to.

Then twelve commands accepted on twelve consecutive beats across three turn
boundaries, because nothing was ever waiting.

### The demo found two things, which is what a demo is for

**The comparison was wrong before the code was.** Comparing "removed and unwound"
against "never existed" compares two different questions, because removing
somebody genuinely changes the world — their scope is unheld, and who holds a
scope is part of the checksum. The comparison world had to have the guest in it,
sitting quietly, removed the same way.

**Unwind first, then remove.** A rollback that reaches back past a removal undoes
the removal, and the person is back at the table. Nothing is wrong with either
piece: **the order is a fact about how they compose**, which means it lives in
whatever uses both and nothing local will ever tell you about it. It is written
down in [1203](1203-and-undo-what-they-did.md) and in
[the door and the private port](../../docs/003-the-door-and-the-private-port.md) now.

## Intended behaviour

### What it shows

**A goblin patrol in somebody else's tavern.** The forest's commander moves it and
the tavern's owner cannot. The tavern's owner poisons its drink and the forest's
commander cannot stop them. Both refusals and both successes printed with the
sentence that produced them, because the whole point is the pair.

**A ruleset that has no opinion about poisoning.** The same attempt against the
other ruleset, refused because nothing knows what the intent means — which is the
server being honest about having no opinion rather than inventing one.

**Somebody removed, and what they did unwound.** Two people act; one is removed;
the world is replayed without their commands and the other person's actions
survive exactly. Compared by world hash against a run where the removed person
never issued anything at all.

**The dial, resolved.** The three dials turned through several positions, with the
diagram printed at each, and the world point each combination resolves to —
showing that the resolution is arithmetic and that nothing about direction or
distance ever reaches the server.

### And the honesty

Say that nothing checks who anybody is, that this is the decided answer, and that
it is only defensible because the two things above exist. Say that a removed
person can knock again.

## Suggested implementation steps

1. Two commanders, one patrol, one tavern.
2. Both directions of the ownership rule, with sentences.
3. A removal and an expunge, compared by hash.
4. The dial resolution table.
5. Confirm `./run-phase-demo 12`.
