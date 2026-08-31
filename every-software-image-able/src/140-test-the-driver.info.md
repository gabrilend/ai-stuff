# 140-test-the-driver — info

A machine that reads what it was told, thinks about it, and says what it thought -- with nothing underneath it -- held word for word to what the readable loop says from the same starting text. Issue 107a.

Everything below this has been provable alone for a while. This is where the pieces are one machine. It runs twice: once on the development machine, where a failure can be pointed at, and once on an emulated computer with no operating system, which is the claim that matters.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `140-test-the-driver.lua` and run the sweep again.*

## Invocation

```
luajit 140-test-the-driver.lua [--dir ROOT] [--seconds N] [--quick]
```

## What it describes

| Field | Value | |
|---|---|---|
| `layers` | `u32(blob, header_at.layers), hidden = u32(blob, header_at...` |  |
| `heads` | `u32(blob, header_at.heads)` |  |
| `head_width` | `u32(blob, header_at.head_width)` |  |
| `kv_heads` | `u32(blob, header_at.kv_heads)` |  |
| `feedforward` | `u32(blob, header_at.feedforward)` |  |
| `vocabulary` | `u32(blob, header_at.vocabulary)` |  |
| `context` | `u32(blob, header_at.context)` |  |
| `model` | `model` |  |
| `kernels` | `built` |  |
| `conduct` | `conductor` |  |
| `sampler` | `sampler` |  |
| `tokenizer` | `tokenizer` |  |
| `tables` | `{ tokens = tokens_table, merges = merges_table }` |  |
| `carried` | `carried` |  |
| `settings` | `SETTINGS` |  |
| `text_bytes` | `3 })` |  |
| `text_bytes` | `shape.context + 4 })` |  |
| `finish_token` | `expected.tokens[1] })` |  |
| `dir` | `DIR` |  |
| `blob` | `blob` |  |
| `text` | `BOOT_TEXT` |  |
| `max_tokens` | `MAX_TOKENS` |  |
| `settings` | `SETTINGS` |  |
| `randomness` | `carried` |  |
| `bytes` | `carried` |  |
| `path` | `"EFI/BOOT/BOOTX64.EFI"` |  |
| `identity` | `"first-light-x86_64"` |  |
| `label` | `"SEED"` |  |

## Why the comparison is token for token and not

"CLOSE". A drawn word is discrete. One different choice at one boundary and the two machines are having different conversations from that word onwards -- so a machine that agrees for five words and differs on the sixth has not nearly agreed, it has diverged, and the only useful threshold is all of them.

## Where it sits

**Belongs to** `107a`.

