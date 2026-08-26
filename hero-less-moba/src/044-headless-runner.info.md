# 044-headless-runner

Runs a match with no window at all, as fast as the machine allows, and prints what
happened.

## What it is for

This is not a debugging convenience to be thrown away. It is **half of the reason the
simulation and the viewer are separate programs**: balance work is running ten thousand
matches overnight and reading a table in the morning, and that is not possible if
drawing is welded to simulating.

It is also the fastest way to find out whether a change broke the game. A window shows
one match at one speed; this shows a thousand.

## Running it

```
luajit src/044-headless-runner.lua                -- one match, report at the end
luajit src/044-headless-runner.lua 5000           -- stop after 5000 ticks
luajit src/044-headless-runner.lua 40000 trace    -- a line every 600 ticks
```

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `run(world, tick_module, limit, on_tick)` | | The world, advanced. |
| `report(world)` | | The match as a printable table. |
| `main(arguments)` | | The command-line entry. |

`main` is kept apart from `run` so a test can drive a match without going through
argument parsing.

## What the report says

Outcome and tick count; bodies on the field and waves spawned; then, per lane per team,
**push depth** and **waves lost**; then upgrades drawn and where they are sitting; then
towers standing and each library's health.

Deliberately made of the numbers a balance question is asked in, rather than of prose.

## How it knows it was invoked directly

`arg[0]` — the script the interpreter was asked to run — compared against this file's
own name. The usual trick of checking `...` cannot tell the difference here, because a
script run with no arguments and a chunk loaded by `loadfile` both receive nothing.

## What a headless match looks like today

With nobody placing upgrades, a match **stalemates**, and that is the correct result
rather than a defect. It is the vision's problem statement rendered: units walking
toward one another, fighting in the middle, barely moving the frontlines at all. The
chest fills up and nothing happens, because nothing is placing it.

Handing those upgrades to a lane is what breaks it, which is what
[the invariants test](../tests/051-the-invariants.info.md) checks and what a player
does with a mouse.
