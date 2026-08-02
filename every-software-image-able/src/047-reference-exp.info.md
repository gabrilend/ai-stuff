# 047, 048 — the exponential, specified — info

Raising e to a power, defined here rather than borrowed from a library. The
last function standing between this project and a forward pass comparable
exactly rather than approximately.

## Running the comparison

```
luajit src/048-test-exp.lua
```

## Why it needed specifying

Every language and library computes this slightly differently in the final
bits. If the readable version and the assembly version each ask their own,
they disagree and neither is wrong — and a fixture matchable only within a
tolerance turns every later disagreement into a judgement call.

Multiplication, addition and square root are pinned by the standard. Sine and
cosine were removed from the engine entirely by carrying a table of turns
(`034`). That left the exponential, and rather than accept a tolerance for its
sake, it is written down as a specification both sides implement.

## How it works

Raising e to a power becomes raising two to a power, because two is the base
the hardware already stores numbers in. That power splits into a whole part and
a fraction: the whole part becomes an adjustment to the number's exponent
field, which is exact and free, and the fraction — always between minus a half
and a half — is approximated by a short polynomial.

## Two polynomials, and why the longer one

Both are kept and both are measured, because which is right is a question of
evidence rather than preference. Measured across the ranges a model actually
produces:

| Range | five terms | seven terms |
|---|---|---|
| softmax, after the largest is removed | 4.6e-06 | 2.1e-06 |
| softmax, the common part of that range | 3.4e-06 | **3.0e-07** |
| the feedforward gate | 4.7e-06 | 2.0e-06 |
| everything representable | 1.0e-05 | 7.7e-06 |

Seven wins everywhere and wins tenfold in the range that matters most, which is
near zero — where softmax spends nearly all its arguments, because the largest
score is subtracted first. In the wide ranges the improvement is smaller,
because there the error comes from the range reduction rather than from the
polynomial, and a longer polynomial does not help with that.

`M.CHOSEN` selects one. Changing it changes every recorded answer downstream,
which is correct: it is a change to the specification, and the fixture is
regenerated.

## The coefficients are not cited

They are one over a factorial and can be re-derived by anyone. A minimax fit
would be closer for the same number of multiplications, and would be an
improvement to make in one place with both sides following. Being *identical*
on both sides matters more here than being closest to the true value.

## Constants are computed, never transcribed

Assembly needs the exact bits of a single-precision number. Writing those by
hand produced `0x3a83b8ac` where the correct pattern for one seven-hundred-and-
twentieth is `0x3ab60b61` — which would have made every softmax and every gate
in every layer quietly slightly wrong, with no failure anywhere.

The assembly is therefore generated with its constants already computed from
this file's values (`043`). There is no longer an opportunity to transcribe.

## What `048` checks beyond accuracy

That e to nothing is exactly one; that nothing escapes to infinity, since the
result always feeds a division and an infinity there poisons a whole row of
probabilities rather than failing; that a larger power never gives a smaller
answer, because a polynomial that dips would make a token's probability fall as
its score rose and nothing downstream could detect that; and that both ends
clamp.

## Result on 2026-08-02

8 of 8 here, and in `044` the assembly agrees with this file **bit for bit**
across the whole range at tenth steps, plus past both clamps.
