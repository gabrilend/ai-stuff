# 036-fixture — info

The answer a forward pass gives on this model with this prompt. Any other implementation of the same arithmetic is correct exactly when it reproduces these numbers, and is wrong otherwise -- including a faster one, including one written in a different architecture's instructions.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `036-fixture.lua` and run the sweep again.*

## What it describes

| Field | Value | |
|---|---|---|
| `shape` | `a table below` |  |
| &nbsp;&nbsp;↳ `kv_heads` | `2, feedforward = 64, vocabulary = 48, context = 16 }` |  |
| `prompt` | `{ 1, 7, 7, 3 }` |  |
| `logits` | `a table below` |  |

## Worth knowing

Regenerate with 036-make-fixture.lua. If the numbers move, something changed in the arithmetic and the change was probably not intended.

## Where it sits

**Checked by** `037-test-forward`, `050-test-assembly-forward`, `110-test-forward-aarch64`, `116-test-forward-riscv64`, `136-test-fill-the-plan`.

