# 402 — scene compiler

## Current Behavior

Score files can be read as stroke lists; nothing turns them into the
tracks the simulator runs, and nothing guards the gate.

## Intended Behavior

The compiler: score in, timeline out — with the validation wall in
front.

- Validation first, everything at once: unknown easing, fade, or hue
  names (checked against the vocabulary tables themselves), arcs
  without a turn direction, landmarks borrowed from strokes that don't
  exist, times outside the canvas length, **times spoken in more than
  tenths of a second**, malformed blocks. Errors are collected and
  reported *together*, each naming its stroke and field — a score
  author fixes one render's worth of mistakes per attempt, not one
  mistake.
- No silent repair, ever. Documented defaults for absent optional
  fields are vocabulary (they come from the format document);
  anything else malformed stops the render.
- Every unknown-name error carries the *nearest legal word* ("no
  easing named `strok` — nearest legal: `stroke`"), computed by edit
  distance against the derived legal-name lists. Added when phase 6
  (the listening porch) joined the roadmap: these suggestions are what
  the porch quotes back to its models on retry — but they were always
  owed to humans, who also say the wrong word while describing the
  mechanism correctly.
- Compilation resolves names to numbers: landmark borrowings become
  coordinates, hue names become palette ramp indices, clock words
  become angles, easing and fade names become functions. The timeline
  that comes out contains no strings to look up at runtime.
- Tests: each validation error fires on a minimal bad score and names
  the right stroke; the reference scores compile; a compiled
  two-clocks score renders byte-identically to the hand-choreographed
  phase-3 demo given the same seed — the compiler proves it adds
  nothing and loses nothing.

## Suggested Implementation Steps

1. The validator (error collection, derived legal-name lists).
2. The resolver/compiler to tracks.
3. The byte-identity test against the phase-3 demo.

## Blockers

- 401 (the format), 303 (the tracks it compiles to).

## Related Documents

- docs/datapath-scene-script.md (validation-is-a-wall section)
