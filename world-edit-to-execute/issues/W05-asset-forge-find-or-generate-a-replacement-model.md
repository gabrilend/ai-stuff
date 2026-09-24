# Issue W05: Asset Forge — Find or Generate a Replacement Model

**Phase:** W - WoW Client Bridge
**Type:** Implementation (root)
**Priority:** Medium
**Dependencies:** W03 (model resolver, override packs), 604 (content-addressed storage)
**Unlocks:** W06, W07

---

## Current Behavior

Once W03 exists, every unit that is not in an override pack is drawn with a
proprietary WoW model. There is no way to replace one model at a time other
than making a model by hand and writing a pack manifest by hand.

## Intended Behavior

The owner points at any model in the game and asks for a replacement. The
forge offers two routes and keeps everything either route produces:

- **Search**: look up openly licensed models on the internet by text (the
  model's name and what uses it) and by image (a render of the current model).
  Candidate sites: Sketchfab (downloadable models, licence per model, needs an
  API token), Poly Pizza, Poly Haven, Objaverse. Licence, author and source URL
  travel with every file.
- **Generate**: render the current model from the front, optionally restyle
  that image, then send it to a ComfyUI server running an image-to-3D workflow
  (for example Hunyuan3D-2 or TRELLIS custom nodes). ComfyUI is driven through
  its HTTP API: submit a workflow, poll for completion, fetch the output mesh.

Candidates are fitted to the original's size and pivot, stored forever
(content-addressed), rated 1-5, and the best is installed into an override
pack, where W03's resolver finds it first. The full flow and its refusal rules
are in `docs/datapath-asset-forge.md`.

**Why borrowed Blizzard models are allowed, and when they stop being needed.**
They are not ours, so they stay in the owner's client folder. They fill the gap
until new models exist. Each replacement carries a **similarity score** against
the original it replaces (W05a), and the owner improves the artwork bit by bit
until the score passes a distinctness threshold. Only then does the model count
as replaced.

**Skeletons and animation come from models already in the game.** Image-to-3D
produces a static mesh with no skeleton. Doodads, buildings and weapons use it
directly. For anything that walks and swings, the owner picks an existing
skeleton plus its full animation set from a catalogue grouped by race or
monster type (W05b). The new mesh is bound to that skeleton by giving each new
vertex the bone weights of the nearest vertex of that set's model. The
borrowed animation sets are themselves Blizzard's and get replaced later,
like particle effects, textures and sounds (see the replacement order in the W
client's `docs/012-asset-replacement-and-provenance.md`).

**Every candidate records its lineage**: `derived` (made from a render of the
original, a restyle, or while looking at it) or `independent` (made from text
or concept art that never included the original). The score says how *far*
an asset is from the original. Lineage says whether it could be shown to be
*independent* of it. The transcripts will show which route each asset took.

## Sub-Issues

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| W05a | similarity-to-original-score | W03 | Scores how far a candidate model is from the Blizzard original, in shape and in look, and keeps each model's score history |
| W05d | clean-room-describe-build-check-loop | W05a, W03 | **The default route** (decided 2026-09-23): a describer who sees the original writes a specification; a builder who never sees it makes the replacement; a checker returns only measurements. Iterative size fitting ("is approximately as large"; if not, rescale, re-render the candidate, ask the builder to fix the imbalances). Lineage `independent` |
| W05e | body-structure-fit-and-body-plan-standards | W05d, W03 | Bind the skeleton to the new mesh, pose both alike, photograph, and judge per joint whether the body under the armour matches (vision model + measurements). Defines body plans: the shared dimensions future custom skeletons and animations will target |
| W05c | default-client-compatible-seal | W05a, W01 | Convert a replacement to the stock client's formats (M2 version 264 + `.skin`, BLP2 via the shared library's encoder), check the stock client's limits, then confirm it loads in the stock client using W04's rig. Passing assets get the seal on their asset card and in the pack manifest. Needs an M2 writer, which nothing provides yet |
| W05b | borrowed-skeleton-and-animation-sets | W01, W03 | A catalogue of existing skeleton + animation sets grouped by race or monster type; binding a new mesh to the chosen set |

Order: W05a and W05b in parallel; both before the fit, keep and install steps below.

## Suggested Implementation Steps

1. **Select**: in our engine, a debug key on the selected unit or doodad opens
   its asset card. In the WoW client, an addon command sends the target to the
   server; an ALE script looks up the display id → model path and writes a
   request file into a spool folder the forge watches.
2. **Asset card**: model path, display ids, every unit or item using it,
   current source, bounds, bone count.
3. **Search** adapters, one per site, behind one interface; each returns
   candidates with licence fields filled or is refused.
4. **Generate** adapter for ComfyUI: workflow files kept in the repo; each run
   records prompt, seed and workflow hash.
5. **Fit**: normalise scale and pivot. For animated models, the owner picks an
   animation set (W05b) and the weights are transferred onto it. Report the
   share of vertices whose nearest donor vertex is far away (a quality number).
6. **Score** (W05a): similarity to the original, stored with the candidate.
7. **Keep and rate**: store, show in a gallery page with the score beside
   each candidate, rate.
8. **Install** into an override pack (phase 6 format) with the licence and
   the similarity score in the manifest.
9. Converting to M2 so the *stock* client also shows the replacement is W05c
   (the seal). The W client doesn't need it: it reads pack formats directly.

## Acceptance Criteria

- [ ] A doodad (e.g. a tree) replaced by a searched CC0 model, visible in our engine
- [ ] A building replaced by a ComfyUI-generated model, with its provenance record
- [ ] One animated unit replaced on an owner-chosen animation set, walking without tearing (or the failure documented with its quality number)
- [ ] Every installed replacement shows its similarity score; replacement progress counts only models past the threshold
- [ ] Every stored candidate has licence or generation provenance; refusals are listed in a report

## Open Questions

1. Where does selection live first: in our engine (can see model paths directly; recommended) or as a WoW client addon (must ask the server)?
2. Where does ComfyUI run: this machine's GPU, or another host? Which image-to-3D nodes are already installed?
3. Is Sketchfab's API token something the owner wants the forge to use?

## Related Documents

- `docs/datapath-asset-forge.md`, `docs/wow-client-bridge.md`
- `issues/604-asset-deduplication-system.md`, `issues/605-local-storage-manager.md`
