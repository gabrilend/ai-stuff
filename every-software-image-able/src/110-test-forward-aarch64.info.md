# 110-test-forward-aarch64 — info

A whole forward pass, conducted in the second tongue, on a real emulated ARM machine, compared against the first tongue's scores bit for bit. Issue 401's remaining gap, closed for the second architecture.

The ten pieces of arithmetic were already shown to agree one at a time. This runs them in the order a thought requires, over a whole small model, and asks whether the same scores come out. That is a different claim: a piece can be right alone and be handed the wrong thing by the piece before it, and the first architecture found exactly such a defect the moment its pieces were first composed.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `110-test-forward-aarch64.lua` and run the sweep again.*

## Invocation

```
luajit 110-test-forward-aarch64.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `shape` | `shape` |  |
| `tensors` | `(function()` |  |
| `words_of` | `words_of` |  |
| `prompt` | `fixture.prompt` |  |
| `recorded` | `recorded` |  |
| `scale_bits` | `scale_bits` |  |
| `epsilon_bits` | `epsilon_bits` |  |
| `kernels` | `arm.source(nil, specification` |  |
| `conductor` | `arm_conduct.source(conduct)` |  |
| `conductor_miswired` | `arm_conduct.source(conduct, {` | and one built wrong on purpose, so the machine has something it is required to disagree with |
| &nbsp;&nbsp;↳ `name` | `"forward_conduct_miswired", miswire = true` |  |
| `plan` | `conduct` |  |

## What makes the comparison worth anything

The expected scores are not recomputed on the ARM side. They are produced HERE, by the first architecture's own conducting over the same weights, carried into the payload as the exact bit patterns that came out, and compared on the other machine as integers. Nothing rounds, and "close" cannot happen.

## And the reference vouches for itself first

Before its answer is used as the standard, it is checked against the recorded fixture. A first architecture that had quietly regressed would otherwise become the thing the second one is measured against, and a matching pair of wrong answers reads exactly like a working port.

## Where it sits

**Belongs to** `401`.

