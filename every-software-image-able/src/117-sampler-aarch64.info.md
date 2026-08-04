# 117, 118, 119 — choosing what to say, in the second tongue — info

The sampler written for ARM, run on a real emulated ARM machine, and held to
the first architecture choice for choice and chance for chance.

With this the second architecture can turn scores into a word. Before it, that
engine could think and never say anything: a score for every possible next
word and no way to pick one is not yet a machine that speaks.

## Running it

```
luajit src/119-test-sampler-aarch64.lua
```

## What it exports

| File | Role |
|---|---|
| `117-sampler-aarch64` | `M.source(sampler)` — `sampler_choose` as assembler text |
| `118-emit-sampler-check` | the payload that draws and compares |
| `119-test-sampler-aarch64` | records the first tongue's choices and drives the board |

`sampler` is the module describing the two structures (`057`) — the carried
stream and the plan — passed in so there stays one description of where every
slot sits.

## Why exactness is worth more here than anywhere else in the engine

A score off in its last bit stays off in its last bit. A **choice** that flips
once joins the context, and every word after it is said in a different
conversation — two implementations diverge wholesale from that moment rather
than drifting apart. So this is not checked for closeness.

## Why the draws are chained

The carried stream advances with every draw: its position, its state, how many
have been taken from the current number, and whether it has wrapped.
Independent draws would check the arithmetic and miss the bookkeeping. One run
of 620 draws through six settings from a single carried file means one wrong
step puts every later draw somewhere else — and the test also requires both
machines to end at the same position in the file, which arithmetic alone would
never catch.

The file is deliberately small and drawn from often, so it wraps during the
run rather than in theory.

## Where the comparisons had to be worked out rather than translated

The first architecture's float compare sets its flags so an **unordered** pair
— one where something is not a number — takes the same branch as
less-or-equal. This architecture's flags are laid out differently, and whether
the two agree on that case had to be derived rather than assumed.

They do. After a floating compare here, `le` means less-or-equal **or**
unordered and `gt` means ordered-greater, which is exactly what the first
tongue's `jbe` and `ja` mean. Nothing in a real score is ever not a number,
and a specification exact everywhere else should not be approximate there.

## What survives a call

The exponential is called once per token. This architecture's convention says
the low halves of the first eight vector registers must be given back, so the
three running floats — the total, the largest score, the kept total — live in
those. The first tongue keeps them on the stack because it has no such
registers to use.

## What it cost to get right

**The frame is ninety-six bytes, not eighty.** The frame pair takes the first
sixteen, so a third floating register saved at offset eight lands on the
return address, and the routine comes back to wherever the low half of a
probability happens to point.

**The unvaried-data guard needed two rules, not one.** It fired twice, and it
was right the first time and wrong the second.

First on the scores: six of forty-eight were a deliberate tie, to exercise the
rule that equal chances go to the lower token, and that read as stale data.
The ties were made fewer rather than the guard weaker, and the test now checks
the tie group exists rather than assuming it.

Then on the recorded answers, where it was simply wrong: 620 draws from a
vocabulary of 48 **cannot** be ninety percent distinct, and demanding it
demands that a choice from a small set stop being one. So blocks now say which
kind they are. Inputs — scores, carried numbers, weights — keep the ninety
percent rule, because anything less means a generator handed back a stale
value. Outcomes state a minimum number of distinct values instead, which still
catches a generator stuck on one answer and stops calling a legitimate
distribution broken.

## Result on 2026-08-04

9 of 9. All 620 choices identical, all 620 chances identical bit for bit, and
both machines ended at position 11 of the carried file.

## Related

`057, 058` — the same sampler on the first architecture, and its comparison.
`099-kernels-aarch64` — the exponential this calls.
`040` — the readable sampler both are held to.
