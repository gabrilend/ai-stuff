# 906 -- The quality dial

**Phase:** 9, the sprite studio
**Blocked by:** [904](904-two-ways-of-rating.md)
**Blocks:** [908](908-the-phase-nine-demo.md)
**Documents:** [the sprite studio](../../docs/017-the-sprite-studio.md)

## Current behaviour

**Done.** `pool_survivors` answers the query and `studio_dial_report` compares two
floors without applying either — the answer arrives while the question is still
open, which is the whole point.

`studio_dial_sentence` writes the exchange: the category, both counts, how many
are in the category at all, and a consequence drawn from a small table of how
much variety survives. "Expect them to start resembling each other" is what a
quarter surviving reads as; the thresholds are in one table where they can be
argued with rather than spread through a chain of comparisons.

Lowering a floor says the opposite thing rather than announcing a cost, because
variety is being bought back rather than spent.

**Both provenance modes.** `TRUST_ANYBODY` and `TRUST_A_PERSON` are separate
requests and the second is always smaller. Confidence and quality are not the
same axis, and a pool nobody has judged returns nothing at all under the strict
question — which is the honest answer and not an empty category.

**Declining is free.** `studio_decline` records the refusal and touches nothing
about the library — no tier, no entry, no ordering — and there is a test that
checks exactly that. The offer carries its own cost, saying how many are unrated
and what rating them would buy, because a question with no price on it has no
honest answer.

`studio_may_offer` is per category: turning down the goblins is not turning down
everything.

### What the retrieved entries are not yet used for

`pool_survivors` returns the surviving entries as well as the count, so both uses
this issue names are reachable: shown as examples of what good looks like here,
and used directly. Nothing calls it for the first use yet, because nothing
generates sprites from examples — that is the second rung of the ladder in
[907](907-the-anchor-that-stops-drift.md) and only the bottom rung is built.

## Intended behaviour

The pool is **a live asset library, queried at generation time**, and the tier is
the filter.

The exchange this exists for:

> *"The goblin sprites are looking pretty bad — can we increase their quality?"*
> "Yes. Raising the floor for that category from 3 to 4 leaves 31 to draw from
> instead of 214, so expect them to start resembling each other."
> *"That's okay."*
> "Do you want to look through the unreviewed ones and set some ratings
> yourself?"
> *"No, not now, thanks."*

Four mechanics fall out, and all four are requirements.

**The floor is per-category and set at run time.** Not global, not a build-time
constant. You raise quality on *the goblins*, because the goblins are what is
bothering you.

**Raising it costs variety, and the system says so before it happens.** Report the
surviving count at the current floor and at the proposed one. The trade must be
visible at the moment of choosing, not discovered afterwards in the output.

That is the same axis that decides whether a trained system memorises or wanders,
pulled out of the internals and put where a person can reach it.

**There is a second dial: provenance.** "Tier 4 or better" and "tier 4 or better
*as judged by a person*" are different requests, and the second is smaller and
more trustworthy. Offer both — confidence and quality are not the same axis, and
collapsing them loses the distinction exactly when it matters.

**Re-rating is offered, never forced, and declining is free.** The offer carries
its own cost so the answer can be informed. **A studio that nags is a studio
nobody opens.** "Not now" must cost nothing and must not be asked again in the
same breath.

### Retrieved entries have two uses

Shown to whatever generates the next sprite as **examples of what good looks like
here**, and **used directly** — because reuse is cheaper than regeneration and
often better than it. The design must allow both.

## Suggested implementation steps

1. `pool_survivors(category, floor, provenance)` returning a count and a list.
2. A report comparing two floors before either is applied.
3. Both provenance modes.
4. Make the offer to re-rate carry its cost, and make declining a no-op.
5. Test the reported counts against the pool, and that raising a floor never
   increases the survivors.
