# Datapath: WoW models shown by our engine, behaving like WC3 units

**Features:** W01 (read the WoW client's archives), W03 (show WoW models with WC3 unit behavior)
**Status:** Designed, not built. Update this file when W01 or W03 changes the flow.

---

## The whole path

```
 WC3 unit type id ("hfoo")                         (from the map, phases 1-2)
        │
        ▼
 [1 model resolver]  asks, in order:
        │   a. override pack (community or forge-made model)   ── open, shippable
        │   b. the owner's WoW client, via the display map     ── proprietary, local only
        │   c. wireframe placeholder (issue 602)               ── always available
        │   every step past (a) is counted; (c) is a warning, an error in strict mode
        ▼
 [2 WoW archive chain]  (W01)  common.MPQ … patch-3.MPQ, locale, patch-W.MPQ
        │   reads: CreatureDisplayInfo.dbc → CreatureModelData.dbc → model path
        │          AnimationData.dbc (animation id ↔ name)
        ▼
 [3 model loader]  .m2 (+ .skin, + external .anim) + .blp textures
        │   → mesh, bones, animation sequences, attachment points, cameras
        ▼
 [4 behaviour layer]  WC3 animation state machine
        │   game state per tick (moving, attacking, casting, dead, decaying)
        │   → "which WoW sequence, at what time and speed"
        ▼
 [5 draw list]  one entry per visible unit per frame
        ▼
 [6 renderer]  raylib (src/render/): skinning, team colour, selection circle
```

## Stages

| # | Stage | Input (type) | Output (type) | Issue |
|---|-------|--------------|---------------|-------|
| 1 | Resolve | unit type id (4-char string) | model reference: source tag (`override`/`client`/`placeholder`), path (string) | W03a |
| 2 | Archive chain | ordered list of MPQ paths | a file lookup: path (string, backslashes, case-insensitive) → bytes; later archives win | W01a |
| 2 | Tables | DBC bytes: header `WDBC`, then record count, field count, record size, string block size (4 × uint32), fixed-size records, string block | table of rows keyed by id (uint32); strings resolved from the string block | W01b |
| 3 | Textures | BLP2 bytes: palettized (256-colour + alpha) or DXT1/3/5 compressed, with mipmaps | RGBA8 image or compressed GPU upload | W01c |
| 3 | Models | M2 bytes (magic `MD20`, version 264 in 3.3.5a) + `<name>00.skin` (vertex lists per level of detail) | vertices (position, normal, 2 UV, 4 bone indices uint8 + 4 weights uint8), bones (parent, pivot, keyframed translation/rotation/scale per sequence), sequences (animation id uint16, variation, duration ms uint32, move speed float), attachments (id, bone, offset), texture slots (hard-coded path or replaceable type) | W01d |
| 4 | Behaviour | per-tick unit state + WC3 unit data (walk speed, attack damage point, backswing, model scale, selection scale) | chosen sequence index, playback time (ms), playback rate (float) | W03b |
| 5 | Draw list | all of the above | per unit: model handle, bone matrices, team colour (RGB), selection ring radius | W03c |
| 6 | Render | draw list | pixels | W03c (on top of phase 5) |

## WC3 animation names → WoW sequences

WC3 picks animations by **name** ("Stand", "Walk", "Attack", "Spell",
"Death", "Decay", plus tags like "Alternate", "Slam", "Throw", and a random pick
among variations weighted by rarity). WoW M2 files store animations by
**number**; the numbers' names are listed in `AnimationData.dbc`. The
translation table is kept as data (`name → list of WoW animation names`),
resolved to numbers through `AnimationData.dbc` at load time, never
hard-coded:

| WC3 name | WoW animation name(s), first found wins |
|----------|------------------------------------------|
| Stand | Stand |
| Walk | Walk, Run |
| Attack | Attack1H, Attack2H, AttackUnarmed |
| Spell | SpellCastDirected, SpellCastOmni, SpellCast |
| Death | Death |
| (corpse) | Dead |
| Decay | none in WoW: the corpse sinks into the ground and fades (engine-side) |
| Portrait | the M2's portrait camera (camera type 0) aimed at the Stand sequence |

## Timing rules taken from WC3 (the part that makes it "behave like WC3")

| Behaviour | WC3 rule | How we apply it to a WoW model |
|-----------|----------|--------------------------------|
| Walk speed | The walk animation plays at `unit speed / animation base speed` so feet do not slide | WoW sequences carry a move speed (yards/s); rate = converted unit speed / that |
| Attack timing | Damage lands at the unit's *damage point* (seconds into the swing); *backswing* follows | Stretch the WoW attack sequence so its midpoint lands on the damage point |
| Death | Death plays once, corpse stays, then "Decay Flesh", "Decay Bone", then removal | Death once → Dead held → sink + fade on the WC3 decay timers |
| Team colour | Replaceable texture 1 (team colour) and 2 (team glow) | WoW has no team-colour slot; tint the model's cape/banner area by a mask, or add a ground ring + glow. Open question in W03 |
| Scale | `modelScale` and `selectionScale` per unit type | Model scale × a per-model normalisation so a footman-class unit matches WC3 bounds |

## Statistics this path produces

- Share of units drawn from each source (override / client / placeholder): the "replacement progress" number the demos show.
- Count of WC3 animation names with no WoW match, per model.
- Frame time for skinning N units (N = 100, 500, 1000).
