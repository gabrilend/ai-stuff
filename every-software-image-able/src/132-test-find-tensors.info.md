# 132-test-find-tensors — info

Finding every tensor in a packed model, on all three machines, against what the host works out from the same bytes. Issue 107.

Before an engine can think it must be handed the address of every table of weights. This checks that all three processors find the same addresses in the same run of bytes -- and that each of them refuses a model that does not match rather than handing back a number.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `132-test-find-tensors.lua` and run the sweep again.*

## Invocation

```
luajit 132-test-find-tensors.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `layers` | `u32(header_at.layers), hidden = u32(header_at.hidden)` |  |
| `heads` | `u32(header_at.heads), head_width = u32(header_at.head_width)` |  |
| `kv_heads` | `u32(header_at.kv_heads)` |  |
| `feedforward` | `u32(header_at.feedforward)` |  |
| `vocabulary` | `u32(header_at.vocabulary), context = u32(header_at.context)` |  |

## Why the addresses are compared as offsets

The three machines load the blob at three different places, so the addresses themselves cannot be compared. What can is where each tensor sits RELATIVE to the start, which is the thing the routine actually computes -- and comparing the difference rather than the absolute is what makes one answer checkable against another machine's at all.

## What is checked beyond

"IT FOUND THEM". Two refusals, because both are silent when they go wrong: a model holding fewer tensors than the engine expects hands back an address that was never written, and a truncated one hands back an address off the end of everything. Neither faults. Both are refused here with distinct numbers, because to somebody reading a serial port they mean different things -- the wrong model, or half of one.

## Where it sits

**Belongs to** `107`.

