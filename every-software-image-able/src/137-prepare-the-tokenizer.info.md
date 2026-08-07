# 137, 138 — the tokenizer's tables, built by the machine — info

`137` emits the assembly that turns the word-lists a model carries into the
four lookup tables the engine encodes with. `138` runs it against
`059.prepare` on the same model and requires the tables to come out identical,
then encodes and decodes through the machine-built ones. Issue `107a`.

## Running it

```
luajit src/138-test-prepare-the-tokenizer.lua
```

## What `137` exports

| Name | Meaning |
|---|---|
| `header_offsets(format)` | field name to byte offset in the model's header, computed from `024` rather than transcribed |
| `expected(token_count, merge_count, text_bytes)` | where each of the four arrays lands, and how many bytes the lot needs — the host's answer, which the assembly is held to |
| `x86_64(format, tokenizer)` | `tokenizer_prepare` as assembler text |

```
int64_t tokenizer_prepare(const uint8_t *blob, void *room, int64_t bytes,
                          TokenizerPlan *plan, int64_t *detail)
```

Returns how many bytes of `room` were used. `room` must begin on a sixteen-byte
boundary — everything inside is placed relative to it, so an unaligned start
makes every array unaligned and nothing here could notice.

| Return | Meaning | What `detail` receives |
|---|---|---|
| positive | how many bytes were used | untouched |
| `-1` | the room is too small | how many bytes short |
| `-2` | a merge rule makes a text the vocabulary does not hold | which rule, from zero |

`detail` may be null.

## Why the refusal is a code and a number

`133` has one way to fail and can return minus the shortfall, letting the
number be the whole diagnosis. This has two, and they want different numbers.
A single negative return cannot carry both without a reader having to know
which kind it is looking at — so the return says which failure and `detail`
says how much.

## What it costs, and where that stops working

Resolving a merge rule means finding the token whose text is two other tokens'
texts joined. There is no hash and nothing to build one with, so it is a walk
over the vocabulary per rule: merge count times vocabulary size times token
length. Nothing on a fixture. On the order of tens of billions of byte
comparisons for a real model with thirty thousand of each.

It is paid once, at startup. If that turns out to be too slow to sit through,
the answer is to pay it at build time and carry the prepared table on the
image — a different design with a different seam, and one for whoever first
boots a real model. `024` says the token table is read once at startup to
build whatever lookup the engine wants, which is what settles it for now.

## The defect this found

The packed fixture carried placeholder token names and merge rules joining
texts no token held, so `059.prepare` refused it — and had always refused it.
Nothing noticed, because the only test that tokenizes builds its own
vocabulary in memory and never asks the blob for one. Three sections each
well-formed alone and unusable together, found by the first program that
needed all of them at once. `036` now emits single-byte tokens for most of the
vocabulary and two multi-byte ones the merge rules actually produce, so the
merge path is exercised rather than skipped.

## First claim wins

When two tokens say the same text the lower number is the trained one, so the
byte map takes the first token that claims a byte and a later one never
overwrites it. That is the reference's rule rather than an accident of
ordering, and getting it backwards would encode text into numbers the weights
barely know — a machine that seems mildly stupid, which `059` names as the
worst failure available.

## Result on 2026-08-07

17 of 17. Four tables identical to the host's, text encoding to the same
numbers through both, and both refusals landing with the right number beside
them — including a doctored model whose first merge rule makes nothing, which
the host refuses too.
