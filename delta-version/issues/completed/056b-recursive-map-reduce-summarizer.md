# Issue 056b: Recursive Map-Reduce Summarizer

**Phase**: 0 - Tooling
**Status**: Completed (2026-11-02)
**Priority**: High
**Created**: 2026-11-02 (split out of 056, which specified it)
**Parent**: 056 (Recursive Transcript Summarization)

---

## Current Behavior

A saved conversation has no summary, and most are longer than the local
model can read at once. Issue 056 specifies the engine; this file records
building it.

## Intended Behavior

As specified in 056, step 2: `scripts/summarize-transcript.lua` reads one
transcript and emits title, slug, blurb and final summary, slicing to the
model's context with exact token counts, recursing until one summary is
left, logging each level, and changing no file.

## Suggested Implementation Steps

1. Split the transcript into turns without bisecting one.
2. Pack turns into slices sized by `/tokenize`.
3. Summarise each slice; merge the summaries level by level until one is left.
4. Title and blurb passes; slugify the title.
5. Emit a small record for 056c; test against the stand-in model.

## What Happened

**2026-11-02 — built and tested against the stand-in model.**

- **Slices hold whole exchanges.** 056 asked only that no turn be bisected.
  The first build packed single turns, so a slice could end on a user request
  whose answer started the next slice. The model would then summarise a
  question without its answer, and the answer without its question. Slices
  are now cut between exchanges: a request plus the parts that answer it. An
  exchange bigger than a slice is cut between lines, and that is reported.
- **Merging that cannot shrink stops loudly.** If no two summaries fit in
  one slice, another level would leave the same count, so the run exits 1 and
  names the options to change. It does not loop.
- **Qwen3's `<think>` blocks** are removed from every answer before use.
- **The record is plain text,** with fixed `name: value` lines and two
  headings, so the Bash applier (056c) can read it without a JSON parser.
  `--json` gives the same fields for anything else.
- **`--plan`** shows the slicing and its token sizes and calls only
  `/tokenize`, so the cost of a run on a large transcript can be seen before
  the model is asked anything.
- **The stand-in brain** learned `summarize-slice`, `merge-summaries`,
  `title` and `blurb`, plus `STAND-IN-THINK` to imitate a reasoning block.

Tests: `scripts/test-summarize-transcript.sh` passes 40/40. The other
stand-in suites still pass (040 33, 049 30, 051 24, 053 23). Not done here:
a run against the real llama.cpp server. No model was downloaded or started.
