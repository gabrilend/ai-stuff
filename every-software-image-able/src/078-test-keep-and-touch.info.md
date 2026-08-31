# 078-test-keep-and-touch — info

Checks storage and hardware exploration together, because they only work together: the discipline that makes exploring survivable depends on writing a note first, and the note needs somewhere to land. Issues 206 and 205.

The machine is given pretend storage and a pretend body, and then made to explore recklessly. What is being tested is that it cannot -- that the writes which destroy real hardware are refused, that every exploratory write leaves a note behind first, and that a machine with nowhere to write a note is not allowed to explore at all.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `078-test-keep-and-touch.lua` and run the sweep again.*

## Invocation

```
luajit 078-test-keep-and-touch.lua [--dir ROOT]
```

## What it describes

| Field | Value | |
|---|---|---|
| `name` | `name, blocks = blocks, block_bytes = block_bytes` |  |
| `writable` | `writable, removable = removable, note = note` |  |
| `read` | `function(block, count)` |  |
| `write` | `function(block, text)` |  |
| `contents` | `contents` |  |
| `devices` | `{ make_disk("blank", 64, 512, true, false) } }), { 0 }))` |  |
| &nbsp;&nbsp;↳ `registers` | `{ { base = 0xf0000000, length = 0x20000 } }, interrupt = 11` |  |
| &nbsp;&nbsp;↳ `destroying` | `{ [0x40] = "voltage", [0x44] = "clock", [0x80] = "non-vol...` | the addresses that end the part, exactly as a real one would have |
| &nbsp;&nbsp;↳ `registers` | `{ { base = 0xe0000000, length = 0x1000000 } }, interrupt ...` |  |
| &nbsp;&nbsp;↳ `destroying` | `{ [0x10] = "thermal" } }` |  |
| `enumerate` | `function() return devices end` |  |
| `read` | `function(device, offset) return registers[device.name .. ...` |  |
| `write` | `function(device, offset, width, value)` |  |
| `store` | `store, keep = keep, note_on = "disk", note_at = 1000` |  |
| `enumerate` | `function() return devices end` |  |
| `read` | `function() return 0 end` |  |
| `write` | `function() end` |  |
| `name` | `"keep", arguments = { "disk", "300", "something worth rem...` |  |
| `name` | `"recall", arguments = { "disk", "300" } })` |  |

## Where it sits

**Belongs to** `206`.

