# 904 -- Two ways of rating

**Phase:** 9, the sprite studio
**Blocked by:** [903](903-the-pool-keeps-everything.md)
**Blocks:** [906](906-the-quality-dial.md)
**Documents:** [the sprite studio](../docs/017-the-sprite-studio.md)

## Current behaviour

A pool exists with a tier field nothing writes.

## Intended behaviour

**Both algorithms. Both tested. Neither counts as built until both work.**

### Algorithm A — rate on arrival, correct on inspection

The machine rates **everything**, the moment it is generated. A person rates a
little, whenever they feel like it. Both write the same field; the person's wins
and is marked as theirs.

It exists because of an arithmetic problem: if everything is kept and only a
little is looked at, the pool is overwhelmingly unrated and a floor of "tier 4 or
better" would exclude nearly the whole library.

It pays twice. Wherever both a machine tier and a person's exist for one sprite,
that is a **free, continuous measurement of how often the machine agrees with
you** — no evaluation exercise ever run. A machine grader nobody has measured is
not a grader, it is a rumour.

**Shape: large pool, thin judgment, measured.**

### Algorithm B — judge the pool, then curate in play

A person passes over the whole library once and tiers everything. From then on
the rating happens **during play**: mid-session, the moment somebody looks at a
goblin and thinks *that one is wrong*, they change its tier right there.

Three things it has that A does not:

**Every rating is a person's**, so provenance is uniform — and there is no
agreement rate, because there is nothing to compare against.

**The judgment happens in context.** This is the real argument and it is
specifically a tabletop argument: a sprite judged in a gallery is judged as a
picture; the same sprite judged mid-session is judged on *did that read as a
goblin at the moment I needed it to, at that size, in that light, next to those
other things.* That is a better question and it can only be asked while playing.

**The pool is bounded by patience** — and that limit is also the source of the
quality, because everything in it has been looked at.

**Shape: small pool, complete judgment, contextual.**

### Neither is the better one

A is for ten thousand generated dandelions. B is for the forty things that
actually appear in your campaign. Which one a table runs is a setting, and
switching costs nothing because both write the same field.

### The in-play re-rating comes through the same door

`VERB_RETIER` already exists in the command table. It changes nothing in the
world and runs the same gauntlet as everything else — which means the rating
store has to be reachable from a live session.

## Suggested implementation steps

1. The machine grader: a scorer over the sprite. Honest about being a heuristic.
2. Rate on ingest under A; leave unrated under B until the opening pass.
3. `pool_rate` records who and when, always.
4. The agreement rate, computed from the pool rather than measured separately.
5. Wire `VERB_RETIER` to the pool.
6. **Test both algorithms.** A mode that is not tested is a mode that is broken.
