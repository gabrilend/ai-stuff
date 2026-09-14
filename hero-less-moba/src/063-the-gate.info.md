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
./scripts/run-a-test the-dragon-at-the-midpoint          -- run it and report
./scripts/run-a-test the-dragon-at-the-midpoint watch    -- open it in the window, held
```

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world, source)` | | The world, given a gate: held, with an empty script. |
| `perform(world, rows)` | rows of `{verb, arguments...}` | The world, put into the described state. |
| `fire_due(world)` | | — Everything the script says should have happened by now. |
| `step(world, tick_module, count)` | | `false` if the match ended. |
| `until_event(world, tick_module, name, limit)` | | Reached, and why. |
| `describe(world)` | | What it looks like right now, as text. |
| `verb` | *(table)* | What a scenario may say. |

## What a scenario says

A row is a verb and its arguments — `{"stone", 1, 1, "lane", 2}`. A dispatch table rather
than a parser with branches in it, so adding something a scenario can describe is adding
a row.

The rows live in a test file, which is a table read by [the bench](071-the-bench.info.md)
and is the same shape a scene has. **The verbs were already the right idea and the
scenario was already the right shape**: it named things the engine does and contained no
behavior of its own, which is now the rule for every test in the project. What changed is
only that the rows sit in a Lua table beside a name, a caption, the mechanics it covers
and what it claims, instead of alone in a file of lines.

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
