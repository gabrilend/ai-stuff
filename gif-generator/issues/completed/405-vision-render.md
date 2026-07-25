# 405 — vision render (phase 4 capstone)

## Current Behavior

Complete — the road is one road. The vision score in input/ (its
comments the vision's own sentences) renders through the front door
byte-identical to phase 3's hand-staged demo: the same 333536 bytes,
proven by comparison inside the phase-4 demo where everyone can
watch it fail if it ever does. Getting there required two honest
fixes to the phase-3 demo, both cross-noted there: its tips now come
from the landmark machinery (independent computation differed in the
last floating-point bits, and byte-identity is the whole proof), and
its frame count rounds instead of floors (4.6 x 25 is 114.999... in
floats — the runner's first outing caught the stolen frame). The
demo then rebuilds the gallery so the vision loops beside every
earlier piece with its measured numbers. The phase-picker gained
phase 4 by existing — it reads the playbill from disk.

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
