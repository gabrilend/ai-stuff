# 120-sampler-riscv64 — info

Choosing what to say next, in the third tongue. Issue 401.

The engine hands back a score for every word it might say. This turns those scores into a choice. Until it exists on an architecture, an engine there can think and never say anything.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `120-sampler-riscv64.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/120-sampler-riscv64.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.emit(p, sampler)` | described below |

### In more detail

**`M.emit(p, sampler)`**

```
int64_t sampler_choose(const SamplerPlan *plan, const float *scores,
                       int64_t count, float *chance_out)

plan a0, scores a1, count a2, chance_out a3.

`sampler` is the module that describes the two structures (057), passed in
so there stays exactly one description of where every slot sits.

  s0  the plan       s1  the scores      s2  how many
  s3  where the chance is written
  s4  the index, and afterwards how many were kept
  s5  the limit on how many may be kept
  fs0 the running total   fs1 the largest score   fs2 the kept total
```

## Why exactness is worth more here than anywhere else in the engine

A score off in its last bit stays off in its last bit. A CHOICE that flips once joins the context, and every word after it is said in a different conversation -- two implementations diverge wholesale from that moment rather than drifting. So this is held to the first architecture choice for choice, and the chance each was chosen with is compared as bits.

## This architecture has no floating condition flags

and that is the one place the translation had to be reasoned about rather than copied. The other two compare and then branch on flags, and both of them arrange those flags so that an UNORDERED pair -- one where something is not a number -- takes the same branch as less-or-equal. Here a comparison instead writes a one or a zero into an ordinary register, and every such instruction answers zero for an unordered pair.

## Why it emits rather than returning text

This assembler leaves a relocation on a branch to a label in its own file, there is no linker to answer it, and the branch then points at itself -- so every loop spins forever, silently. The word emitter (054) counts every distance itself and must see every instruction to do so.

## Worth knowing

So each comparison is written as the POSITIVE test and branched on being false: where the first tongue says "skip unless strictly greater", this asks "is it strictly greater" and skips when the answer is no. An unordered pair answers no, which is the same branch the other two take. Nothing in a real score is ever not a number, and a specification exact everywhere else should not be approximate there.

## Where it sits

**Belongs to** `401`.

**Checked by** `122-test-sampler-riscv64`.

