# 058-gbnf — the porch's grammar, read and tried

A small reader of GBNF, the grammar language llama.cpp constrains a
model with, and an exact matcher for it. No model runs where the tests
run, so this stands in for one: it proves the grammar the porch
generates (`032-porch.lua`) names no rule it never defines, that the
tool-calls a person would want are sayable, and that a misspelled word
is not (issue 704).

It reads the subset the porch writes: one `name ::= body` rule per
line; literals with `\" \\ \n \t` escapes; `[character classes]` with
ranges and `^`; rule names; `(groups)`; and `?`, `*`, `+`. Comments and
rules over several lines are not read.

## Usable surface

- **read(text) → grammar** — `{ rules = { name = tree }, order = {
  name, ... } }`. Refuses a line that isn't a rule, a rule defined
  twice, or a body it can't parse, naming the rule and the character.
- **undefined(grammar) → { name, ... }** — every rule used but never
  defined, sorted. Empty is whole.
- **matches(grammar, text, start) → true | false** — whether the
  whole text is one the grammar allows from `start` (default `root`).
  Tries every way through, remembering each rule's answers at each
  place, so it is exact; fast enough for a few hundred characters.
