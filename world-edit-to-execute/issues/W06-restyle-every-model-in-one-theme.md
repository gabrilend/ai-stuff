# Issue W06: Restyle Every Model in One Theme

**Phase:** W - WoW Client Bridge
**Type:** Implementation (later; large compute job)
**Priority:** Low (after W05 works on single models)
**Dependencies:** W05
**Unlocks:** W07

---

## Current Behavior

W05 (once built) replaces one model at a time, on request. There is no way to
say "remake everything in this style" and have it happen.

## Intended Behavior

A **style template** such as `neopunk` (a file holding prompt fragments,
negative prompts, a colour palette, reference images and a seed policy) is
applied to *every* model the game can show, producing a complete style pack:

- **Enumerate** every model from the WoW tables: creatures
  (`CreatureDisplayInfo`), equipment (`ItemDisplayInfo`, grouped by
  `ItemSet` so the pieces of one armour set are made together and share a
  palette), and world objects (`GameObjectDisplayInfo`), plus every WC3 unit
  type in the display table.
- **Queue** one forge job per model (W05's generate route with the template
  applied), resumable after a stop, skipping jobs whose output already exists
  (content-addressed, so re-runs cost nothing).
- **Batch on the GPU**: many jobs are submitted to ComfyUI's queue at once so
  the GPU never waits; CPU work around it (rendering reference views, fitting,
  scoring) runs on a thread pool.
- **Keep every candidate**, rate them (a vision model can pre-rate against the
  template's reference images; the owner has the final word), and install the
  best per model into the style pack.

The engine can then switch the whole game between the owner's client models,
the open pack, and `neopunk` with one setting.

## Suggested Implementation Steps

1. Style template format and two example templates (`neopunk`, and a plain
   "faithful" template that asks for the original look, as a control).
2. Enumerator with a count report per category. The size of the job comes from
   this tool, not from a number written into documents.
3. Job queue in RAM-backed `tmp/shared-memory/`, results in content-addressed
   storage, a progress page (done, running, failed, GPU hours).
4. Set grouping: equipment sets and creature families share a palette seed.
5. Pre-rating by a vision model; the owner's gallery for final choices.
6. Style pack export in the phase 6 format.

## Acceptance Criteria

- [ ] The enumerator reports how many models each category holds
- [ ] One full equipment set restyled consistently
- [ ] The queue survives a stop and resumes without redoing finished work
- [ ] A style pack switchable in the engine with one setting

## Open Questions

1. What does "neopunk" look like to the owner? A few reference images would define the template better than words.
2. Should animated units wait until W05's weight transfer is reliable, or be restyled as textures only (repaint the existing mesh) in the meantime?

## Related Documents

- `docs/datapath-asset-forge.md`
- `issues/W05-asset-forge-find-or-generate-a-replacement-model.md`
