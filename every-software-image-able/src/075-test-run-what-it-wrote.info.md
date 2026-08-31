# 075-test-run-what-it-wrote — info

Checks the hand the whole project rests on: assembly the machine wrote, turned into instructions, placed, and run -- and most of all, a program that would never return being noticed and stopped.

A small program is written the way the machine would write it, assembled, put in real memory and executed on this processor. Then a program that loops forever is run, and the count the assembler hid at the bottom of its loop is what takes control back.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `075-test-run-what-it-wrote.lua` and run the sweep again.*

## Invocation

```
luajit 075-test-run-what-it-wrote.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `usable` | `{ { base = BASE, length = SIZE } }` |  |
| `ours` | `{ { base = BASE, length = 0x100, what = "engine" } }` |  |
| `read` | `read, write = write` |  |
| `memory` | `memory` |  |
| `somewhere` | `PROGRAMS` |  |
| `room` | `SIZE - 0x1000` |  |
| `count_at` | `LOOP_COUNT` |  |
| `run` | `transfer` |  |
| `allowance` | `40` |  |
| `memory` | `memory, somewhere = BASE + 0x40, room = 0x100` |  |
| `count_at` | `LOOP_COUNT, run = transfer` |  |
| `memory` | `memory, somewhere = PROGRAMS, room = 4` |  |
| `count_at` | `LOOP_COUNT, run = transfer` |  |
| `name` | `"assemble"` |  |
| `arguments` | `{ "double", "move a di\nadd a di\nreturn" }` |  |
| `name` | `"run", arguments = { string.format("0x%x", placed_at) }` |  |
| `name` | `"assemble", arguments = { "bad", "fly a di" }` |  |
| `name` | `"why", arguments = { string.format("0x%x", placed_at) }` |  |

