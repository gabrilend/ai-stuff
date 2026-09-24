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

**The hard part, stated plainly:** image-to-3D produces a static mesh with no
skeleton. Doodads, buildings and weapons can use it directly. Units that walk
and swing need their new mesh bound to a skeleton, most practically the
original model's skeleton, by giving each new vertex the bone weights of the
nearest original vertex. That works for similar silhouettes and fails for very
different ones. Static assets are therefore the first target.

## Suggested Implementation Steps

1. **Select**: in our engine, a debug key on the selected unit or doodad opens
   its asset card. In the WoW client, an addon command sends the target to the
   server; an Eluna script looks up the display id → model path and writes a
   request file into a spool folder the forge watches.
2. **Asset card**: model path, display ids, every unit or item using it,
   current source, bounds, bone count.
3. **Search** adapters, one per site, behind one interface; each returns
   candidates with licence fields filled or is refused.
4. **Generate** adapter for ComfyUI: workflow files kept in the repo; each run
   records prompt, seed and workflow hash.
5. **Fit**: normalise scale and pivot; for animated models, weight transfer
   onto the original skeleton; report the share of vertices whose nearest
   original vertex is far away (a quality number).
6. **Keep and rate**: store, show in a gallery page, rate.
7. **Install** into an override pack (phase 6 format) with the licence in the
   manifest.
8. Converting to M2 so the *WoW client* also shows the replacement needs an M2
   writer; that is a separate later step, not part of this issue.

## Acceptance Criteria

- [ ] A doodad (e.g. a tree) replaced by a searched CC0 model, visible in our engine
- [ ] A building replaced by a ComfyUI-generated model, with its provenance record
- [ ] One animated unit replaced through weight transfer, walking without tearing (or the failure documented with its quality number)
- [ ] Every stored candidate has licence or generation provenance; refusals are listed in a report

## Open Questions

1. Where does selection live first: in our engine (can see model paths directly; recommended) or as a WoW client addon (must ask the server)?
2. Where does ComfyUI run: this machine's GPU, or another host? Which image-to-3D nodes are already installed?
3. Is Sketchfab's API token something the owner wants the forge to use?

## Related Documents

- `docs/datapath-asset-forge.md`, `docs/wow-client-bridge.md`
- `issues/604-asset-deduplication-system.md`, `issues/605-local-storage-manager.md`
