# 907 -- The anchor that stops drift

**Phase:** 9, the sprite studio
**Blocked by:** [905](905-the-machine-grader-is-a-heuristic.md),
[906](906-the-quality-dial.md)
**Blocks:** [908](908-the-phase-nine-demo.md)
**Documents:** [the sprite studio](../docs/017-the-sprite-studio.md)

## Current behaviour

**Done, for the bottom rung.** The measurements exist and are reported where they
can be seen.

`studio_agreement` counts the entries carrying both a machine tier and a
person's, how often they matched exactly, how often they came within one, and
which way the machine leans. The lean is worth having separately from the rate
because they answer different questions: the rate says how often the machine is
wrong, and the lean says WHICH WAY — and a grader that is consistently one tier
generous can be corrected rather than replaced.

`studio_anchor` gives the human-rated fraction against a floor of five per cent,
and says plainly when it is below: *the machine's taste is drifting away from
yours with nothing pulling it back, and no error will ever be raised about it.*

**A rate computed from nothing does not read as agreement.** Three standings, not
two:

| Standing | When | Why it is separate |
| --- | --- | --- |
| UNMEASURABLE | no entry carries both opinions | Zero out of zero is not perfect. It is silence. |
| THIN | fewer than twenty pairs | Three out of three is a hundred per cent, and swings thirty points on the fourth. |
| MEASURED | twenty or more | A number worth deciding on. |

Both the unmeasurable and the thin cases have tests, and both check that no
percentage appears in the sentence.

**Algorithm B's asymmetry is measured rather than asserted.** A judge-then-curate
pool reports its fraction as everything and its agreement as unmeasurable,
because every rating is a person's and there is nothing to drift from.

### The ladder

Only the bottom rung is built, and the rest are named in
[the sprite studio](../docs/017-the-sprite-studio.md) so that somebody reaching
for the fourth without the first knows what they are missing. The pool can be
queried for the best previous sprites in a category, which is the retrieval the
bottom rung needs; nothing yet feeds them into a brief, because nothing yet
writes briefs.

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
