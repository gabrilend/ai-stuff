# Phase 7: Gameplay - Core Mechanics — Progress

## Goals

From `docs/roadmap.md`, "Phase 7: Gameplay - Core Mechanics (Archived)":

The death system (701) and profession system (702) were archived on
2026-01-08 with the WoW-mode issues (`issues/archive/wow-mode-2026-01-08/`);
only the core profession component (702a) was completed first. Issues 703-707
were planned but never written. WC3 gameplay mechanics (combat, abilities,
buffs, training, fog of war) have no live issues; when they come back they
start from this list. The rest of this section is the record of the plan.

Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m`

## Issues

<!-- phase-progress-files: issues begin (generated; edits here are overwritten) -->

| ID | Title | Status | Depends on |
|----|-------|--------|------------|
| 701 | [Death and Resurrection System](./archive/wow-mode-2026-01-08/701-death-and-resurrection-system.md) | retired (archive/) | 402, 404, 308 |
| 701a | [Death State and Events](./archive/wow-mode-2026-01-08/701a-death-state-and-events.md) | retired (archive/) | 402, 308 |
| 701b | [Spirit World Layer](./archive/wow-mode-2026-01-08/701b-spirit-world-layer.md) | retired (archive/) | 701a, 402, 404 |
| 701c | [Ghost Form Component](./archive/wow-mode-2026-01-08/701c-ghost-form-component.md) | retired (archive/) | 701a, 701b |
| 701d | [Resurrection Mechanics](./archive/wow-mode-2026-01-08/701d-resurrection-mechanics.md) | retired (archive/) | 701a, 701c |
| 701e | [Corpse System](./archive/wow-mode-2026-01-08/701e-corpse-system.md) | retired (archive/) | 701a |
| 702a | [Core Profession Component and Skill System](./archive/wow-mode-2026-01-08/702a-core-profession-component.md) | retired (archive/) | 402, 406 |
| 702a | [Profession Core Component and Skill System](./completed/702a-profession-core-component.md) | completed | 402 |
| 702d | [Recipe and Schematic System](./archive/wow-mode-2026-01-08/702d-recipe-schematic-system.md) | retired (archive/) | 702a, 406 |
| 702e | [WoW-Mode Profession Configuration](./archive/wow-mode-2026-01-08/702e-wow-mode-configuration.md) | retired (archive/) | 702a, 702b, 702c, 702d |
| 702f | [WC3-Mode Profession Configuration](./archive/wow-mode-2026-01-08/702f-wc3-mode-configuration.md) | retired (archive/) | 702a, 702b, 702c, 702d |
| 702g | [Profession UI Abstraction Layer](./archive/wow-mode-2026-01-08/702g-profession-ui-abstraction.md) | retired (archive/) | 702a, 506 |

Completed 1, open 0, retired 11, as of the last run of `scripts/phase-progress-files.lua`.

<!-- phase-progress-files: issues end -->
