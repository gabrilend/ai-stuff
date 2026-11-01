# 602 — three readings

## Current Behavior

Built 2026-11-01 (see What Happened), proven against fakes. Before,
the porch gave one reading from one door, and a single guess, however
constrained, carries a single perspective.

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

## What Happened

Built 2026-11-01 on branch `claude/602-three-readings`, on top of 601's
live door, so it hears both spaces (704) with no further change.

- **Asking.** `./porch --three "a sentence"` plans the readings
  (`src/061-readings.lua`: every door in `input/cluster` once; one door
  three times with seeds 1, 2 and 3; two doors share three) and asks
  them all at once, each reading in its own process
  (`src/062-three-readings.lua --one`), so a slow door holds up no one.
  `--count=N` asks for 1 to 4, never more processes than her limit.
- **Filming.** Each reading that passes is filmed through the one
  pipeline (`026-render-main`), shown at a whole fraction of its size
  when it is wider than 128 pixels (every Nth pixel; the score itself
  is unchanged). That is the whole thumbnail profile,
  `readings.THUMB_MOST`.
- **Looking.** `output/readings/SLUG/index.html`: the sentence, then
  each reading with its film, what the porch heard in plain lines, and
  its score behind a disclosure. A reading that didn't pass is dimmed,
  with the wall's words, or the door that didn't answer, and its draft.
  HTML and CSS only, in the gallery's look (`027-gallery.lua` now
  shares its `STYLE` and `escape`). It stands beside the readings
  rather than inside the generated gallery, since readings are runtime,
  like films in `output/`.
- **Picking.** `./porch --pick SLUG K [--name=NAME]` moves the score
  into `input/`, by rename from a partial, never over an existing
  score. Who heard it is appended to `input/porch-history.txt` rather
  than beside the cluster file, since `input/cluster` stays out of git
  and the history is worth keeping.
- **Proof.** `src/063-readings-test.lua`, 22 of 22, with fakes: one door
  that reads well, one that misspells every time, one that doesn't
  answer. By hand, against small fake llama.cpp servers: three doors
  (one good, one stubborn, one down), then one door with three seeds;
  both pages built, a pick landed, a second pick of the same name
  refused.

Still open:

- A door that accepts the connection and then never answers holds its
  reading until curl's limit (15 minutes); the other readings land
  meanwhile, and the page is written when the last one ends.
- The person answering a wrong reading in plain words (704) would fit
  here, as a fourth asking with their words beside the wall's.
