# 034, 035, 036, 037 — the arithmetic and its fixture — info

The forward pass written plainly on the host, the fixture it produces, and the
tests that guard both. This is the half of issue 103 that makes the other half
possible: every assembly implementation, on every architecture, is correct
exactly when it reproduces what these produce.

## The four files

| | What it is |
|---|---|
| `034-model-shapes` | which tensors a model of a given shape contains, and how large each is |
| `035-reference-forward` | the forward pass, slow and legible |
| `036-make-fixture` | packs a model, runs a pass, records the answer |
| `037-test-forward` | checks the answer against the record, and against what must be true regardless |

`034` exists so that nothing works out tensor names for itself. Two programs
agreeing about names is two programs agreeing until one is edited.

## Running them

```
luajit src/036-make-fixture.lua      # regenerate assets/036-fixture.lua
luajit src/037-test-forward.lua      # check against it
```

The fixture is kept in `assets/` rather than in RAM. It is the one generated
thing here that must persist: an answer nobody can recompute without the very
implementation it exists to check.

## The reference is not meant to be fast

It is meant to be legible and right. A mistake in it does not fail — it becomes
the definition of correct, and three assembly implementations get patiently
taught to reproduce it. That is why `037` checks more than the fixture.

## What `037` checks beyond the fixture

A fixture only catches *change*. These catch being wrong from the beginning,
which a fixture generated from a broken implementation would preserve forever:

| Check | What it catches |
|---|---|
| no score is infinite or nonsense | arithmetic that has escaped its range |
| the same prompt twice gives the same answer | uninitialised memory, unordered iteration |
| the same token later answers differently | position information not reaching the scores at all |
| adding a token does not change earlier answers | something later reaching backwards through the attention |
| a full cache is the size the shape says | the cache calculation and the cache disagreeing |

The fourth is the sharpest. Each step may see only what came before it, so
extending a prompt cannot reach back — and an implementation that lets it is
otherwise very hard to see, because the answers stay plausible.

## Why the weights are random

A fixture needs a model that is the *same* every time, not one that says
anything sensible. Weights drawn from a fixed seed are meaningless and
perfectly reproducible, which is the whole of what is being asked. A different
seed per tensor, so no two tensors hold the same numbers and an implementation
reading the wrong one fails rather than coincidentally agreeing.

## What none of it proves

That the fixture is right — only that the arithmetic has not changed and that
the answer has the shape an answer must have. Whether the model computes what a
model of this kind ought to compute is a question only a real model producing
sensible text can settle.

## Result on 2026-08-02

Seven of seven. Model: 2 layers of 32, 4 heads of width 8 with 2 for keys and
values, feedforward 64, vocabulary 48, context 16 — 21,664 weights across 21
tensors, 88,896 bytes packed.
