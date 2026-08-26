# 1411 — A number a program produced

Changes `docs/002-the-notation.md`, `src/093-blueprint-reader.lua`,
`src/094-ledger.lua` and `src/095-constraint-check.lua`.

## Current behavior

The notation has four kinds and none of them fits a number that came out of a
computation the notation itself cannot express.

- `given` is a decision. Somebody chose it and can choose differently.
- `measured` is the world. Changing it means changing material.
- `derived` is an expression in this grammar, recomputed on every run.
- `target` is a goal with no derivation, and the checker calls a set that still
  has one unfinished.

Two numbers in the project are none of these. `024`'s worst-served flow fraction
is the output of a twenty-branch hydraulic solve; `019`'s service time waits on a
procedure to exist and be timed. The first is currently written as a `target`
with an estimate in it, which is the closest available lie: it is not a goal, it
is an answer nobody has computed yet.

The cost of having no kind for this is that the moment somebody does compute it,
the only place to put the answer is a `given` — and a `given` is a number the
reader is invited to argue with by choosing differently, which is exactly the
wrong invitation for a number that is what it is because the geometry says so.
Worse, it goes stale silently: change a rail's cross-section and the flow shares
change, and nothing in the project notices that the number in the blueprint is
now describing a machine that no longer exists.

## Intended behavior

**A fifth kind, `solved`: a number a named program produced, which the checker
re-runs and refuses if it has drifted.**

```
f_worst_served | 1 | solved | 0.9314 | share of the mean flow the worst-served
                                       face receives, from 102
```

The value field is a bare number, like `given` and `measured`. The difference is
what the reader is told to do about it, and what the checker does about it.

### The declaration carries its producer

A `solved` symbol names the instrument that produced it. The name goes in the
meaning field, in the same place a `measured` names its datasheet, because that
is the sentence a reader meets the symbol in and it is the sentence that has to
answer *where did this come from*.

### The checker re-runs the producer

This is the part that makes the kind worth adding rather than a comment on a
`given`. The checker asks the named instrument for its current answer and
compares it to the number in the blueprint. Agreement within a part in a thousand
— the same tolerance `~=` uses everywhere else — passes silently. Disagreement is
reported like a failed constraint: the symbol, the blueprint, the stored value,
the recomputed value, and the drift.

A stale `solved` symbol is therefore a loud failure and not a quiet wrong answer,
which is the whole difference between a derived quantity and a remembered one.

### Who answers

An instrument that produces `solved` values exposes a table from symbol name to
quantity. The checker loads every instrument that any `solved` symbol names,
asks each for its table, and looks the symbols up. An instrument that names a
symbol nobody declared, or a declaration that names an instrument that does not
answer for it, are both reported — the two halves have to agree in both
directions or the mechanism is decoration.

### What it is not

**It is not an escape hatch for a hard derivation.** If an expression in this
grammar can compute the number, it must. The kind exists for computations the
grammar genuinely cannot hold: an iterative solve, a search over a discrete set,
anything that needs to remember more than one number at a time.

**It does not make a set finished on its own.** `target` still means unfinished.
`solved` means finished by other means, and the report should count them
separately so a reader can see how much of the design rests on programs rather
than on expressions.

## What the change must offer

- `093` accepts `solved` in the kind field and requires a bare number.
- `094` treats it as a leaf, like `given` and `measured` — it has no references
  and cannot participate in a cycle.
- `095` gains a re-run pass, a drift report, and a count in the summary.
- `002` documents the kind, the naming rule and the drift check.

## Tests

- A `solved` symbol whose producer agrees passes silently.
- A `solved` symbol whose producer has drifted a part in a hundred fails, and the
  report shows both numbers.
- A `solved` symbol naming an instrument that does not answer for it is reported.
- An instrument answering for a symbol nobody declared is reported.
- A `solved` symbol with an expression instead of a number is refused at read
  time, like a `given` with an expression.
- The summary counts `solved` apart from `target`.

## Blocks

`305`, which cannot record its answer until there is a kind to record it in.

## Blocked by

`1403`, `1404`, `1405`.

## Related documents

`002` is the normative one and this changes it. `009` carries the open question
about the notation being unable to hold a list, which this does not fix — a
program answering with one number is not the same as the notation holding a set.
