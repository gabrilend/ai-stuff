# 024-blob-format — info

The layout of a packed model. Pure data and a few size helpers, shared by the
packer (025) and the reader (026) so the two cannot disagree about where
anything is — the same reason the hazard map (020) is one file rather than two.

Issue 101 is the blueprint.

## Why the format is self-describing

At the moment the engine starts there is no filesystem, no allocator, no
operating system. There is a block of bytes at a known offset and nothing
else. Everything the engine needs to know about the shape of what it is
holding has to be inside those bytes, because there is nowhere else for it to
be.

## Why offsets are blob-relative

Measured from the start of the blob rather than the start of the image, so the
image builder can move the blob without rewriting it, and so the engine can
find things whether the blob was copied into memory or is being read where it
lies — both rungs of the ratchet in issue 102.

## What it exports

| Name | Type | Meaning |
|---|---|---|
| `MAGIC` | string | `"ESIA"`; four bytes so a reader can tell a blob from rubbish |
| `VERSION` | integer | bumped whenever a field moves |
| `HEADER` | array | the fixed-size fields at the start, in order |
| `header_size()` | function | their total width in bytes |
| `PRECISION` | table | name → `{code, bytes, note}` |
| `precision_by_code(code)` | function | the reverse lookup |
| `TENSOR_ENTRY` | array | the fields of one tensor-table row |
| `tensor_entry_size()` | function | the width of a row |
| `NAME_BYTES` | integer | 32 — the longest a tensor name may be |
| `MAX_RANK` | integer | 8 — the most dimensions a tensor may have |
| `MERGE_ENTRY_BYTES` | integer | 8 — two token numbers per merge rule |

## The header fields

Magic and version, then the model's shape — `layers`, `hidden`, `heads`,
`head_width`, `kv_heads`, `feedforward`, `vocabulary`, `context` — then the
locations of the three tables (tensors, tokens, merges) with a count for each,
then `blob_bytes`.

The shape is read from here rather than compiled into the arithmetic, so a
different model can be packed without rewriting issue 103.

`blob_bytes` exists because a truncated blob is otherwise indistinguishable
from a whole one until something reads past the end.

## Precisions

| Name | Bytes each | Effect on the inner loop |
|---|---|---|
| `f32` | 4 | simplest |
| `f16` | 2 | same shape, half the size |
| `i8` | 1 | one scale for the whole tensor |
| `q40` | — | 32 weights share a 2-byte scale; needs a dequantise step inside the hottest loop in the machine |

The format permits all four; the engine decides which it supports. That choice
is not only about size — it reaches directly into issue 103.

## The tokenizer sections

The model never sees text. It works in integers, and its embedding table says
what each integer *means* without saying which string it *is*. That mapping is
separate data, published beside the model, and it travels with it.

**Token table**: one entry per token — a length byte then that many bytes.
Variable-length and walked in order, because it is read once at startup to
build whatever lookup the engine wants rather than seeked into.

**Merge table**: two token numbers per rule, highest rank first. Encoding
repeatedly joins the highest-ranked adjacent pair until no rule applies, so
rank *is* position in this table.
