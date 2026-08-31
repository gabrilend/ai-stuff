# 093-test-devices-that-die — info

Checks the devices that can be destroyed, and -- more importantly -- checks that a machine cannot tell a destroyed part from a busy one or an unpowered one. Issues 702 and 702b.

The point of these devices is not that they die. It is that they die the way real ones do, which is silently, ambiguously, and sometimes long after the mistake. A test that proved the machine can always tell what happened would be testing a machine nobody will ever have.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `093-test-devices-that-die.lua` and run the sweep again.*

## Invocation

```
luajit 093-test-devices-that-die.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `name` | `"healthy", base = 0x1000, length = 0x100` |  |
| `registers` | `{ [0] = 0x1234 }` |  |
| `name` | `"busy", base = 0x2000, length = 0x100, condition = "busy"` |  |
| `busy_until` | `50, registers = { [0] = 0x2345 }` |  |
| `name` | `"unpowered", base = 0x3000, length = 0x100, condition = "...` |  |
| `registers` | `{ [0] = 0x3456 }` |  |
| `name` | `"fragile", base = 0x4000, length = 0x100` |  |
| `registers` | `{ [0] = 0x4567 }` |  |
| `fatal` | `a table below` |  |
| `name` | `"silent-bus", base = 0x6000, length = 0x100, condition = ...` |  |
| `registers` | `{ [0] = 0x6789 }` |  |
| `name` | `"cooking", base = 0x5000, length = 0x100` |  |
| `registers` | `{ [0] = 0x5678 }` |  |
| `fatal` | `a table below` |  |
| &nbsp;&nbsp;↳ `after` | `500 } }` |  |
| `devices` | `a table below` |  |
| &nbsp;&nbsp;↳ `read` | `function() return string.rep("\0", 512) end` |  |
| &nbsp;&nbsp;↳ `write` | `function(block, text)` |  |
| `name` | `"fragile", base = 0x4000, length = 0x100` |  |
| `registers` | `{ [0] = 0x4567 }` |  |
| `fatal` | `{ [0x40] = { kind = "voltage", any_value = true } }` |  |
| `enumerate` | `function()` |  |
| &nbsp;&nbsp;↳ `class` | `"something fragile"` |  |
| &nbsp;&nbsp;↳ `registers` | `{ { base = 0x4000, length = 0x100 } }` |  |
| &nbsp;&nbsp;↳ `interrupt` | `-1` |  |
| &nbsp;&nbsp;↳ `destroying` | `{ [0x40] = "voltage" } } }` |  |
| `read` | `function(device, offset) return bench_module.read(bench_t...` |  |
| `write` | `function(device, offset, width, value)` |  |
| `store` | `store, keep = keep, note_on = "disk", note_at = 1` |  |

## Where it sits

**Belongs to** `702`.

