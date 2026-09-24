# Datapath: the asset forge

**Features:** W05 (find or generate a replacement for one model), W06 (restyle every model in one theme)
**Status:** Designed, not built. Update this file when W05 or W06 changes the flow.

---

## The whole path

```
 [1 select]  click a unit/doodad in our engine  ──or──  target it in the WoW client
      │            (model path known directly)            (addon → server → spool file)
      ▼
 [2 asset card]  model path, display id, every unit/item that uses it,
      │          current source (client / override), bounding box, bone count
      ▼
      ├──▶ [3a search]    text query (name + tags) and image query (a render of the
      │                   current model) against openly licensed model sites
      │                   → candidates with licence + author + URL
      │
      └──▶ [3b generate]  render front view → (optional) restyle the image with a
                          style template → ComfyUI image-to-3D workflow → GLB mesh
                          → candidates with prompt + seed + workflow hash
      ▼
 [4 fit]     scale and pivot to the original's bounding box; for animated models,
      │      the owner picks a skeleton + animation set from a catalogue grouped
      │      by race or monster type, and weights are copied from it (W05b)
      ▼
 [4½ score]  similarity to the Blizzard original: silhouette, surface shape,
      │      colour, image-embedding distance → one number 0 (same) … 1 (unrelated)
      │      (W05a); the model counts as replaced only past the threshold
      ▼
 [5 keep]    every candidate stored forever, content-addressed, with provenance
      │      and its score; rated 1-5 by a person, a model, or both.
      │      Low score → rework the art and go round again ("bit by bit")
      ▼
 [6 install] best-rated candidate written into an override pack (phase 6 format)
             → the model resolver (W03) now finds it first
```

W06 is the same path with stage 1 replaced by "enumerate every model" and a
style template applied at 3b, run as a GPU batch queue.

## Stages

| # | Stage | Input (type) | Output (type) |
|---|-------|--------------|---------------|
| 1 | Select | a click (engine) or a target GUID (WoW client, uint64) | request record: model path (string), requested by, time |
| 2 | Asset card | request record | card: path, display ids (uint32 list), users (list of unit/item names), source tag, bounds (6 floats), bone count (uint), is_animated (bool) |
| 3a | Search | card, source list | candidates: url, title, author, licence (SPDX-style string, e.g. `CC0-1.0`, `CC-BY-4.0`), file format, thumbnail |
| 3b | Generate | card, optional style template, ComfyUI address | candidates: GLB file, prompt (string), seed (uint64), workflow file hash (SHA-256), GPU seconds (float) |
| 4 | Fit | candidate mesh, original model | fitted mesh; for animated units, bone weights (4 × uint8 per vertex) on the original skeleton |
| 4½ | Score | fitted candidate, original model, weights file | score record: silhouette, shape, colour, embedding parts (floats 0-1), combined (float 0-1), weights hash, camera ring version |
| 5 | Keep | fitted candidate + score record | stored blob (SHA-256 name, phase 6 dedupe) + provenance record + ratings (list of {rater, 1-5, note}) |
| 6 | Install | chosen candidate | override pack entry: `unit type id → model file`, with licence, lineage (`derived`/`independent`), latest score and seal flag carried into the pack manifest (the format the W client's resolver reads) |
| 7 | Seal (optional) | installed candidate | stock-format files (M2 + BLP2), limit checks, stock-client load check → "default client compatible" flag (W05c) |

## Rules that are errors, not warnings

- A downloaded model with no licence, or a licence that forbids redistribution, is refused. It is not "used for now".
- A generated model without its prompt, seed and workflow hash is refused: it could never be regenerated or explained.
- A candidate for an animated unit that has not been bound to a chosen animation set is refused for that unit (it may still be kept as a static doodad candidate).
- A candidate without a score record is refused at install time.

## Why the score exists

Blizzard's models are used because they are there and there are not yet
enough of our own. They are not ours, so each one is a placeholder with a way
out. The score measures how far each replacement has moved from the original,
and the art is reworked until it passes the threshold. It measures distance.
It is not a legal test of derivative work (see W05a).
