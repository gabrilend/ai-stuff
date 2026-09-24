# Issue W05b: Borrowed Skeleton and Animation Sets

**Phase:** W - WoW Client Bridge
**Type:** Sub-issue of W05
**Priority:** High (every animated replacement needs one)
**Dependencies:** W01 (models and tables), W03 (animation playback)

---

## Current Behavior

A generated or downloaded mesh has no skeleton, so it cannot walk, attack or
die. Nothing lists which skeletons and animation sets the game already has.

## Intended Behavior

In the owner's words: "I think that will work best with all of the animations
already in the game. Let the user decide which animation set to give them -
group it by like, race I guess. Or monster type."

- **Catalogue**: every model with a skeleton, grouped by:
  - **race** for playable-race character models (from `ChrRaces.dbc` and the
    `Character\<Race>\<Gender>\` model folders), split by gender;
  - **monster type** for creatures (the creature type the server stores per
    creature template: beast, dragonkin, demon, elemental, giant, undead,
    humanoid, mechanical, critter), then by model family (all wolves, all
    gnolls, …).
- Each entry shows: bone count (uint), the animation names it has (list of
  strings, resolved through `AnimationData.dbc`), which WC3 animation names it
  can satisfy (W03's table), height (float, yards) and a looping preview.
- **Choice**: the owner picks an entry for a candidate mesh. The forge scales the
  mesh to the set's model, poses it to match the bind pose, and gives each new
  vertex up to 4 bone weights copied from the nearest vertices of the set's
  model.
- **Suggestion**: the catalogue ranks entries by how well the candidate's
  silhouette fits each skeleton's bind pose, so the likeliest match is at the
  top. The owner still decides.

## Suggested Implementation Steps

1. Enumerator over models with bones; grouping by race and by monster type.
   The monster type comes from the server's creature tables, joined to display
   ids.
2. Catalogue page (viewer) fed by a catalogue data file (generator).
3. Bind-pose alignment and nearest-vertex weight transfer.
4. Fit-quality number (share of vertices far from any donor vertex) shown
   beside the result.
5. Tests: transferring a model's own mesh onto its own skeleton reproduces its
   original weights; a humanoid mesh on a humanoid set walks without tearing.

## Acceptance Criteria

- [ ] The catalogue lists every skeleton, grouped by race and by monster type
- [ ] A candidate can be bound to a chosen set and plays Stand, Walk, Attack, Death
- [ ] The self-transfer test passes

## Open Questions

1. The animation sets are also Blizzard's. Once meshes are distinct, the motion still is not, and W05a only scores appearance. Should animations get their own score and replacement route later?
2. Monster type from the server's creature data, or the owner's own grouping (e.g. "big four-legged", "small flyer") when the server's types are too coarse?

## Related Documents

- `issues/W05-asset-forge-find-or-generate-a-replacement-model.md`
- `docs/datapath-wow-models-in-engine.md` (WC3 → WoW animation names)
