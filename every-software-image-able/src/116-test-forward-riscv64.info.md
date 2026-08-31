# 116-test-forward-riscv64 — info

A whole forward pass, conducted in the third tongue, on a real emulated RISC-V machine, compared against the first tongue's scores bit for bit. Issue 401's last arithmetic gap.

The eleven routines were already shown to agree one at a time. This runs them in the order a thought requires, over a whole small model, and asks whether the same scores come out. That is a different claim: a routine can be right alone and be handed the wrong thing by the routine before it, and the first architecture found exactly such a defect the moment its routines were first composed.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `116-test-forward-riscv64.lua` and run the sweep again.*

## Invocation

```
luajit 116-test-forward-riscv64.lua [--dir ROOT] [--seconds N]
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
| `kernels` | `riscv` |  |
| `conductor` | `riscv_conduct` |  |
| `plan` | `conduct` |  |
| `specification` | `specification` |  |
| `float_bits` | `float_bits` |  |
| `dir` | `DIR` |  |

## And the reference vouches for itself first

Before its answer is used as the standard, it is checked against the recorded fixture. A first architecture that had quietly regressed would otherwise become the thing the third one is measured against, and a matching pair of wrong answers reads exactly like a working port.

## Where it sits

**Belongs to** `401`.

