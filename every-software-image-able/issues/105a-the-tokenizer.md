# 105a — The tokenizer

## Current behavior

**The reference exists and is tested.** `src/038` encodes and decodes; `src/039`
checks it, 21 of 21 on 2026-08-02 — sixteen round trips through the cases
implementations actually disagree about, including every byte from 0 to 255 and
a null byte mid-string.

Two checks matter more than the round trips. **A round trip passes perfectly if
nothing merges at all** — every byte its own token, decoded straight back — so
there is a separate check that merging shortens what it can. And the strongest
rule must be applied first, because joining a weaker pair earlier can make a
stronger one impossible, and the result then differs from what the model was
trained on. That is exactly the failure that shows as mild stupidity rather
than as an error.

Text containing a byte with no token is refused rather than silently dropped.

**The assembly version does not exist yet.** It now has something to agree
with.

## Intended behavior

Text in, tokens out, and tokens back into text — using the table packed by `101`,
in assembly, like the rest of the engine.

## Why it is not free, and not the model's job

The model never sees text. It operates on integers, and its embedding table says
what each integer *means* without saying which string it *is*. That mapping is
separate data: a vocabulary, and a ranked list of merge rules.

Encoding runs the merges — start from individual bytes, repeatedly join the
highest-ranked adjacent pair until no rule applies. Decoding is a lookup and a
concatenation, and is much easier.

It cannot be derived from the weights and it is not something this project
designs. Choose a model and its tokenizer comes with it.

## Suggested implementation steps

1. Decoding first, since it is a table lookup and it makes everything else
   debuggable — a machine that can print what it just thought is a machine you
   can watch.
2. Then encoding. The naive version rescans the whole sequence after every merge
   and is quadratic; on prompts of any length that cost shows. Get it correct that
   way first, then make it faster.
3. Handle the byte-level cases exactly. Characters outside the simple range,
   whitespace runs, and the beginning of a sequence are where implementations
   differ from each other, and a subtly wrong tokenizer does not fail visibly — it
   produces a model that seems mildly stupid, which is the worst failure available
   because nobody suspects the right thing.
4. Test against the reference from `103` on the same fixtures. Same string in,
   same integers out, exactly, for a corpus with awkward characters in it.
5. Test the round trip: text to tokens to text, unchanged.

## Blocks

`105`.

## Blocked by

`101` for the table.

## Related documents

`docs/010-datapath-the-mind.md`.
