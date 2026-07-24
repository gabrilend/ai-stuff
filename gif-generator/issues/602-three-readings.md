# 602 — three readings

## Current Behavior

The translator (once built) produces one reading from one node; a
single guess, however constrained, carries a single perspective.

## Intended Behavior

Three perspectives, then taste. It is better to approach the same
prose from three angles and get three understandings than to refine
one understanding three times.

- The prose goes to every endpoint in `input/cluster` concurrently;
  one lone endpoint answers three times with three seeds instead.
  Node count and seed policy are configuration, not code.
- Each reading that passes the wall is rendered as a **thumbnail**:
  low resolution, ordinary pipeline, nothing bespoke — a small honest
  preview of the motion, cheap enough to make three of.
- A **pick page** (a viewing artifact, styled like the gallery, built
  by the same generator) shows the original prose beside the three
  looping thumbnails, each with its reading's scene text a click away.
  Readings that failed the wall appear too, dimmed, errors shown —
  a failed understanding is information, not embarrassment.
- Picking promotes that reading's scene file into `input/` as a
  first-class citizen and records which node's understanding won —
  over time the cluster file's affectionate names accumulate a little
  history of who hears best.
- Tests: fan-out against fake servers (three answers reassembled,
  one server down is a named report, not a hang); promotion is an
  atomic rename; the pick page builds from canned readings with no
  cluster present.

## Suggested Implementation Steps

1. Concurrent fan-out over the endpoints (the pipeline-of-snapshots
   habit again: independent work, reassembled by label).
2. Thumbnail render settings as one documented profile.
3. The pick page in the gallery generator.
4. Promotion, with the winner recorded beside the cluster file.
5. Tests as described.

## Blockers

- 601 (the translator being fanned out), 404 (the gallery generator
  that builds the pick page).

## Related Documents

- docs/datapath-prose-translation.md (three readings, the person picks)
- strategems/pipeline-of-snapshots (independent work, reassembled)
