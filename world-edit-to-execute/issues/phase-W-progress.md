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
| W03 | [Show WoW models with WC3 unit behavior](./W03-show-wow-models-with-wc3-unit-behavior.md) | open | W01, 508, 601, 602 |
| W04 | [Compare the real client against the open client](./W04-compare-the-real-client-against-the-open-client.md) | open | W02, W03 |
| W05 | [Asset forge: find or generate a replacement model](./W05-asset-forge-find-or-generate-a-replacement-model.md) | open | W03, 604 |
| W06 | [Restyle every model in one theme](./W06-restyle-every-model-in-one-theme.md) | open (later) | W05 |
| W07 | [Phase W demo](./W07-phase-w-demo.md) | open | W02-W06 |

## Suggested order

W01 → (W02 ∥ W03) → (W04 ∥ W05) → W06 → W07

W02 and W03 can proceed in parallel once W01 reads the client. W03 also waits
on the phase 5 vertical slice (508) and the phase 6 asset loader (601, 602).

## Open questions blocking the start

Collected in `docs/wow-client-bridge.md` under "Open questions"; the first two
(mission boundary, one reader or two) decide how W01 is built.
