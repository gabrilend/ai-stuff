# 404 — Phase 4 demo: a gallery of comparisons

## Current behavior

Nothing exists. Needs `401`–`403`.

## Intended behavior

**Every fixture quantity drawn, in every kind, shown as a gallery.**

`issues/completed/demos/phase-4-demo` runs phase 3's analogies through
ComfyUI (using the cache, so a second run is near-instant), then opens an HTML
gallery in Firefox: the same quantity-by-kind table as phase 3, with each cell
now the picture and its sentence. A switch on each picture overlays the cell
layout from `401`, so the reader can see where each object was meant to go.

Above the gallery: pictures drawn versus served from the cache; seconds per
picture (median and slowest); and a column where the owner ticks whether the
picture shows the right number of things. That tally — exact, over, under, per
packing and per count range — is the evidence for the choice between area
prompts and pasted copies in `402`.

## Suggested implementation steps

1. The generator, using the host's modules directly.
2. The gallery page.
3. The demo script; check `run-phase-demo` lists and runs it. Without the
   ComfyUI server reachable, the script says so and stops.

## Related

needs `401`, `402`, `204`, `403`
