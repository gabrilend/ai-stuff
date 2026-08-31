# 127-test-tokenizer-elsewhere — info

Text into the model's numbers and back, on the second and third machines, held to the first over the corpus where tokenizers actually disagree. Issue 403.

A machine that cannot turn text into numbers cannot read the instruction it woke up holding. This checks that all three processors turn the same text into the same numbers.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `127-test-tokenizer-elsewhere.lua` and run the sweep again.*

## Invocation

```
luajit 127-test-tokenizer-elsewhere.lua [--dir ROOT] [--seconds N]
```

## What it describes

| Field | Value | |
|---|---|---|
| `numbers` | `numbers }` |  |
| `plan` | `0, tokens_out = 64, text_out = 4096, hex = 8192` |  |
| `total` | `12288` |  |

## Why the awkward corpus and not a few words

This routine has no floating point in it and ports mechanically, which makes it look safe. Its failure mode is a WRONG ANSWER THAT LOOKS FINE: a tokenizer that joins in a slightly different order still produces numbers, and the machine then reads a subtly different instruction and nothing faults. So the cases carried are the ones where implementations genuinely differ -- runs of spaces, a null byte in the middle, bytes above 127, text that is entirely one token, and nothing at all.

## Where it sits

**Belongs to** `403`.

