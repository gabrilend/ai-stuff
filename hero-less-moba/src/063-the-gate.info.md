# 063-the-gate

Put the world somewhere interesting, look at it, and only then let it move.

## The third kind of test

Not a unit test over a data structure, and not the headless runner playing a whole
match at speed. A **simulation test**: put the world in a described state, inspect it,
step it, and see what happens next.

Without it, every question about the middle of a match costs the first ten minutes of
one — and the questions worth asking are nearly all about the middle.

## The gate is the feature

**Nothing advances until the scenario is released.** Load, look, then say go.

That is what separates this from the runner, and it deserves stating plainly: a match
that begins running the instant it loads cannot be *inspected before it moves*, and
the most useful moment when something is going wrong is almost always the tick before
it does.

## Running one

```
./run-scenario the-dragon-at-the-midpoint                -- load, describe, hold
./run-scenario the-dragon-at-the-midpoint step 400       -- advance and hold again
./run-scenario the-dragon-at-the-midpoint until monster_slain
```

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `load(world, path)` | | The world, described and held. |
| `step(world, tick_module, count)` | | `false` if the match ended. |
| `until_event(world, tick_module, name, limit)` | | Reached, and why. |
| `describe(world)` | | What it looks like right now, as text. |
| `verb` | *(table)* | What a scenario file may say. |

## What a scenario file says

One verb per line, `#` for a comment. A dispatch table rather than a parser with
branches in it, so adding something a scenario can describe is adding a row.

| Verb | Says |
| --- | --- |
| `tick <n>` | Start the clock here. |
| `phase <name>` | normal, surge, challenge or calm — **by name**, because `phase 2` is a worse sentence than `phase surge` in every way that matters. |
| `challenge <n>` | Put a named monster on the field. |
| `wave <team> <lane> <milestone>` | A wave of that team's ordinary composition, standing that far along. |
| `rubble <team> <lane> <milestone>` | A tower that has already fallen. |
| `stone <team> <kind> <where> [lane]` | An upgrade already held or already placed. |
| `points <player> <colour> <amount>` | What somebody is holding. |
| `at <tick> <verb> ...` | The same verbs, happening later. |

Positions are given in **milestones**, not paces, because that is how the game
measures everything and a scenario should read the way the game reads.

## A scenario is a bug report anybody can run

Written by hand, diffable, made of the same words the documents use. That is worth
more than any amount of describing what you saw.

## The clock verb moves every clock

Setting the tick also moves the wave timer, the surge timer, the wallet ladder and the
phase deadline.

Without that, a scenario that jumps forward leaves the spawn timer a whole match
behind, and the spawner produces every wave it thinks it owes — one per tick until it
catches up. The first version of this put **a thousand bodies on the field in four
hundred ticks** that way.

The spawner also snaps its own clock forward now if it ever finds itself more than one
interval behind, and **says so** when it does. Catching up is not obviously wrong, so
it is the kind of thing that has to announce itself rather than be quietly corrected.
