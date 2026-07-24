# Datapath — from score to timeline

This document follows a motion description from the file the user (or
the porch) wrote to the moment-by-moment answer sheet the simulator
reads.

Amended 2026-07-23 at gabrilend's direction: the surface language is
no longer a nested table of actors but a **score** — a flat, linear
todo list of strokes. Start at the top, proceed down.

## The input: a score

A score is a Lua file in `input/` that makes a sequence of declarative
calls — one per stroke of light — inside a sandbox that offers exactly
the vocabulary and nothing else. Each stroke is a single function call
in a linear list of operations; each gives its own time, so the file
reads top-to-bottom in playing order. A sketch (the two-clocks vision,
abridged):

```lua
canvas{ size = 256, fps = 25, length = 4.0, seed = 7 }

stroke{ name = "left-hand", at = 0.0, lasts = 2.0,
        color = "ember", fade = "in", ease = "stroke",
        shape = arc{ center = {88,128}, radius = 60,
                     from = "12 o'clock", to = "7 o'clock",
                     turn = "clockwise" },
        aim = "inward" }

stroke{ name = "seal-line", at = 2.2, lasts = 0.8,
        color = "violet", fade = "in",
        shape = line{ from = tip("left-hand"), to = tip("right-hand") } }

stroke{ at = 2.6, lasts = 1.2, color = "violet", fade = "in-out",
        shape = fill{ vertices = { tip("left-hand"), tip("right-hand"),
                                   {128, 190} },
                      sweep = "downward" } }
```

The elements of a stroke:

- **at** — when it begins, in seconds. **Times speak in tenths**: one
  decimal place accepted, more is a validation error. (The porch's
  models are held to the same rule by grammar.)
- **lasts** — its duration, same tenths rule.
- **color** — a hue name from the palette vocabulary.
- **shape** — arc, line, point, or fill, built by the sandbox's
  constructors; arcs speak clock-face; fills give vertices and a
  sweep style.
- **fade** — an envelope pick from a small enum: how brightness
  enters and leaves (`in`, `out`, `in-out`, `hold`, `flash`).
- **ease** — optional; how *progress along the shape* is shaped
  (`stroke` = slow then fast, etc.). Defaults to `linear`.
- **name** — optional; lets later strokes borrow landmarks
  (`tip("left-hand")` = where that stroke's shape ends), resolved to
  plain coordinates at compile time.
- **emit** — optional overrides for particle character (rate, spread,
  life); every field has a documented default. Vocabulary, not
  fallback.

## Order is time's job, not the author's

The author (person or model) may declare strokes in any order; the
`at` value is the truth. The canonical writer sorts strokes by time
when it writes a score file, using an index that walks back up the
list: place the newcomer at the end, then decrement the index while
the entry above starts later than it, and stop at the first
comparison that would be a no-op — stop-instead-of-GOTO-and-do. Equal
times mean the order genuinely does not matter, and the walk stops
there too, so later arrivals settle just below their equal-timed
kin.

In gabrilend's founding words: *"Just... a todo list, start at the top
and proceed down… When we need to iterate the list, we just decrement
that index until A·B+(1−A)·C = 0, as in a no-op, instead of 'GOTO and
DO'."*

The compiler accepts any order (activation windows are absolute); the
sort is for the reading human. A machine-written score is always
sorted; a hand-written one is merely encouraged to be.

## The clock-face convention

The vision speaks in clock positions, so the system does too. This is
a data-format decision worth pinning down once, here:

- The canvas uses screen coordinates: x grows rightward, y grows
  *downward*. This flips the usual math convention, so "clockwise" on
  screen is the direction of *increasing* angle.
- "12 o'clock" is straight up from an arc's center. Each hour is 30
  degrees. Hour h converts to the angle (h / 12) x 360° - 90°,
  measured in screen space.
- Fractional hours are legal ("about 7" may become 7.2 by eye).

## Validation is a wall, not a net

The compiler checks the score before anything runs: unknown fade or
easing or hue names (each error carrying the nearest legal word),
arcs missing a direction of turn, landmarks borrowed from strokes
that don't exist, times outside the canvas length or spoken in more
than tenths — each is a hard, named error that says which stroke and
which field, and all errors are reported together in one pass. There
are no defaults quietly filled in for malformed input. (Absent
*optional* fields have documented defaults; that is vocabulary, not
fallback.)

## The output: a compiled timeline

Compilation turns each stroke into a **track**:

- a *path function*: progress (0 to 1) → position on the canvas
  (fills return a region sampler — coverage → random point inside the
  covered portion — instead).
- an *easing function*: raw time-fraction → shaped progress, applied
  before the path is consulted.
- an *envelope function*: the fade enum realized — raw time-fraction
  → emission strength.
- an *activation window*: start and end in seconds.
- an *emitter recipe*: rate, spread, lifetime, hue — the defaults
  plus any overrides, resolved to numbers.

Landmark borrowings are resolved at compile time into fixed
coordinates — the timeline holds no name lookups, only numbers.
Downstream, the simulator asks one question per track per frame:
*"at time t, where are you, how strongly are you emitting?"* — and
gets numbers back.

## Relevant pieces

- the score reader (runs the file in the constructor sandbox)
- the canonical writer (the walk-back insertion; used by the porch
  and by any tool that emits scores)
- the score validator (the wall described above)
- the track compiler (paths, easings, envelopes, windows, recipes)
- the timeline (the array of tracks the simulator iterates)
