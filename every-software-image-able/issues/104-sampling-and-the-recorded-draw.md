# 104 — Sampling, and the recorded draw

## Current behavior

The arithmetic in `103` produces a score for every token in the vocabulary.
Nothing turns that into a choice.

## Intended behavior

A token is selected from the scores, and **the random draw that selected it is
recorded**, because it is one of the few things in this machine that cannot be
recomputed from anything else.

## Suggested implementation steps

1. Turn scores into probabilities, then draw. The usual controls — a temperature,
   a cut-off that discards the unlikely tail — belong here and should be values
   read from somewhere rather than constants, since the machine may later want to
   change them.
2. Find a source of randomness. On bare hardware with no operating system this is
   not free: the processor may offer an instruction for it, or it may have to come
   from timing jitter, or from a device. Whatever the source, it must be written
   down as a device the machine knows it has.
3. **Record every draw.** `docs/006` says the machine writes down only what it
   could not have computed for itself, and a random number is exactly that. Two
   consequences follow: the model's own reasoning becomes replayable, and a
   machine can be stepped back into why it chose an approach rather than only
   into what the approach then did.
4. Decide where the draws go before there is anywhere to write. Until the machine
   has moved in (`docs/003`) there is no storage, so the earliest draws either
   live in memory and are lost on power failure, or are not recorded at all. Say
   which, in the ticket for `303`, rather than leaving it to whoever notices.
5. Test that replay works: run a fixed prompt, record the draws, run again feeding
   the recorded draws back, and confirm the identical tokens come out.

## Note on non-determinism

This is not a defect to be removed. A single token is a weighted random choice; a
paragraph is not random at all. Two machines diverge from the first token and
that is expected — what matters is the choices going forward.

## Blocks

`105`, `106`.

## Blocked by

`103`.

## Related documents

`docs/006-datapath-status-and-tolerance.md` — recording what cannot be
recomputed, and what replay buys.
