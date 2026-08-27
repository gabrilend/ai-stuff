# 1206 -- The phase twelve demo

**Phase:** 12, the table as it is actually played
**Blocked by:** every other issue in phase 12.
**Blocks:** nothing.
**Documents:** [the roadmap](../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` offers phases 1 through 11.

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
