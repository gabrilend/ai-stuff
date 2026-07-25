# 022-score — reader, constructors, insertion, canonical writer

Scores are Lua files run in a sandbox offering exactly the
vocabulary — canvas, stroke, arc, line, point, fill, tip — and
nothing else. They declare; they never compute. Constructors are
dumb taggers; ALL deep validation belongs to the compiler's wall so
a score's mistakes are reported together. docs/score-format.md is
the language's contract in prose.

## Usable surface

- **read(path) → { canvas, strokes }** — runs the file sandboxed.
  Structural refusals only: no canvas, two canvases, no strokes, or
  any attempt to compute.
- **insert(list, stroke)** — the walk-back insertion (place at the
  end, decrement while the entry above starts later, stop at the
  first no-op). Stable at equal times: arrival order kept, because
  emission order is the random stream's order and determinism is a
  promise.
- **write(raw) → text** — canonical score text: canvas first,
  strokes sorted by insert, fields in fixed order so two writes are
  byte-identical, comments (the porch's prose sentences) above the
  strokes they describe.
- **fmt_shape(shape) → text** — one shape back into constructor
  syntax; used by write.
