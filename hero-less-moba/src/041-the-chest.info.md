# 041-the-chest

The shared upgrade pool: the deck, the draws, the slots, and the stamp a body takes
at birth.

## What it is for

The centre of the game. Everything about how an upgrade turns into a larger number on
a specific blow lives here.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `build_deck(world)` | | — The one shared sequence, generated once at match start. |
| `draw(world, team_id, count)` | | — Takes upgrades off the deck into a chest. |
| `apply_counts(world, id, counts)` | | — Folds a count vector into a body's fields. |
| `stamp_from_lane(world, id, team, lane)` | | — A wave body takes its lane's upgrades at birth. |
| `stamp_from_stone(world, id, tower)` | | — A guard takes its tower's. |
| `stone_counts(world, structure)` | | What a given piece of stone currently holds. |
| `restamp_stone(world, team, lane)` | | — Rebuilds one lane's towers and their guards. |
| `restamp_guard(world, id, tower)` | | — Clears one guard's vector and rebuilds it. |
| `total_held(world, team_id)` | | Three numbers: in chest, in lanes, in stone. |

## Everything is stamped, nothing is read through a reference

Every body's modifiers are a **copy it owns.** Nothing in the swing path dereferences a
lane, a tower, or a team record to find out how strong a body is — the numbers are in
the body's own slot, already multiplied out.

That is a performance argument and a correctness argument at once. There is no such
thing as a stale reference to a slot that moved, because nothing holds a reference to
a slot.

## The one place this deviates from the written design

The documents describe the swing path walking the count vector and applying each entry
on every blow. **This folds the modifiers into the body's fields at stamp time
instead.**

The two produce identical numbers, and folding does the multiplication once per body
rather than once per blow. They are equivalent because a wave unit's vector never
changes after birth and a guard's only changes when its tower does — which is precisely
when it is re-stamped. The count vector is still carried on the body, because the
renderer reads it to draw the badges an opponent learns your arrangement from.

## Clear, then re-stamp

When the thing a body copied from changes, the body is **cleared and rebuilt from
scratch.** Not patched — cleared. A rebuild from the current truth cannot drift; an
incremental adjustment can, and will, in the direction nobody tests.

Three moments trigger a sweep and only three: an upgrade arrives at or leaves a lane's
towers (every guard in that lane), a boon is chosen (every living body that team owns),
and a body spawns (that body).

**Wave units are never swept**, and that is not an oversight — it is the rule that makes
the whole chest worth arguing about. Moving an upgrade out of a lane does not weaken
the soldiers already walking in it; they finish their lives carrying it.

**Guards are swept.** From either side the other looks like a bug, so: a wave unit
walks away from its lane and dies somewhere else, so what it was born with is a fact
about its birth. A guard stands at the thing it copied from for its entire life.

A re-stamp keeps the **wound** while rebuilding the numbers. "Cleared and rebuilt" is
about the modifier vector, not about damage already taken — stone that healed itself
every time somebody moved an upgrade would be unkillable by fiddling.

## What each piece of stone holds

| Kind | Inherits |
| --- | --- |
| lane tower | its own lane's slot |
| base tower | **every** lane's slot, plus the library slot |
| library | nothing; it does not fight |

A team that invested in stone and then lost all six lane towers still has three fully
upgraded base towers, because the base was inheriting those upgrades the whole time.
That is not a comeback mechanic and does not reward losing — it means an investment
made while winning is still working while losing, which is what makes defending a base
something other than a formality.

## Order of operations

Additive terms in one loop, multiplicative in a second, so the ordering is
**structural** rather than a convention somebody has to remember. A cooldown is rounded
back to a whole number of ticks and floored at 1, because every duration in the game is
an integer and that is the property two machines have to agree on.

## The deck wraps

A long match can draw more cards than the deck holds. It wraps rather than running out;
refusing to pay a team that earned a draw would silently switch the economy off in
exactly the matches where it matters most.
