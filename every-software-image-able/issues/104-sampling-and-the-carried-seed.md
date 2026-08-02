# 104 — Sampling, and where the randomness comes from

## Current behavior

The arithmetic in `103` produces a score for every token in the vocabulary.
Nothing turns that into a choice.

## Intended behavior

A token is selected from the scores, using randomness drawn from a file carried on
the image — so that the same image with the same file produces the same machine,
exactly, until it makes randomness of its own.

## Suggested implementation steps

1. Turn scores into probabilities, then draw. The usual controls — a temperature,
   a cut-off that discards the unlikely tail — belong here and should be read from
   somewhere rather than baked in, since the machine may later want to change
   them.
2. **Read the randomness from the carried file.** The image builder generates
   around a hundred kilobytes of random numbers at build time (`502`) and bakes
   them in. Sampling walks that file.
3. Keep the position in the file as part of what the machine knows about itself.
   Two machines from the same image, given the same inputs, walk the same
   positions and make the same choices — which makes a failure reproducible by
   handing somebody the image rather than by explaining what happened.
4. **Do not record the draws.** The earlier design had every random number written
   down so that thinking could be replayed. Carrying a seed achieves the same
   determinism for far less machinery, and the recording can be added later if
   something turns out to want it.
5. **Decide what happens when the file runs out**, because it will. A hundred
   kilobytes is a finite budget of unpredictability, and a machine that thinks for
   a day will spend it. Wrapping around silently is the worst option available —
   the machine would begin making the same choices again without noticing. See
   below.
6. Test that determinism holds: same image, same file, same input, same tokens.

## The file is a clock

This is the consequence worth noticing. The carried randomness gives the machine a
countable supply, and **it has to build its own source before the supply is
gone.** That is a deadline, in a design that otherwise has none.

Whatever the machine eventually builds — a processor instruction for it, timing
jitter, noise from a device it found — is its own business (`strategems/009`).
What the seed owes it is a clear signal that the supply is running low, early
enough to do something about it, and a refusal rather than a quiet wrap-around
when it is gone.

## Blocks

`105`, `106`.

## Blocked by

`103`, and `502` for the file.

## Related documents

`docs/006-datapath-status-and-tolerance.md` — what a machine writes down, and
what it can recompute instead.
