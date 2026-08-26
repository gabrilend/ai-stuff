# 906 -- The quality dial

**Phase:** 9, the sprite studio
**Blocked by:** [904](904-two-ways-of-rating.md)
**Blocks:** [908](908-the-phase-nine-demo.md)
**Documents:** [the sprite studio](../docs/017-the-sprite-studio.md)

## Current behaviour

A rated pool. Nothing queries it.

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
