# 407 — The quality dial

## Current behavior

Done. `src/047-the-quality-dial.lua`.

```
luajit src/047-the-quality-dial.lua --category forest --floor 4
```

It reports the whole ladder rather than one number, because the question is
never "how many at four" on its own — it is "how many do I lose going from three
to four", and answering that needs both. The report is not optional and cannot
be turned off: a filter that quietly returns five things where there were seven
is the failure this file exists to prevent, and making the telling optional is
exactly how it would come back.

The tests assert the *telling* rather than the filtering, for the same reason.
That the counts are right is arithmetic. That the cost is said out loud before
the floor moves is the requirement, and it is the one a later tidy-up would
drop. There is no way to say *the forest ones are looking
bad* and have anything happen.

## Intended behavior

**A floor per world, set when a run happens, and the system says what raising it
costs before it is raised.**

The exchange this exists for:

> *the forest ones are looking pretty bad — can we raise their quality?*
> raising forest from 3 to 4 leaves 31 to draw from instead of 214, so expect
> them to start resembling each other.
> *that's fine.*
> do you want to look through the 47 unrated ones and set some yourself?
> *not now.*

Four things fall out of that and all four are requirements.

**The floor is per-category and set at run time.** Not global, not a build-time
constant. Quality is a thing turned up on *the forest ones* because the forest
ones are what is bothering somebody.

**Raising it costs variety and that is reported before it happens.** The size of
the surviving set at the current floor and at the proposed one, at the moment of
choosing. This is the same axis that decides whether a trained system memorises
or wanders, pulled out of the internals and put where a person can reach it.

**Provenance is a second dial.** *Tier 4 or better* and *tier 4 or better as
judged by a person* are different requests; the second is smaller and more
trustworthy. Confidence and quality are not the same axis and collapsing them
loses the distinction exactly when it matters.

**Re-rating is offered with its cost attached, and declining is free.** A studio
that nags is a studio nobody opens. *Not now* must cost nothing and must not be
asked twice in the same breath.

**What survives the filter has two uses and both must work.** Shown to whatever
writes the next scene, as examples of what good looks like in this world — and
used directly, because reuse is cheaper than regeneration and often better.

## Suggested implementation steps

1. **The dial is a query against the walker in `405`** and holds no state of its
   own. It reports before it filters, always, in the same call.

2. **The report is the point, not the filter.** A filter that quietly returns
   thirty-one things where there were two hundred is the failure this ticket
   exists to prevent.

3. **Test the reporting rather than the filtering.** That the count at each
   floor is right is arithmetic; that the count is *said out loud before the
   floor moves* is the requirement, and it is the one that will be quietly
   dropped in some later refactor.

## Related

`405` — the pool it reads. `406` — where tiers come from.
