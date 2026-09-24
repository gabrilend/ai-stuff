# Issue W03: Show WoW Models with WC3 Unit Behavior

**Phase:** W - WoW Client Bridge
**Type:** Implementation (root; expected to split into W03a-W03d)
**Priority:** High
**Dependencies:** W01, 508 (vertical slice renderer), 601 (asset loader), 602 (wireframe fallback)
**Unlocks:** W04, W05, W07

---

> **W client merge (2026-09-23).** The W client (formerly custom-client)
> will also show WoW models with WC3 behaviour, in its issue 407 and Phase 11.
> To avoid two versions of the rules, the WC3 behaviour rules (the animation
> name table and the timing rules in `docs/datapath-wow-models-in-engine.md`)
> are kept as a **data file** that both programs read. The M2 reader comes
> from the W client's shared library (W01). Whether this project's own
> renderer keeps drawing WoW models at all, or hands that job entirely to the
> W client, depends on open question 4 below.

## Current Behavior

Our engine (phase 5, `src/render/`) draws terrain and units as placeholder
shapes through raylib, driven by the phase 4 simulation (62.5 ticks/s). Units
have positions, facing and orders, but no animation state and no real models.
The asset loader (601) and wireframe fallback (602) are designed, not built.

## Intended Behavior

Our engine loads models from the owner's WoW 3.3.5a client and shows them
**acting like WC3 units**: a footman-class unit stands idle, walks with feet
matched to its speed, swings so the hit lands at WC3's damage point, dies,
lies as a corpse, and decays on WC3's timers. It has a team colour, a
selection circle and a portrait. The player controls it exactly as in the
WC3 client: select, right-click to move, attack-move, hotkeys.

This is the "harness" between the player's control and the client's output
(see `docs/wow-client-bridge.md`): input → orders → simulation → animation
choice → draw list → frame. Every link is recordable, so W04 can compare our
frames with the real WoW client's frames for the same moment.

Proprietary models are only a middle step. A model resolver asks three places
in order: an override pack (open or forge-made models), then the owner's WoW
client, then the wireframe placeholder. Each model can be replaced
individually, and the share of units drawn from each place is shown as a
statistic (the "replacement progress").

Full detail, including the WC3 → WoW animation table and the timing rules,
is in `docs/datapath-wow-models-in-engine.md`.

## Suggested Implementation Steps

| ID | Name | Dependencies | Description |
|----|------|--------------|-------------|
| W03a | model-resolver-chain | W01, 601 | Override pack → WoW client (via a WC3 unit type → display id table, kept as data) → placeholder. Counts per source. Any use of the placeholder is a warning; a strict flag makes it an error |
| W03b | wc3-animation-state-machine | W03a | Per unit per tick: state (idle, moving, attacking, casting, dead, decaying) → WC3 animation name → WoW sequence (by name through `AnimationData.dbc`) → playback time and rate from WC3 rules (walk speed, damage point, backswing, decay timers). Random variation choice uses the simulation's seeded random source so replays match |
| W03c | skinned-model-rendering | W03a, 508 | GPU skinning of M2 meshes (4 bones per vertex), BLP textures, team colour, selection circle, model and selection scale from WC3 unit data, attachment points (overhead, origin, hands) for effects and health bars |
| W03d | input-recording-and-replay | W03b | Record the input stream per tick and replay it to get the same frames; the entry point W04 uses |

Order: `W03a → W03b → W03c`, `W03d` after `W03b`.

## Acceptance Criteria

- [ ] A WC3 map loads with WoW models for every unit type in the display table; others show as wireframes and are counted
- [ ] Idle, walk, attack, spell, death, corpse and decay play on WC3 timing
- [ ] Walking shows no visible foot sliding at the unit's WC3 speed
- [ ] Two replays of the same input recording produce identical draw lists
- [ ] The replacement-progress numbers (override / client / placeholder) are printed per map
- [ ] 500 animated units hold 60 fps on the development machine (or the measured limit is recorded)

## Open Questions

1. **Team colour**: WoW models have no team-colour texture slot. Options: (a) tint by a per-model mask made once per model; (b) a coloured ground ring and glow only; (c) both. Which does the owner want WC3's look to rely on?
2. **"Mimic exactly"**: should our engine mimic how *WC3* would behave (the plan above), or how the *WoW client* animates these models (idle fidgets, emotes)? They conflict in places; WC3 is assumed.
3. ~~Should the custom-client project reuse W03c's skinning code?~~ Superseded by the merge: skinning is built once, in the W client (its issues 403-404).
4. Does this project's renderer (`src/render/`) remain a second place WoW models are drawn (useful for W04's comparisons and for the engine's own WC3 play), or does the W client become the only renderer for WoW models, leaving `src/render/` to the asset-free engine?

## Related Documents

- `docs/datapath-wow-models-in-engine.md`, `docs/wow-client-bridge.md`
- `docs/render-architecture.md` (threading, component slots)
- `issues/601-asset-loader-resolution.md`, `issues/602-wireframe-fallback-renderer.md`
