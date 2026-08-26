# 1411 — A number a program produced

Changes `docs/002-the-notation.md`, `src/093-blueprint-reader.lua`,
`src/094-ledger.lua` and `src/095-constraint-check.lua`.

## Current behavior

**Done.** `solved` is the notation's fifth kind. `093` accepts it and requires a
bare number and a producer named as `-- from NNN`; `094` treats it as a leaf;
`095` re-runs the named instrument on every pass and fails the run if the copy has
drifted by more than a part in a thousand; `002` documents all of it.

Two instruments answer. `102` produces fourteen values about the cube's plumbing
that no expression could — a network that converges, a search over five hundred
and twelve candidates, a list of twelve edges. `103` produces six about the size
of the blueprint set itself.

**The second one found a real defect on its first run.** `087` and `090` carried
the blueprint count, the symbol count and the constraint count as numbers a person
had typed, and every one was wrong: eighty blueprints offered where there were
eighty-four, five hundred and eight requirements where there were five hundred and
forty-four. Nothing had gone wrong with the design — the documents were describing
an earlier version of themselves, which is what a self-describing document does if
nobody re-counts. That is the exact failure this kind exists to make impossible,
and it was sitting in the covering note a materials engineer opens first.

**The producer marker needed to be explicit.** The first version took the first
three-digit number it found in the meaning field, which picked a cross-reference
to another blueprint out of the middle of a sentence and then reported that
blueprint as a program that would not load. Meanings are prose and a sentence about
a solved value very often mentions where the geometry came from, so the marker is
`-- from NNN` and nothing else.

**A document that counts itself moves while you are counting it.** Converting the
five self-describing declarations from `given` to `solved` changed the number of
`given` declarations in the project, so the first run reported the new figures as
already stale — by five, exactly the number that had changed kind. The second
settled. It is a genuine fixed point and it converges in one pass, and `090` says
so in prose so that nobody meeting it concludes the checker is broken.

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
