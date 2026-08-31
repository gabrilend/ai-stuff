# 063-measure-boards — info

What the boards themselves can be measured for today: how long from power to the machine finding its model, how long to the full memory report, and how much of each board the engine and weights occupy. Issue 106's board-side half; the native speed half is 051.

Three emulated computers are switched on, and a stopwatch runs until each one speaks. The numbers land in a data file as well as on the screen, so a fourth board is a new row rather than a rewrite.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `063-measure-boards.lua` and run the sweep again.*

## Invocation

```
luajit 063-measure-boards.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `spoke` | `false }` |  |
| `arch` | `target.arch, board = description.board_id, spoke = true` |  |
| `to_first_light` | `found_at, to_full_report = report_at` |  |
| `memory_total` | `total, engine_bytes = engine, weight_bytes = weights` |  |

## What these times are and are not

An emulated machine is a board (see phase 7), but its clock is not a real board's clock -- emulation speed is one of the things the emulator lies about (705, when it exists). These times say how the boot road FEELS in development and which board is slowest relative to the others; a real board's numbers replace them the day one is plugged in, in the same table.

## Where it sits

**Belongs to** `106`.

