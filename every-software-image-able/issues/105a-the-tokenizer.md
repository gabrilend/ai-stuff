# 105a — The tokenizer

## Current behavior

The thinking loop moves integers. Nothing turns text into those integers or back.

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
