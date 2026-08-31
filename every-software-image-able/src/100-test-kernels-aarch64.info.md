# 100-test-kernels-aarch64 — info

The second tongue's arithmetic, run on a real emulated ARM machine and compared against answers recorded from the first tongue -- bit for bit, not closely. Issue 401.

The first architecture's kernels could be tested by loading them into this process and calling them, because this processor speaks that language. It does not speak this one. So the only honest test is to boot a machine that does, run the arithmetic there, and have it report what it got -- which is why the emulated boards were built first.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `100-test-kernels-aarch64.lua` and run the sweep again.*

## Invocation

```
luajit 100-test-kernels-aarch64.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `fast_answers` | `quick_answers }` |  |
| `name` | `"add_into", words = 48, compare = 48` |  |
| `input` | `spread(48, 11000), extra = spread(48, 12000)` |  |
| `call` | `{ "  add x0, sp, #1024", "  adr x1, add_intoex", "  mov w...` |  |
| `run` | `function(a, b) kernels.add_into(a, b, 48) end` |  |
| `name` | `"rotate", words = 32, compare = 32` |  |
| `input` | `spread(32, 13000), extra = spread(8, 14000)` |  |
| `call` | `a table below` |  |
| `run` | `function(a, b) kernels.rotate(a, b, 4, 8) end` |  |
| `name` | `"exp_one", words = 40, compare = 40` |  |
| `input` | `(function()` |  |
| `call` | `{}` |  |
| `emit_call` | `true` |  |
| `run` | `function(a)` |  |
| `name` | `"softmax", words = 24, compare = 24` |  |
| `input` | `spread(24, 15000)` |  |
| `call` | `{ "  add x0, sp, #1024", "  mov w1, #24" }` |  |
| `run` | `function(a) kernels.softmax(a, 24) end` |  |
| `name` | `"swiglu", words = 24, compare = 24` |  |
| `input` | `spread(24, 16000), extra = spread(24, 17000)` |  |
| `call` | `{ "  add x0, sp, #1024", "  adr x1, swigluex", "  mov w2,...` |  |
| `run` | `function(a, b) kernels.swiglu(a, b, 24) end` |  |
| `name` | `"attention_scores", words = 16, compare = 8, no_copy = true` |  |
| `input` | `spread(16, 18000),          -- the question` |  |
| `extra` | `spread(128, 19000),         -- eight positions of sixteen` |  |
| `call` | `a table below` |  |
| `run` | `function(out, keys)` |  |
| `name` | `"attention_mix", words = 8, compare = 16, no_copy = true` |  |
| `input` | `spread(8, 20000),           -- how well each position mat...` |  |
| `extra` | `spread(128, 21000),         -- what each position held` |  |
| `call` | `a table below` |  |
| `run` | `function(out, values)` |  |
| `cases` | `CASES, recorded = recorded` |  |
| `norms` | `NORM, recorded_norm = recorded_norm` |  |
| `kernels` | `arm.source(nil, specification, float_bits)` |  |
| `jobs` | `jobs` |  |
| `number_at` | `number_at` |  |
| `dir` | `DIR` |  |

## What makes the comparison worth anything

The answers are not recomputed on the ARM side and compared to themselves. They are the exact bit patterns the x86 kernels produced, carried into the payload as constants, and the machine compares its own results against them and reports how many matched. A port is correct when it agrees with the fixture the first one agreed with, and that is the whole reason the fixture exists.

## Where it sits

**Belongs to** `401`.

