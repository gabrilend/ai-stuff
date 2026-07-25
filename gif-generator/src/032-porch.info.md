# 032-porch — the listening porch (testable whole)

The translator as a client of the pipeline: prose in, a candidate
score out, through a model that paints in tool-calls. The grammar is
generated from the same vocabulary tables the validator trusts —
misspelling is physically impossible; the model's freedom is
choosing among legal readings, and times are structurally tenths.
The prompt is assembled from the format contract and both reference
scores, verbatim. Arriving strokes settle by the walk-back
insertion; the canonical writer carries the person's sentences as
comments; the wall's teaching is quoted back verbatim for a bounded
number of retries, and exhausted patience surfaces the errors WITH
the best draft — never a silent repair or drop.

## Usable surface

- **grammar() → GBNF text** — pure function of the vocabulary.
- **prompt(dir) → text** — pure function of the contract and the
  reference scores.
- **parse_calls(reply_text) → calls** — one JSON object after
  another (dkjson from the shared shelf).
- **collect(calls) → raw score** — canvas plus time-settled strokes.
- **translate(dir, prose, transport) → score_text, compiled |
  nil, errors, draft** — transport is a handed-in function
  (request → reply text); tests use fakes. The live HTTP adapter
  joins when the orchestrator lights (see input/cluster.example).
- **cluster_doors(text) → doors** / **cluster(dir) → doors** — the
  roster, parsed purely / read with polite refusals.
