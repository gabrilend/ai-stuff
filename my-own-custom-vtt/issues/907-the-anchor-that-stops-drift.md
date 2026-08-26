# 907 -- The anchor that stops drift

**Phase:** 9, the sprite studio
**Blocked by:** [905](905-the-machine-grader-is-a-heuristic.md),
[906](906-the-quality-dial.md)
**Blocks:** [908](908-the-phase-nine-demo.md)
**Documents:** [the sprite studio](../docs/017-the-sprite-studio.md)

## Current behaviour

Ratings accumulate. Generation could draw on them. Nothing watches whether the
machine's taste and a person's are still the same thing.

## Intended behaviour

### The ladder

A pool retrieved into the brief is the bottom rung and it works immediately: the
best previous sprites for this category are shown before a new one is written.
Improves from the very first judgment; costs only storage.

Above it: per-category brief refinement, then a small adapter retrained on
accumulated preference pairs, then a full reinforcement loop.

**You cannot reach the top rung until the machine grader is calibrated, and you
calibrate it with the agreement data the bottom rungs generate for free.** So the
cheap thing and the prerequisite are the same thing. Build upward and never skip.

Only the bottom rung is built here. The rest are named so that somebody reaching
for the fourth without the first knows what they are missing.

### The floor that stops it drifting

A generator improved by a grader that is itself being tuned is **a loop with no
anchor**.

Let a person's ratings become rare relative to the machine's, and the whole
apparatus converges smoothly on *the grader's* taste rather than yours — with no
error raised anywhere — and you find out months later by not liking the output.

So:

- **A guaranteed minimum fraction of work gets a person's rating.** Below it, the
  studio says so.
- **The agreement rate is reported where it can be seen**, not computed and filed.
- If agreement falls, the grader has drifted and its ratings are **suspect until
  re-anchored**.

### Algorithm B has no such failure

Every rating is a person's, so there is nothing to drift from. It pays for that
with a pool the size of one person's patience.

That asymmetry is worth stating plainly, because it is the real difference between
the two algorithms and it is not the one people notice first.

## Suggested implementation steps

1. Compute the agreement rate from the pool: where both a machine tier and a
   person's exist, how often they match.
2. Compute the human-rated fraction.
3. Report both wherever the pool is summarised.
4. Say plainly when the fraction is below the floor.
5. Test: a pool with no human ratings reports an unmeasurable agreement rather
   than a perfect one — **a rate computed from nothing must not read as
   agreement.**
