# 106-test-the-watchdog — info

Checks that a read which never comes back takes one core down rather than the machine, and that what the machine was doing survives the reset.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `106-test-the-watchdog.lua` and run the sweep again.*

## Invocation

```
luajit 106-test-the-watchdog.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `cores` | `4, patience = 100` |  |
| `arm` | `function(core) armed[core] = true end` |  |
| `disarm` | `function(core) armed[core] = nil end` |  |
| `note` | `with_note and function(core, text)` | one slot per core, addressed by core number, because a core that is still running would otherwise overwrite the last ... |
| `name` | `"answers", base = 0x1000, length = 0x100, registers = { [...` |  |
| `name` | `"never-answers", base = 0x2000, length = 0x100, condition...` |  |

## Worth knowing

The bench of devices that can die already models a bus that never answers (092), so the hang here is a real modelled hang rather than a value being read as one.

