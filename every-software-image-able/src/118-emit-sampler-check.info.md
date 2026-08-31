# 118-emit-sampler-check — info

A payload that draws on a bare ARM machine and says whether it chose the same words the first architecture chose. Issue 401.

A score being off in its last bit stays off in its last bit. A CHOICE that flips once joins the conversation, and everything after it is said in a different conversation. So this does not check that the two architectures are close; it checks that across many hundreds of draws, under every setting the sampler has, they picked the same word every time and recorded the same chance for it, bit for bit.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `118-emit-sampler-check.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/118-emit-sampler-check.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.workspace(count, settings_count, draws, stream_slots, plan_slots)` | Where everything writable lives, as offsets from the stack pointer. |
| `M.aarch64(options)` | described below |

### In more detail

**`M.aarch64(options)`**

options: sampler (057), scores, settings, stream_numbers, per_number,
  recorded (per draw: token and chance bits), kernels, conductor_free
  assembly text pieces, float_bits

## Why the draws are chained rather than independent

The carried stream advances with every draw -- position, state, how many have been taken from this number, and whether it has wrapped. Comparing single draws would check the arithmetic and miss the bookkeeping. Running hundreds in a row from one stream means a single wrong step puts every later draw in a different place, which is exactly the failure being guarded against.

## Where the writable memory is

On the stack, all of it, because firmware that honours section rights maps the payload's code read-only.

## Where it sits

**Belongs to** `401`.

**Checked by** `119-test-sampler-aarch64`.

