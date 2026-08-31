# 134-test-lay-out — info

Dividing a run of memory into everything a thought needs, on all three machines, with no allocator. Issue 107.

This checks that three processors given the same model and the same room put every working vector in the same place -- and that each refuses, with a number, when the room is not enough.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `134-test-lay-out.lua` and run the sweep again.*

## Invocation

```
luajit 134-test-lay-out.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `layers` | `u32(header_at.layers), hidden = u32(header_at.hidden)` |  |
| `heads` | `u32(header_at.heads), head_width = u32(header_at.head_width)` |  |
| `kv_heads` | `u32(header_at.kv_heads)` |  |
| `feedforward` | `u32(header_at.feedforward)` |  |
| `vocabulary` | `u32(header_at.vocabulary), context = u32(header_at.context)` |  |
| `name` | `region.name, at = places[region.name]` |  |
| `bytes` | `region.numbers(shape) * 4` |  |

## The property that matters most is not agreement

It is that no two regions overlap. Two that do would not fault: attention writes over the cache, the cache reads back what attention left, and the machine thinks something unrelated while reporting nothing. So the regions are checked against each other directly, in addition to being checked against the host's answer.

## Where it sits

**Belongs to** `107`.

