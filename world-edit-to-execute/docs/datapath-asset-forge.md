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
      │      transfer onto the original skeleton (the hard step — see W05)
      ▼
 [5 keep]    every candidate stored forever, content-addressed, with provenance;
      │      rated 1-5 by a person, a model, or both
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
| 5 | Keep | fitted candidate | stored blob (SHA-256 name, phase 6 dedupe) + provenance record + ratings (list of {rater, 1-5, note}) |
| 6 | Install | chosen candidate | override pack entry: `unit type id → model file`, with licence carried into the pack manifest |

## Rules that are errors, not warnings

- A downloaded model with no licence, or a licence that forbids redistribution, is refused. It is not "used for now".
- A generated model without its prompt, seed and workflow hash is refused: it could never be regenerated or explained.
- A candidate for an animated unit that has no skeleton is refused for that unit (it may still be kept as a static doodad candidate).
