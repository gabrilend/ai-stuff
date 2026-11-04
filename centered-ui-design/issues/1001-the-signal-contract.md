# 1001 — The signal contract

**Phase:** 10 — The machine answers
**Blocked by:** none
**Blocks:** 1003, 1004
**Related documents:** delta-version issue 066 (the same system, built in
parallel), /mnt/mtwo/programs/r-mail/docs/attachments.md (the chunking style)

## Current Behavior

There is no agreed way to hand a signal to a physical output.

## Intended Behavior

A signal is a series of values 0.0–1.0 (number), each with a time (seconds
since the signal began, number), and carries its own mapping: a low and a
high end (fractions of full output, numbers) — two ten-percents or the whole
range, whichever suits the hardware. It arrives either as a **single setting**
(one value, held until replaced) or as a **stream** in rmail-attachment
style: "it's been N seconds since the last sent message, so I send M bits of
data from the next end of the section." Chunks are numbered files in an inbox
under `tmp/shared-memory/signal-inbox/`; late or out-of-order chunks are put
back in sequence, and a missing one is asked for again. The reader never
asks where a signal came from.

## Suggested Implementation Steps

1. Chunk file format: sequence number, send time, values.
2. Reader: reorder, detect gaps, write a re-ask file for each gap.
3. Tests: a stream with chunks out of order and one missing.
