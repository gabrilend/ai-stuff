# 040, 041 — the sampler and its tests — info

Turning a score for every possible next token into one chosen token. Issue
`104` is the blueprint.

## What `040` exports

| Name | Meaning |
|---|---|
| `new_stream(numbers, position)` | the machine's supply of chance, resumable |
| `softmax_with_temperature(scores, count, temperature)` | scores → probabilities |
| `choose(scores, count, settings, stream)` | one token, and how likely it was |
| `generate_file(seed, count)` | what the image builder bakes in |

`settings` carries `temperature`, `top_k` and `top_p`, read rather than baked
in — a constant is a decision somebody else already made, and the machine may
want to change it.

## Where the chance comes from

A file of random numbers made when the image was built and carried on it. Each
number seeds a generator yielding four thousand draws before the next is taken,
so a hundred kilobytes lasts a very long life.

**The property that matters:** the same image with the same file, given the
same input, produces the same machine. That turns a strange failure into
something reproducible by handing somebody an image.

Running off the end of the file is noticed and recorded, but is not the
disaster it looks like — a drawn number meets a different set of probabilities
every time, so reusing the stream only repeats old choices if the same
questions are being asked, and a machine asking the same questions has a
problem randomness was never going to solve.

## Two details that are easy to get backwards

**Temperature below one sharpens, above one flattens.** Reversed, the machine
is either frozen or incoherent, with no error either way. Tested directly.

**A temperature of zero is a different instruction, not a very small one.** It
means take the highest, and dividing by zero is not a way to say that.

## Sorting must be stable across machines

Ties are broken by token number. An unstable sort would let two identical
images disagree, which would quietly break the only reproducibility this design
has.

## Precision is part of the specification here too

Every floating step is single precision, rounded where the machine rounds,
and the exponential is the specified one (`047`) rather than the host
library's — because a chosen token is discrete, and a hair of difference at
one boundary sends two implementations down different lives. The assembly
twin (`057`) is held to this reference choice for choice and bit for bit by
`058`.

The generator is exact sixty-four bit integers. The first version multiplied
in ordinary host numbers, which hold integers exactly only to fifty-three
bits — and the product here reaches sixty-one. It looked like an integer
generator and quietly was not, which is precisely the kind of specification
no assembly could ever match. The same lesson as the forward pass (`notes/023`),
found before a fixture froze it in place this time.

## What `041` checks

Probabilities that add to one and never invert the score order; determinism
across two runs with the same carried numbers; genuinely different output from
different numbers; that keeping the best two never returns a third; that
temperature zero always takes the highest; that with nothing cut away **every**
token is reachable, since an unreachable tail is a word the model can never
say; and that running out of carried numbers is noticed.

## Result on 2026-08-02

9 of 9, at the single-precision specification.
