# 136-test-fill-the-plan — info

Telling the conducting where everything is, on all three machines -- and on the first, setting a machine up from nothing and requiring it to think correctly. Issue 107.

The previous two pieces found the weights and divided the memory. This writes down where all of it is, in the form the conducting reads. On the first architecture the whole chain is then run for real: find, divide, fill, and think -- with the answer held to the recorded one, which is the strongest statement available about a setup routine.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `136-test-fill-the-plan.lua` and run the sweep again.*

## Invocation

```
luajit 136-test-fill-the-plan.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `layers` | `u32(header_at.layers), hidden = u32(header_at.hidden)` |  |
| `heads` | `u32(header_at.heads), head_width = u32(header_at.head_width)` |  |
| `kv_heads` | `u32(header_at.kv_heads)` |  |
| `feedforward` | `u32(header_at.feedforward)` |  |
| `vocabulary` | `u32(header_at.vocabulary), context = u32(header_at.context)` |  |
| `layers` | `shape.layers, hidden = shape.hidden, heads = shape.heads` |  |
| `head_width` | `shape.head_width, kv_heads = shape.kv_heads` |  |
| `feedforward` | `shape.feedforward, vocabulary = shape.vocabulary` |  |
| `context` | `shape.context` |  |
| `heads_per_kv` | `shape.heads / shape.kv_heads` |  |
| `kv_width` | `shape.kv_heads * shape.head_width` |  |
| `query_width` | `shape.heads * shape.head_width` |  |
| `layers` | `2048, room = 8192, stack = 0x8000 }` |  |

## Why thinking is a better test than comparing slots

A slot written one place along is not an error. Comparing the plan against a plan says only that two programs agree; running the engine with it says the plan is *usable*, and every wrong slot becomes a wrong score. The slot comparison is kept as well, because it says WHICH slot -- one answers "does it work", the other answers "what is broken", and a setup routine wants both.

## Where it sits

**Belongs to** `107`.

