# 119-test-sampler-aarch64 — info

Choosing what to say next, in the second tongue, on a real emulated ARM machine -- held to the first architecture choice for choice. Issue 401.

A score off in its last bit stays off in its last bit. A CHOICE that flips once joins the conversation, and every word after it is said in a different conversation. So this does not ask whether the two architectures are close. It asks whether, across many hundreds of draws under every setting the sampler has, they picked the same word every time and recorded the same chance for it.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `119-test-sampler-aarch64.lua` and run the sweep again.*

## Invocation

```
luajit 119-test-sampler-aarch64.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `temperature` | `setting.temperature` |  |
| `top_p` | `setting.top_p` |  |
| `top_k` | `setting.top_k` |  |
| `token` | `tonumber(token), chance = as_bits[0]` |  |
| `sampler` | `sampler` |  |
| `scores` | `scores` |  |
| `settings` | `SETTINGS` |  |
| `stream_numbers` | `stream_numbers` |  |
| `per_number` | `PER_NUMBER` |  |
| `recorded` | `recorded` |  |
| `kernels` | `arm.source({ "exp_one" }, specification, float_bits)` |  |
| `sampler_source` | `arm_sampler.source(sampler)` |  |
| `float_bits` | `float_bits` |  |

## Why the draws are chained

The carried stream advances with every draw -- its position, its state, how many have been taken from the current number, and whether it has wrapped. Independent draws would check the arithmetic and miss the bookkeeping; one long run means a single wrong step puts every later draw somewhere else, which is the failure worth guarding.

## Where it sits

**Belongs to** `401`.

