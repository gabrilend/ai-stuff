# Phase W — WoW Client Bridge — Progress

The goal of phase W is to use the owner's World of Warcraft 3.3.5a client in
three roles (alternate host for WC3 maps, source of models, reference to test
against) and then to replace its proprietary models one at a time. Design:
`docs/wow-client-bridge.md`.

Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m`

## Issues

| ID | Title | Status | Blocked by |
|----|-------|--------|------------|
| W01 | [Read the WoW client's archives](./W01-read-the-wow-client-archives.md) | open | — |
| W02 | [Build WC3 maps into the WoW client](./W02-build-wc3-maps-into-the-wow-client.md) | open | W01 |
| W02a | [Terrain to ADT writer](./W02a-terrain-to-adt-writer.md) | built 2026-11-04; open: texture paths and Noggit to check on the owner's machine | W01 (checking only) |
| W02b | [Doodads and units to placements](./W02b-doodads-and-units-to-placements.md) | built 2026-11-04; open: model paths, the SQL on AzerothCore and the stock client to check on the owner's machine | W02a |
| W02c | [Map registration and output forms](./W02c-map-registration-and-output-forms.md) | built 2026-11-04; open: table layouts, the stock client, the SQL on AzerothCore to check on the owner's machine; the W client's side (custom-client) | W02a, W02b |
| W02e | [Triggers on the server](./W02e-triggers-on-the-server.md) | steps 1-2 of 8 built 2026-11-04/05 (coverage report, the shim's skeleton, 574 natives on a fake ALE: 95.5% of call sites over the 19 maps, was 58.9%; templates for types only the script makes); open: ALE's API to check on the owner's machine, the server's loader, steps 3-8 | W02b, W02c |
| W02f | [Launcher and loader](./W02f-launcher-and-loader.md) | steps 1-2 of 5 built 2026-11-05 (the server's stamp, by which Test Map reuses the server; the install plan as data, `install-plan.lua`, with the shim copied into the build); open: running the install on AzerothCore, the stock client, the character at the start | W02c, W02d |
| W02i | [A converted map's own light](./W02i-a-converted-maps-own-light.md) | built 2026-11-05 (the stock client and AzerothCore's side on the owner's machine open) | W02c, the W client's light through its tables (custom-client #26) |
| W03 | [Show WoW models with WC3 unit behavior](./W03-show-wow-models-with-wc3-unit-behavior.md) | open | W01, 508, 601, 602 |
| W04 | [Compare the real client against the open client](./W04-compare-the-real-client-against-the-open-client.md) | open | W02, W03 |
| W05 | [Asset forge: find or generate a replacement model](./W05-asset-forge-find-or-generate-a-replacement-model.md) | open | W03, 604 |
| W05a | [Similarity-to-original score](./W05a-similarity-to-original-score.md) | open | W03 |
| W05b | [Borrowed skeleton and animation sets](./W05b-borrowed-skeleton-and-animation-sets.md) | open | W01, W03 |
| W05d | [Clean-room loop: describe, build, check](./W05d-clean-room-describe-build-check-loop.md) | open | W05a, W03 |
| W05e | [Body-structure fit and body-plan standards](./W05e-body-structure-fit-and-body-plan-standards.md) | open | W05d, W03 |
| W05c | ["Default client compatible" seal](./W05c-default-client-compatible-seal.md) | open | W05a, W01, W04 |
| W08 | [Our own server, speaking the same protocol](./W08-our-own-server-speaking-the-same-protocol.md) | design research | W02, W04 |
| W06 | [Restyle every model in one theme](./W06-restyle-every-model-in-one-theme.md) | open (later) | W05 |
| W07 | [Phase W demo](./W07-phase-w-demo.md) | open | W02-W06 |
| W10 | [The editor edits WoW maps](./W10-the-editor-edits-wow-maps.md) | open; W10a, W10b, W10c, W10d, W10e, W10f built 2026-11-05 | W01, W02, Phase 9 |
| W10a | [The WoW layer of a map](./W10a-the-wow-layer-of-a-map.md) | built 2026-11-05 (drawing it in the window open) | W10, 911c |
| W10b | [The terrain editor on WoW tiles](./W10b-the-terrain-editor-on-wow-tiles.md) | built 2026-11-05 (the window, the WDL, water, new tiles and a stock tile on the owner's machine open) | W10a, W02a, 902 |
| W10c | [The far view and water on WoW tiles](./W10c-far-view-and-water-on-wow-tiles.md) | built 2026-11-05 (stock files and the far-hole rule on the owner's machine open) | W10b, W02a |
| W10d | [Tiles from the WDT, added and taken off](./W10d-tiles-from-the-wdt-added-and-taken-off.md) | built 2026-11-05 (a stock map's new tile and flowing water on the owner's machine open) | W10c, the W client's 098-wdt.c |
| W10e | [The object placer on WoW tiles](./W10e-the-object-placer-on-wow-tiles.md) | built 2026-11-05 (the stock client and Noggit showing placed objects on the owner's machine open) | W10d, W10b, W02b, the W client's adt_place_read |
| W10f | [Areas and doodad sets on WoW tiles](./W10f-areas-and-doodad-sets-on-wow-tiles.md) | built 2026-11-05 (zone names in the stock client, the server's extractor and AreaTable rows open) | W10e, W10d, the W client's 016-dbc |

## Built elsewhere

Since 2026-09-23 the W client (`/mnt/mtwo/games/azeroth-core/custom-client/`)
builds the shared reading layer (its issues 104-107), the model renderer
(its Phase 4) and WC3 map mode controls (its Phase 11). W01 and W02g here
track this project's side of those.

## Suggested order

W01 → (W02 ∥ W03) → (W04 ∥ W05) → W06 → W07

W02 and W03 can proceed in parallel once W01 reads the client. W03 also waits
on the phase 5 vertical slice (508) and the phase 6 asset loader (601, 602).

## Open questions blocking the start

Collected in `docs/wow-client-bridge.md` under "Open questions"; the first two
(mission boundary, one reader or two) decide how W01 is built.
