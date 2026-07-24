# 401 — scene script format (the score)

## Founding words

Spoken by gabrilend, 2026-07-23, reshaping this issue before any
implementation began:

> It should be very declarative, with each "stroke" acting as a single
> function call in a very linear list of operations to perform for the
> .gif. Just... a todo list, start at the top and proceed down. The
> LLM doesn't have to describe them in order, it gives a time value as
> well, which is used to order the operations in the lua script. If
> they have the same time value we should expect that to happen, and
> it means it doesn't matter which order to do them in, just pick
> whichever came last and iterate back up. We can do this by keeping
> an "index" into the array of functions to be written to the lua
> script. When we need to iterate the list, we just decrement that
> index until A*B+(1-A)C = 0, as in a no-op, instead of "GOTO and DO"

## Current Behavior

Choreography is written directly in Lua against internal machinery
(the two-clocks demo); there is no declarative document a person could
write without knowing the internals.

## Intended Behavior

The score: a Lua file making a flat, linear sequence of stroke calls —
a todo list for light, top to bottom in playing order.

- One `canvas` call (size, fps, length, seed, one per score), then any
  number of `stroke` calls. Each stroke gives: `at` and `lasts` in
  seconds — **tenths only; one decimal place accepted, more is a
  validation error** — a `color` (hue name), a `shape` (arc, line,
  point, fill — built by sandbox constructors, arcs speaking
  clock-face), a `fade` envelope pick from a small enum (`in`, `out`,
  `in-out`, `hold`, `flash`), optional `ease` for motion along the
  shape, optional `name` so later strokes may borrow landmarks
  (`tip("left-hand")`), optional `emit` overrides with documented
  defaults.
- Authors may declare strokes in any order; `at` is the truth. The
  **canonical writer** sorts on write with the walk-back insertion:
  newcomer at the end, decrement an index while the entry above starts
  later, stop at the first no-op comparison — equal times stop the
  walk, so later arrivals settle below their equal-timed kin. The
  compiler accepts any order; sortedness is a courtesy to readers.
- Score files are data, loaded in a sandbox exposing exactly the
  vocabulary constructors and nothing else (a score that tries to
  compute is an error, not a plugin — scores must stay portable,
  diffable, safe to share, and speakable by grammar-constrained
  models).
- The format document — every field, its meaning, legal values,
  documented defaults — is the deliverable, written as the datapath
  document's expanded successor; the porch's prompt and grammar are
  built from it, so it is the single source of vocabulary truth.
- Two reference scores ship in `input/`: a minimal one-stroke orbit,
  and the full two-clocks vision translation.

## Suggested Implementation Steps

1. Write the format document from the two-clocks dress-rehearsal
   notes (what translated awkwardly there is a vocabulary bug fixed
   here).
2. The sandboxed reader and the vocabulary constructors.
3. The canonical writer with the walk-back insertion.
4. The two reference scores.

## Blockers

- 305 (the dress rehearsal that vets the vocabulary).

## Related Documents

- docs/datapath-scene-script.md (rewritten for the score, this
  issue's specification)
- notes/vision (the prose the vocabulary must carry)
