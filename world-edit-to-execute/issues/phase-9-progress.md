# Phase 9: World Editor — Progress

## Goals

From `docs/roadmap.md`, "Phase 9: World Editor (Issues Created)":

12 issues created. Full-featured map editor with WC3 World Editor parity.

Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m`

## Issues

<!-- phase-progress-files: issues begin (generated; edits here are overwritten) -->

| ID | Title | Status | Depends on |
|----|-------|--------|------------|
| 901 | [Editor Core Framework](./completed/901-editor-core-framework.md) | completed | — |
| 901a | [The Editor Draws Models and Textures](./completed/901a-editor-draws-models-and-textures.md) | completed | 522, 523, 526 |
| 902 | [Terrain Editor](./902-terrain-editor.md) | open | 901, 105 |
| 903 | [Object Placer](./903-object-placer.md) | open | 901, 110 |
| 904 | [Region and Camera Editor](./904-region-camera-editor.md) | open | 901, 203, 204 |
| 904b | [Cameras, and New Regions for the Triggers](./completed/904b-cameras-and-new-regions.md) | completed | 904, 905a |
| 905 | [Trigger Editor](./905-trigger-editor.md) | open | 901 |
| 905a | [Trigger Editor — Blocks Written as JASS, and the Map's Own Triggers](./completed/905a-trigger-editor-blocks-and-map-triggers.md) | completed | 901, 911a, 520 |
| 905b | [Triggers as Lua — the Code View That Edits](./completed/905b-triggers-as-lua.md) | completed | 905a |
| 906 | [Object Editor](./906-object-editor.md) | open | 901, 110 |
| 907 | [Sound Editor](./907-sound-editor.md) | open | 901, 205 |
| 907a | [Sound Editor — the Script's Sounds and Music, New Sounds for Triggers](./completed/907a-sound-editor-script-sounds.md) | completed | 901, 905a, 908a |
| 907b | [The Game Heard — Sounds and Music Through the Window's Audio](./completed/907b-the-game-heard.md) | completed | 907a |
| 908 | [Import Manager](./908-import-manager.md) | open | 901 |
| 908a | [Import Manager — the Map's Files Named, Checked, Imported, Renamed, Deleted](./completed/908a-import-manager-names-files-and-changes.md) | completed | 901, 911a |
| 909 | [AI Editor](./909-ai-editor.md) | open | 901 |
| 909a | [AI Editor — The Computer Players' Profiles, Edited and Saved into the Map](./completed/909a-ai-editor-profiles-in-the-map.md) | completed | 901, 521, 540 |
| 910 | [Campaign Editor](./910-campaign-editor.md) | open | 901, 911 |
| 911 | [Map Format and Export](./911-map-format-export.md) | open | 901 |
| 911a | [Writing Maps Back](./completed/911a-writing-maps-back.md) | completed | 114 |
| 911b | [New Maps from Scratch](./completed/911b-new-maps-from-scratch.md) | completed | 911a, 901 |
| 911c | [Map Projects — the Unified Format as a Folder (and a .wex)](./completed/911c-map-projects-unified-format.md) | completed | 911a, 911b, 908a |
| 912 | [Phase 9 Integration Test](./912-phase9-integration-test.md) | open | 901, 911 |
| 912a | [The Editor's Integration Test](./completed/912a-editor-integration-test.md) | completed | 901, 909, 911a, 911b |

Completed 13, open 11, retired 0, as of the last run of `scripts/phase-progress-files.lua`.

<!-- phase-progress-files: issues end -->
