# hubness-experiment.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/hubness-experiment.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Image-embedding measurement tool (Issue 9-013). Turn the seam knob and watch
three different things move at once, for an image synthesized between two
chronological neighbours (a = BEFORE poem, b = AFTER poem):

  1. CENTRALITY  -- cosine to the corpus centroid (the centre of mass). High =
     a HUB that floods similar lists. Compares the dimensional cross-cut
     against a weighted average across the whole 0..100% blend.
  2. STRUCTURE/TEXTURE -- cosine of the cross-cut to the BEFORE poem (its
     "structure", the front dims) and the AFTER poem (its "texture", the back
     dims). Shows how the structure-vs-texture balance tracks the seam.
  3. NEIGHBOURHOOD -- Jaccard overlap of the cross-cut image's top-K similar
     set with the BEFORE poem's top-K vs the AFTER poem's top-K. The
     user-facing question: whose *similar page* does the image land in? Top-K
     is a cliff, so this can flip more sharply than the smooth cosine.

Prefer running this over trusting a number written in a doc. Knobs below.

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## Inside (local to the file)

### `l2(v)`
(No comment above it in the source.)

### `dot(a, b)`
(No comment above it in the source.)

### `seam_blend(a, b, fr)`
(No comment above it in the source.)

### `weight_blend(a, b, fr)`
(No comment above it in the source.)

### `topk_set(q)`
(No comment above it in the source.)

### `jaccard(x, y)`
(No comment above it in the source.)
