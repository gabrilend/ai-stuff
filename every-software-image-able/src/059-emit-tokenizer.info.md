# 059, 060 — the tokenizer in assembly, and its exact comparison — info

`059` emits the assembly twin of the readable tokenizer (`038`): text into
the model's numbers and back. `060` runs the two over the corpus of cases
where tokenizers actually disagree with each other, and requires the same
numbers, the same text back, and refusals at the same places.

## Running it

```
luajit src/060-test-assembly-tokenizer.lua
```

## What `059` exports

| Name | Meaning |
|---|---|
| `PLAN_SLOTS` | the prepared table's layout, as data |
| `plan_offsets()` | slot name to byte offset, computed |
| `declare()` | teaches the FFI the plan and both routines, checked slot by slot |
| `prepare(tokens, merges)` | the load-time walk from carried tables to the prepared form |
| `x86_64()` | `tokenizer_encode` and `tokenizer_decode` as assembler text |

Encode returns how many tokens, or minus the position of the first unsayable
byte, minus one. Decode returns how many bytes, or the same shape of refusal
for an unknown number. `tokens_out` must hold one number per byte of text,
because that is where the pieces start.

## The prepared table

Encoding by the book means looking strings up while merging, and the metal
has no hashes and no strings to spare. So the work is split as the conductor
split it (`056`): once at load time, the carried tables become — which token
says each byte, what token each merge rule produces, where each token's text
lies — and the think-time halves never touch a string while encoding at all.

The preparation is host code here and belongs to the engine's startup on the
metal; it is all table-walking with no floating point. A rule whose joined
text is not in the vocabulary is refused while preparing, which is earlier
than the reference notices it, and earlier is the right direction for a
refusal.

## The merge order is the reference's, provably

The reference repeatedly finds the lowest-ranked rule that applies anywhere.
The assembly walks the rules in rank order and takes the first that applies,
at its first position, then restarts from the strongest rule — the same
choice, the same tie-breaks, the same full re-scan. The naive cost is
accepted deliberately: correct first, faster later, and `106` measures it.

## Result on 2026-08-02

17 of 17: fifteen corpus cases including every byte from 0 to 255, a null
byte mid-string and a long stretch of prose, plus both refusals landing at
the same positions. What remains for other architectures is `401`.
