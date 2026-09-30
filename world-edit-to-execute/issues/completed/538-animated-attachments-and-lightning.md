# Issue 538: Attachment Points That Follow the Animation, and Lightning

**Phase:** 7 (gameplay)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 523 (animation), 530 (spell art)

---

## Current Behavior

- **Attachments:** effects attached to a unit ("hand right", "overhead", ...) sit at the attachment's rest place in the model, rotated with the unit. They don't move with the animation: a sword swing leaves the hand's effect behind.
- **Lightning:** it isn't drawn or kept.
  - **Abilities:** the lightning field (alig) of abilities is read but never used. DAoW sets it on 30-odd of its abilities (AFOD, LEAS, MBUR, HWSB ...).
  - **The script:** AddLightning, MoveLightning and DestroyLightning are no-ops, and AddLightningEx, the colour natives and the BJ forms don't exist.

## Intended Behavior

- **Attachments:** each pose also records where the model's attachment points are (the node's posed matrix applied to its pivot). An effect attached to a unit goes where the unit's current animation has that point, scaled and turned with the unit. It falls back to the rest place when there's no rig or pose.
- **Lightning:** bolts between two units or points, of a type by code.
  - **Types:** colour, width and segment length come from the install's Splats\LightningData.slk, else from stand-ins.
  - **Lifetime:** a bolt lasts for its time, or while its spell channels, or until destroyed. Its ends follow its units.
  - **Abilities:** a spell with a lightning shows it from the caster to the target when it happens: a moment, or for as long as it channels.
  - **The script:** AddLightning (at the ground), AddLightningEx (heights), MoveLightning(Ex), DestroyLightning, Get/SetLightningColor*, and the BJ forms with bj_lastCreatedLightning.
  - **Viewer:** draws a bolt as a jagged strip of crossed ribbons in its colour, re-bent every tenth of a second.

## Suggested Implementation Steps

1. `anim.lua`: mark attachment nodes; record their posed points per cached pose; `anim.attachment(rig, st, id)`.
2. `draw_effects.lua`: `attach_offset` takes the unit's rig; `draw_effects.bolt`; drawing `g.lightnings`.
3. `effects.lua`: lightning types, `add_lightning`, `move_lightning`, `destroy_lightning`, `lightning_ends`, the update. `abilities.land` adds a spell's lightning.
4. `natives/art.lua`: the lightning natives; they come off interface.lua's no-op list.
5. `main.lua`: `unit_model` returns the rig; scripted action `lightning:CODE` (from the selected unit to the nearest) or `lightning:CODE:x1,y1,x2,y2`.
6. Tests.

## Acceptance Criteria

- [x] A made-up arm turning a quarter carries its hand's attachment with it, from fresh and cached poses; effects follow, scaled and turned
- [x] Lightning types, bolts between units and points, timed, channelled and destroyed; a spell's alig bolt
- [x] The script's lightning natives, not no-ops
- [x] Bolts drawn in the viewer (checked headless on DAoW: chain lightning, healing wave and finger of death bolts over the ground)
- [x] Tests: test_lightning (33); test_effects, test_anim, test_abilities, test_wc3_interface still pass

## Notes

- **Stand-ins:** the lightning colours are from memory until the install's table is read.
- **Bolt drawing:** bolts are drawn untextured, without the stock bolt textures.
- **Bolt quads** are wound like the other figures' quads (culled from below); the upright ribbon goes both ways.
