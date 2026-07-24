# 405 — vision render (phase 4 capstone)

## Current Behavior

The two-clocks gesture renders from hand-written choreography; the
scene language, compiler, and runner each work; the three have never
been walked as one road by the founding example.

## Intended Behavior

The proof of the whole project: the vision prose, translated into the
scene vocabulary, shipped as the flagship scene in `input/`, rendered
by one invocation of the runner, admired in the gallery.

- The scene file carries the vision's own sentences as comments above
  the actor each translates — the file *is* the demonstration that
  the language can hold the prose.
- Output verified against the phase-3 demo (same gesture, same seed:
  byte-identical, per the compiler's identity test) — proving the
  language layer transparent.
- The phase-4 demo script runs the runner over `input/`, rebuilds the
  gallery, and opens it: the vision looping on black beside every
  earlier demo, with its measured numbers beneath it.
- The phase-picker gains phase 4.

## Blockers

- 401, 402, 403; 404 for the gallery finale.

## Suggested Implementation Steps

1. Translate the vision, sentence by sentence, comments carrying the
   prose.
2. Run, verify identity with phase 3, rebuild gallery.
3. The demo script and picker registration.
4. Read the vision file once more, watching the gif. Anything the eye
   catches that the words promised and the screen lacks becomes the
   next issue.

## Related Documents

- notes/vision (the contract being honored)
- docs/roadmap.md (phase 4)
