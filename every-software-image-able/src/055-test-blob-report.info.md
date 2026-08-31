# 055-test-blob-report — info

Boots the blob-report payload on all three UEFI boards and holds what each machine says against what the host works out from the same blob. Issue 102 proven whole: the weights found with no filesystem, the memory map read, the image verified outside every usable range, and the ratchet computed by two implementations that must agree.

A bare machine and a development machine are both asked the same questions about the same model -- how big, how much room, which arrangement can be afforded. If any answer differs, one of the two is wrong, and it does not matter which: the seam between the builder's arithmetic and the engine's is exactly where a machine fails at first light with the least possible information, so it is checked here instead.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `055-test-blob-report.lua` and run the sweep again.*

## Invocation

```
luajit 055-test-blob-report.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `layers` | `header.layers, hidden = header.hidden, heads = header.heads` |  |
| `head_width` | `header.head_width, kv_heads = header.kv_heads` |  |
| `feedforward` | `header.feedforward, vocabulary = header.vocabulary` |  |
| `context` | `header.context` |  |
| `shape` | `shape` |  |
| `weights_bytes` | `header.blob_bytes` |  |
| `engine_bytes` | `heard.engine or 0` |  |
| `context` | `header.context` |  |

## Worth knowing

The machines run in the background and are stopped the moment they finish speaking, so the test costs boot time rather than a fixed allowance.

## Where it sits

**Belongs to** `102`.

