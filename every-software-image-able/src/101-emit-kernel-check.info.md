# 101-emit-kernel-check — info

A payload that runs the second tongue's kernels on a bare machine and says how many of their answers matched what the first tongue produced. The other half of issue 401's test.

The kernels for this architecture cannot be tested on the machine that wrote them, because that machine does not speak this language. So the test is carried to a machine that does: the inputs, the kernels, and the answers the first architecture gave, all baked into one program that boots, computes, compares, and reports two numbers.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `101-emit-kernel-check.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/101-emit-kernel-check.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.aarch64(options)` | described below |

### In more detail

**`M.aarch64(options)`**

options: cases, recorded, norms, recorded_norm, kernels (the assembly
text), number_at (the same deterministic numbers the host used)

## Why the answers are carried rather than recomputed

A payload that computed the expected answers on the same machine would be comparing an implementation against itself, which passes whatever it does. The bit patterns here came off the first architecture, and they are compared as INTEGERS -- not as numbers, so nothing rounds during the comparison and "close" is not a thing that can happen.

## Where it sits

**Belongs to** `401`.

**Checked by** `100-test-kernels-aarch64`.

