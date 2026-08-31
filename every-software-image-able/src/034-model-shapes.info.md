# 034-model-shapes — info

Which tensors a model of a given shape contains, and how large each one is. One description, used by everything that needs to agree about a model: the thing that generates a packable description, the reference implementation that reads one, and eventually the assembly that walks the same bytes.

A model is a few dozen tables of numbers with fixed names. This says which tables exist and how big each is, given the handful of numbers that describe the model overall.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `034-model-shapes.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/034-model-shapes.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.tensors(shape)` | Returns an ordered array of { name, shape } for a model of this shape. |
| `M.weight_count(shape)` | How many numbers a model of this shape holds altogether. |
| `M.cache_bytes(shape, bytes_per_number)` | How large a full cache of past keys and values grows. |
| `M.SMALL` | a model small enough to test with and shaped like a real one |
| `M.rotation_table(shape)` | The carried turns, as a flat array of numbers in the order the tensor holds them: for each position, for each pair, a cosine then a sine. |

### In more detail

**`M.tensors(shape)`**

Returns an ordered array of { name, shape } for a model of this shape.

Order matters: it is the order they are packed in, and packing the same
description twice must produce the same bytes.

**`M.weight_count(shape)`**

How many numbers a model of this shape holds altogether. Useful before
deciding whether a model fits somewhere (issue 502).

**`M.cache_bytes(shape, bytes_per_number)`**

How large a full cache of past keys and values grows. This is the number
that decides how long a thought can get (issue 103c), and it is computed
rather than written down anywhere so it cannot go stale.

**`M.SMALL`**

Every dimension is deliberately different from every other, so an
implementation that confuses two of them fails rather than coincidentally
working. A model with hidden width equal to its feedforward width would
hide a whole class of mistake.

**`M.rotation_table(shape)`**

The carried turns, as a flat array of numbers in the order the tensor holds
them: for each position, for each pair, a cosine then a sine.

Computed here so that the packer and anything checking the packer derive it
the same way. The angles come from the position and the pair's depth into a
head: pairs further in turn more slowly, so nearby positions differ sharply
in the early pairs and gently in the late ones.

## Why one file

The alternative is each program working out the tensor names for itself, which is two programs agreeing until one of them is edited. Issue 101 already learned this about field offsets; the same rule applies a level up.

## Worth knowing

The arrangement below is the ordinary one -- attention with separate query, key and value projections, fewer key and value heads than query heads, and a gated feedforward. It is not the only arrangement a model can have, and a model built differently would need this file extended rather than edited.

## Where it sits

**Belongs to** `101`.

**Checked by** `037-test-forward`, `110-test-forward-aarch64`, `116-test-forward-riscv64`, `132-test-find-tensors`.

