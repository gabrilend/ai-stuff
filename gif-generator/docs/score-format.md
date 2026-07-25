# The Score Format — every word of the language

A score is a Lua file in `input/` that makes declarative calls inside
a sandbox offering exactly the vocabulary below and nothing else. It
is a todo list for light: one `canvas` call, then `stroke` calls, top
to bottom in playing order (the canonical writer sorts by time; the
compiler accepts any order, since time values are the truth).

This document is the language's contract. The compiler's validation
wall, the porch's prompt, and the porch's grammar are all derived
from the same vocabulary tables the implementation uses — this prose
is the tour; the tables are the law.

## The canvas call — one per score

```lua
canvas{ size = 256, fps = 25, length = 4.6, seed = 77 }
```

- **size** — canvas width and height in pixels (square). At least 16.
- **fps** — frames per second. Must divide 100 evenly (50, 25, 20,
  10, 5, 4, 2, 1), because GIF delays are whole hundredths of a
  second and any other rate drifts. 25 is the house default tempo.
- **length** — total seconds, spoken in tenths (one decimal place).
- **seed** — any integer. The same score and seed render the same
  bytes on any machine, always.
- **gravity** — optional `{x, y}` force on every particle (a
  fountain's fall, a wind). Absent means none. y grows downward.

## The stroke call — as many as the piece needs

```lua
stroke{ name = "left-hand", at = 0.0, lasts = 2.0,
        color = "ember", fade = "hold", ease = "stroke",
        shape = arc{ center = {76, 108}, radius = 52,
                     from = "12 o'clock", to = "7 o'clock",
                     turn = "clockwise" },
        emit = { rate = 700, speed = 26, aim = 0.7 } }
```

- **at** — when the stroke begins, seconds, tenths only. Two decimal
  places is a validation error, not a rounding.
- **lasts** — its duration, same rule, greater than zero.
- **color** — a hue name. The legal hues live in the palette module's
  vocabulary table (currently: ember, gold, ice, jade, rose, teal,
  violet — but the table is the law, and it grows by rows).
- **fade** — the brightness envelope: `hold`, `in`, `out`, `in-out`,
  or `flash`.
- **ease** — optional, default `linear`: how progress along the shape
  rides time — `linear`, `stroke` (slow then fast, the brush
  gesture), `ease-out`, `smoothstep`. For fills this shapes the
  frontier's advance.
- **name** — optional. Names a stroke so later strokes may borrow its
  landmark with `tip(...)`. Must be unique when present.
- **emit** — optional overrides of the particle character. Legal
  fields and their defaults live in the emitter module's table:
  rate, spread, speed, aim, life, life_jitter, drag, jitter. A
  misspelled field is refused (it would otherwise silently mean
  "default", which is a lie).

## Shapes

- **arc{ center, radius, from, to, turn }** — clock-face positions
  for `from`/`to`: a number (7, 7.2) or a spoken hour ("7 o'clock").
  `turn` is required: `"clockwise"` or `"counterclockwise"` — from
  12 to 7 could sweep either way, and the machine never guesses.
  Twelve is straight up; y grows downward, so clockwise is the
  direction of increasing angle.
- **line{ from, to }** — two points (or `tip` landmarks). The
  emitter rides tip-to-tip over the stroke's window.
- **point{ at }** — stands still.
- **fill{ vertices, sweep }** — a field of glow whose coverage grows.
  Two vertices make a zero-thickness line-field; three or more make
  a polygon. Sweeps: `"at-once"` (the whole region from the first
  breath — for things that fade in as one), `"downward"` (a frontier
  descends), `"radial"` (a disc grows from the centroid), `"along"`
  (two-vertex lines drawing themselves). Fill particles scatter by
  their recipe; aim means nothing extra for a field.

## Landmarks

`tip("name")` — where the named stroke's shape ends, resolved to
plain coordinates at compile time. Forward references are legal (the
endpoint is geometry, not history). Fills have no tip; borrowing one
is an error.

## Ordering, and the walk-back

Authors may declare strokes in any order — `at` is the truth. The
canonical writer keeps its list sorted as strokes arrive: place the
newcomer at the end, decrement an index while the entry above starts
later, and stop at the first comparison that would be a no-op. Equal
times stop the walk too, so simultaneous strokes keep their arrival
order — which the compiler preserves, because emission order is the
random stream's order, and determinism is a promise here.

## What a score may not do

Compute. The sandbox offers the vocabulary and nothing else — no
loops, no math library, no reading files. A score that tries is an
error, not a plugin. Scores stay portable, diffable, safe to share,
and speakable by grammar-constrained small models.

## Validation

The wall (see the scene-script datapath) checks everything before
anything runs, collects every error, and reports them together, each
naming its stroke and field, with the nearest legal word when a name
misses. Documented defaults for absent optional fields are
vocabulary, not fallback; everything else malformed stops the render.
