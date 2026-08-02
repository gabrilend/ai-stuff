# 025-pack-model — info

Turns a model into the blob an engine can find its way around with nothing
underneath it. Runs on a development machine, never on the seed.

**Which model is not decided here.** It is a parameter of whoever builds an
image (issue 502). This tool only has to carry whichever one arrives, which is
why nothing in it names a model or assumes a size.

## Invocation

```
luajit src/025-pack-model.lua --from DESCRIPTION --to BLOB [--dir ROOT]
```

## The description it takes

A Lua file returning a table:

| Field | Type | Meaning |
|---|---|---|
| `shape` | table | `layers`, `hidden`, `heads`, `head_width`, `kv_heads`, `feedforward`, `vocabulary`, `context` |
| `tensors` | array | one entry per tensor, below |
| `tokens` | array of string | the vocabulary, in token-number order |
| `merges` | array | `{a, b}` pairs, highest-ranked first |

A tensor entry:

| Field | Type | Meaning |
|---|---|---|
| `name` | string | at most 32 bytes |
| `precision` | string | `f32`, `f16`, `i8` or `q40` |
| `shape` | array of integer | up to 8 dimensions |
| `scale` | number | for `i8`; zero otherwise |
| `data` | function | takes a byte count, returns exactly that many bytes |

`data` is a function rather than a string so a description stays small and a
caller can stream from wherever the weights actually live.

## What it guarantees

- **Fixed layout order** — header, tensor table, token table, merge table,
  then weights. The same description always packs to the same bytes.
  Reproducibility is a build-time property that matters even though it stops
  meaning anything the moment a machine starts growing.
- **32-byte alignment** for every tensor's data, so a vectorised inner loop
  can start at the beginning of a row without a preliminary unaligned step.
- **Self-consistency** — it refuses to write a blob whose header would
  disagree with its own length.

## What it refuses

A name longer than the field holds. A rank above what the format carries. A
precision it does not know. A `q40` tensor whose weight count is not a whole
number of 32-weight blocks. A `data` function that returns the wrong number of
bytes.

All of these are errors rather than things to paper over: a blob that packs
with a quiet correction is a blob the reader will believe.
