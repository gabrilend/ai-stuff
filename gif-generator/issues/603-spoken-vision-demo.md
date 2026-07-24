# 603 — spoken-vision demo (phase 6 capstone)

## Current Behavior

The porch works part by part (translator, fan-out, pick page); no one
has ever walked up and simply *spoken* a gif into being.

## Intended Behavior

The phase-6 demo: the whole premise performed in one sitting.

- A prose paraphrase of the founding vision ships in `input/` as a
  `.prose` file — reworded from the original, and carrying **one
  deliberate misspelling and one wrong-but-mechanism-true word**
  (say, "swooshes, slow then quick" where the vocabulary says
  `stroke`), because the premise under test is that a person can say
  the wrong word and still be understood. The prose file marks these
  traps in a comment for the future reader.
- The demo runs the full porch: three readings, thumbnails, pick page
  opened in the browser. The person picks; the promoted scene renders
  full-size; the gallery rebuilds with the spoken vision beside the
  typed one.
- The demo prints, from measurement: per-node translation time,
  retries used per reading, wall verdicts, and — the number that
  matters — whether the misspelled mechanism landed on the right
  vocabulary word in each of the three readings.
- The phase-picker gains phase 6.

## Blockers

- 601, 602; the running cluster itself (endpoints in `input/cluster`
  — hosts and ports supplied by gabrilend when the cluster is lit).

## Suggested Implementation Steps

1. Write the paraphrase prose with its two honest traps.
2. The demo script: porch end to end, measurements printed, gallery
   rebuilt, picker registered.
3. Sit on the porch and speak. Compare the spoken gesture to the
   typed one, side by side in the gallery — the distance between them
   is the phase's true measurement.

## Related Documents

- notes/vision (the text being paraphrased)
- docs/roadmap.md (phase 6)
