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
2. **Seed a generator from the carried file.** The image builder puts around a
   hundred kilobytes of random numbers on the image at build time (`502`). Each
   one seeds a cheap generator that produces many thousands of draws before the
   next number from the file is taken. That stretches the file across a very long
   life while keeping the property that matters: same image, same file, same
   machine, exactly.
3. Keep the position in the file as part of what the machine knows about itself.
   Two machines from the same image, given the same inputs, walk the same
   positions and make the same choices — which makes a failure reproducible by
   handing somebody the image rather than by explaining what happened.
4. **Do not record the draws.** The earlier design had every random number written
   down so that thinking could be replayed. Carrying a seed achieves the same
   determinism for far less machinery, and the recording can be added later if
   something turns out to want it.
5. Say something when the file is exhausted and the stream wraps. Not as an
   alarm — see below — but because reaching the end of it at all is a fact worth
   knowing about a running machine.
6. Test that determinism holds: same image, same file, same input, same tokens.

## Why exhaustion is not the hazard it looks like

A drawn number is applied to a different set of probabilities every time, because
the context differs every time. So reusing the stream only reproduces earlier
choices if the same questions are being asked, and the same questions only recur
if the machine has made no progress at all — which is a problem the randomness
was never going to solve.

With a generator seeded from the file the supply is effectively unbounded in any
case. Whatever source the machine eventually builds for itself — a processor
instruction, timing jitter, noise from a device it found — is its own business
(`strategems/009`).

## Blocks

`105`, `106`.

## Blocked by

`103`, and `502` for the file.

## Related documents

`docs/006-datapath-status-and-tolerance.md` — what a machine writes down, and
what it can recompute instead.
