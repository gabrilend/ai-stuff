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

Since issue 704 the porch hears both spaces. The grammar also has
shape, camera, world and pane calls, generated from the 3D wall's
own word lists (`048-shape-words.lua`: one rule per context, a
motion's `kind` picking its words, the runtime's hues, meshes,
effects and solids as choices), and a stroke may name its pane and
follow a shape's tag. The prompt adds `docs/shape-format.md` and
`tests/two-spaces/mixed.lua`. Every reading is said back in plain
lines (`059-say-back.lua`), which also head the written score.

## Usable surface

- **grammar() → GBNF text** — pure function of the vocabulary.
- **prompt(dir) → text** — pure function of the contract and the
  reference scores.
- **parse_calls(reply_text) → calls** — one JSON object after
  another (dkjson from the shared shelf).
- **collect(calls) → raw score** — canvas plus time-settled strokes,
  and the shapes, panes, camera and world in the order spoken, each
  call's prose kept in `raw.said` for the writer. A second camera or
  world call is kept in `raw.called_twice`, and translate refuses the
  reading with a sentence saying so.
- **translate(dir, prose, transport) → score_text, compiled, heard |
  nil, errors, draft** — `heard` is the read-back lines; `score_text`
  starts with them as comments. Transport is a handed-in function
  (request → reply text); tests use fakes. The live HTTP adapter
  joins when the orchestrator lights (see input/cluster.example).
- **cluster_doors(text) → doors** / **cluster(dir) → doors** — the
  roster, parsed purely / read with polite refusals.
