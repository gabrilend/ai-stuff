# 113-test-kernels-riscv64 — info

The third tongue's arithmetic, run on a real emulated RISC-V machine and compared against answers recorded from the first tongue -- bit for bit, not closely. Issue 401.

The first architecture's routines can be tested by loading them into this process and calling them, because this processor speaks that language. It does not speak this one. So the only honest test is to boot a machine that does, run the arithmetic there, and have it report what it got -- which is why the emulated boards were built first.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `113-test-kernels-riscv64.lua` and run the sweep again.*

## Invocation

```
luajit 113-test-kernels-riscv64.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `name` | `"add_into", words = 48, compare = 48` |  |
| `input` | `spread(48, 11000), extra = spread(48, 12000)` |  |
| `run` | `function(a, b) kernels.add_into(a, b, 48) end` |  |
| `name` | `"rotate", words = 32, compare = 32` |  |
| `input` | `spread(32, 13000), extra = spread(8, 14000)` |  |
| `run` | `function(a, b) kernels.rotate(a, b, 4, 8) end` |  |
| `name` | `"exp_one", words = 40, compare = 40` |  |
| `input` | `(function()` |  |
| `run` | `function(a)` |  |
| `name` | `"softmax", words = 24, compare = 24` |  |
| `input` | `spread(24, 15000)` |  |
| `run` | `function(a) kernels.softmax(a, 24) end` |  |
| `name` | `"swiglu", words = 24, compare = 24` |  |
| `input` | `spread(24, 16000), extra = spread(24, 17000)` |  |
| `run` | `function(a, b) kernels.swiglu(a, b, 24) end` |  |
| `name` | `"attention_scores", words = 16, compare = 8, no_copy = true` |  |
| `input` | `spread(16, 18000),          -- the question` |  |
| `extra` | `spread(128, 19000),         -- eight positions of sixteen` |  |
| `scale_bits` | `scale_bits` |  |
| `run` | `function(out, keys)` |  |
| `name` | `"attention_mix", words = 8, compare = 16, no_copy = true` |  |
| `input` | `spread(8, 20000),           -- how well each position mat...` |  |
| `extra` | `spread(128, 21000),         -- what each position held` |  |
| `run` | `function(out, values)` |  |
| `cases` | `CASES, recorded = recorded` |  |
| `norms` | `NORM, recorded_norm = recorded_norm` |  |
| `jobs` | `jobs` |  |
| `number_at` | `number_at` |  |
| `epsilon_bits` | `float_bits.of(1e-5)` |  |
| `kernels` | `riscv` |  |
| `specification` | `specification` |  |
| `float_bits` | `float_bits` |  |
| `dir` | `DIR` |  |

## What makes the comparison worth anything

The answers are not recomputed on the RISC-V side and compared to themselves. They are the exact bit patterns the x86 routines produced, carried into the payload as constants, and the machine compares its own results against them as integers.

## Where it sits

**Belongs to** `401`.

