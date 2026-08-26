# 605 -- The tavern commands its crockery

**Phase:** 6, control is a dial
**Blocked by:** [602](602-membership-is-a-list-or-a-region.md),
[604](604-a-viewer-holds-several-scopes.md)
**Blocks:** [607](607-the-phase-six-demo.md)
**Documents:** [who controls what](../../docs/008-who-controls-what.md)
**Open questions:** [6.2](../../docs/016-open-questions.md) — "usually weaker but
not always".

## Current behaviour

Scopes, membership, and styles exist. Nothing has yet been handed a building.

## Intended behaviour

Somebody is given the tavern. They move the coffee cups, light the fires, and
have the barman look up at the right moment.

### The point of this issue is that it should require no new code

If [601](601-a-scope-is-a-record.md) through
[604](604-a-viewer-holds-several-scopes.md) are right, this is **configuration**:
a scope with `REGION` membership over the tavern's region, `ORDERED` style,
probably `SEES_REGION`.

The code that moves a coffee cup is the code that moves a goblin, because a
coffee cup **is** a thing record with a position and an owning scope. There is no
prop system beside the creature system, no second movement path, no second sight
rule.

**If this issue turns out to need new code, something earlier was wrong**, and the
right response is to find which of the four rather than to add a special case
here. That is the test this issue exists to be.

### What it is really testing

That the dial is one mechanism. A player walking down a corridor and a person
playing a building go through the same gauntlet, the same membership question,
the same motion pass, and the same filter.

### Strength, which is not enforced

The vision says a commander's units are "usually weaker but not always". Nothing
here enforces that, and nothing should: the server has no idea what strength is.
If it is a rule it is a **ruleset's** rule, and if it is a convention it is the
GM's business when handing out scopes.

[6.2](../../docs/016-open-questions.md) stays open, and this issue is where somebody
would notice they wanted it.

## Suggested implementation steps

1. Add crockery to the fixture: a few cups and a table in a room, plus a body that
   can be walked about.
2. Configure a region scope over that room.
3. Confirm the holder can move the cups and cannot move anything outside it.
4. Confirm a player elsewhere cannot move the cups, and is refused **in words**.
5. Write nothing else. If more is needed, say so loudly rather than writing it.
