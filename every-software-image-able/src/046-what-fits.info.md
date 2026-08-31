# 046-what-fits — info

Says what a machine of a given shape would need, on boards of given sizes, and which term runs out first. Also checks the arithmetic against itself.

This is the feasibility question the whole project rests on, asked as arithmetic rather than as an argument. It does not say whether a model good enough to write assembly exists at these sizes. It says what such a model would cost if it did, so that the question can be answered by measurement instead of hope.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `046-what-fits.lua` and run the sweep again.*

## Invocation

```
luajit 046-what-fits.lua [--dir ROOT] [--context N] [--precision NAME]
```

## What it describes

| Field | Value | |
|---|---|---|
| &nbsp;&nbsp;↳ `kv_heads` | `2, feedforward = 64, vocabulary = 48, context = 16 }` |  |
| &nbsp;&nbsp;↳ `kv_heads` | `12, feedforward = 2048, vocabulary = 32000, context = 2048 }` |  |
| &nbsp;&nbsp;↳ `kv_heads` | `4, feedforward = 5632, vocabulary = 32000, context = 2048 }` |  |
| &nbsp;&nbsp;↳ `kv_heads` | `8, feedforward = 14336, vocabulary = 128256, context = 81...` |  |
| `shape` | `shape, shapes_module = shapes, format_module = format, pr...` |  |
| `context` | `context, engine_bytes = 2 * 1048576` |  |
| `shape` | `shape, shapes_module = shapes, format_module = format, pr...` |  |
| `context` | `context, engine_bytes = 2 * 1048576` |  |
| `shape` | `shape, shapes_module = shapes, format_module = format, pr...` |  |
| `engine_bytes` | `2 * 1048576` |  |
| `engine_bytes` | `0 }` |  |
| `precision` | `"f16", context = longest` |  |
| `engine_bytes` | `0 }).total` |  |
| `precision` | `"f16", context = longest + 1` |  |
| `engine_bytes` | `0 }).total` |  |

