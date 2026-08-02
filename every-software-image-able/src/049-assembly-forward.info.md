# 049, 050 — a whole thought on real arithmetic — info

A complete forward pass in which every piece of arithmetic is done by the
assembly kernels. The order of operations is still decided in a readable
language; only the arithmetic has moved.

## Running it

```
luajit src/050-test-assembly-forward.lua
```

## Why this intermediate step exists

Writing the whole engine in assembly at once means discovering at the end that
something in the middle is wrong. Moving the arithmetic first and keeping the
conducting readable means a disagreement can only be in the arithmetic, because
that is the only thing that changed.

What remains afterwards — the conducting — contains no floating point at all,
which is why it was left for last.

## What it proves that the kernel tests could not

Each kernel was already shown correct alone. This shows they are correct
**together**, which is a different claim: a piece can be right in isolation and
be handed the wrong thing by the piece before it, and testing them separately
would never notice.

It also runs the whole pass twice, once with the plain matrix kernel and once
with the four-at-a-time one, and requires the two to agree. That is a far
harder test of the wide kernel than any single call, because a difference in
one bit anywhere compounds through twenty-two tensors and two layers before it
reaches a score.

## What it found

A disagreement of four parts in a thousand million, at the second token only.
The first token matched exactly — and that pattern was the diagnosis, because at
position zero softmax of a single score is one regardless and rotation by a zero
angle is the identity, so anything acting only from the second position was the
suspect.

The cause was in the **reference**, not the assembly. Accumulating a weighted
value the obvious way computes the product and the sum together in double and
rounds once; a machine rounds after the multiply and again after the add. One
rounding against two.

Two earlier fixes were plausible and wrong: an unrounded attention scale, which
was a real defect and not this one; and rounding a square root before dividing
rather than after, which *moved* the disagreement rather than removing it,
because the other side rounded only the result.

**Where a rounding happens is part of the answer.** A recorded answer catches a
change in arithmetic; it cannot catch a specification too imprecise to
implement twice. What caught this was a second implementation — and it found the
bug in the first, which was not the expected direction.

## Result on 2026-08-02

4 of 4. Every score across every step matches the recorded answer bit for bit,
both matrix kernels agree, and the position and causality invariants hold on the
assembly path as they do on the reference.
