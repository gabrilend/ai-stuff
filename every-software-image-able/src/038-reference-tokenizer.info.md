# 038, 039 — the tokenizer and its tests — info

Turning text into the numbers a model works in, and back. Written plainly on
the host so the assembly version has something to be judged by, exactly as the
arithmetic is (`035`). Issue `105a` is the blueprint.

## What `038` exports

| Name | Meaning |
|---|---|
| `load(tokens, merges)` | builds the lookups; returns a vocabulary |
| `encode(vocabulary, text)` | text → array of token numbers, or `nil, complaint` |
| `decode(vocabulary, numbers)` | token numbers → text, or `nil, complaint` |
| `byte_vocabulary(extra)` | a vocabulary that can say anything, plus longer pieces |

## Why it is not derivable from the weights

The model has a row per token saying what that token **means** and nothing
anywhere saying which string it **is**. Those are different facts and only one
is in the model, so the table travels beside the weights and this walks it.

## How encoding works

Start from the smallest pieces the vocabulary knows — single bytes — then
repeatedly join whichever adjacent pair has the strongest rule, until no rule
applies. **Order is the whole algorithm.** Joining a weaker pair first can make
a stronger one impossible, and the result then differs from what the model was
trained on.

Decoding is a lookup and a concatenation, and is built first because a machine
that can print what it just thought is a machine somebody can watch.

## Why the test is mostly awkward cases

A subtly wrong tokenizer does not fail. It produces a model that seems mildly
stupid — slightly worse at everything, for no visible reason — and nobody
suspects the right thing for weeks. Ordinary words get tokenized correctly by
accident; the disagreements between implementations live in newlines, runs of
spaces, bytes above 127, and the empty string.

`039` round-trips sixteen such cases, including every byte from 0 to 255 and a
null byte mid-string.

**The round trip alone is not enough.** It passes perfectly if nothing merges
at all — every byte its own token, decoded straight back. So there is a check
that merging shortens what it can, and one that the strongest rule is applied
first, which is the ordering property above.

## Refusals

Text containing a byte with no token is refused rather than silently dropped.
Dropping produces a model that misreads a document; refusing produces a
complaint somebody can act on.

## Result on 2026-08-02

21 of 21.
