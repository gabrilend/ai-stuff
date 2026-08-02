# 057, 058 — the sampler in assembly, and its exact comparison — info

`057` emits the assembly twin of the readable sampler (`040`): scores in, one
chosen token out, chance drawn from the carried stream. `058` runs the two
side by side — same scores, same carried numbers — and requires agreement
choice for choice and bit for bit, across every setting the sampler has.

## Running it

```
luajit src/058-test-assembly-sampler.lua
```

## What `057` exports

| Name | Meaning |
|---|---|
| `STREAM_SLOTS`, `PLAN_SLOTS` | the two structures' layouts, as data |
| `stream_offsets()`, `plan_offsets()` | slot name to byte offset, computed |
| `declare()` | teaches the FFI both structures, checked against the assembly slot by slot |
| `new_stream(numbers)` | a carried file as the assembly sees it |
| `new_plan(kernels, count, settings, stream)` | scratch, settings and the exponential's address, filled |
| `x86_64()` | `sampler_choose` as assembler text |

The routine returns the token and writes the chance it was chosen with;
the stream structure advances exactly as the readable one does, so the two
can be held in step and compared afterwards.

## Why exactness is worth more here than anywhere

A score that is off by one bit stays off by one bit. A *choice* that flips at
one boundary joins the context, and every choice after it happens in a
different conversation — two implementations diverge wholesale from that
moment. So the comparison is not "close": fifteen thousand draws across
ordinary, sharpened, flattened, tail-cut, frozen and wrapped settings, all
identical, chances compared as bits.

## No sort

The reference orders every token by likelihood and cuts the tail. The
assembly repeatedly extracts the first strict maximum instead — same order,
reached lazily, stopped as soon as a cutter says stop. The tie rule (equal
chances go to the lower token) is what makes the two walks provably
identical, and it is why the reference's sort must stay stable.

## Things learned that must not be re-learned

**A consumed candidate is felled to minus one**, which no probability can
be, so a slot never wins twice.

**The draw's division is an exponent move.** The state divided by two to
the thirty-first rounds nothing, so converting the state to single first is
the only rounding in the draw — and both sides do it.

**Every vector register belongs to whoever was called last.** Floating
accumulators that must survive the exponential live on the stack, the same
lesson the softmax kernel learned (043).

## Result on 2026-08-02

8 of 8. What remains for other architectures is `401`; baking the carried
file onto an image belongs to the builder (`502`).
