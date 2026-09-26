# Phase 1: Foundation - File Format Parsing — Progress

## Goals

From `docs/roadmap.md`, "Phase 1: Foundation - File Format Parsing (In Progress)":

The map file formats are read. Still open: the stock object tables and
their game-version layers (112, 112b, 112d, 112e), and the readers for WC3
models and textures (116, 117). Phase numbers group functionality rather
than mark time, so a foundation phase gaining new readers late is expected.

Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m`

## Issues

<!-- phase-progress-files: issues begin (generated; edits here are overwritten) -->

| ID | Title | Status | Depends on |
|----|-------|--------|------------|
| 101 | [Research WC3 File Formats](./completed/101-research-wc3-file-formats.md) | completed | — |
| 102 | [Implement MPQ Archive Parser](./completed/102-implement-mpq-archive-parser.md) | completed | 101 |
| 102a | [Parse MPQ Header Structure](./completed/102a-parse-mpq-header.md) | completed | 101 |
| 102b | [Parse MPQ Hash Table](./completed/102b-parse-mpq-hash-table.md) | completed | 102a |
| 102c | [Parse MPQ Block Table](./completed/102c-parse-mpq-block-table.md) | completed | 102a, 102b |
| 102d | [Implement File Extraction with Decompression](./completed/102d-implement-file-extraction.md) | completed | 102a, 102b, 102c |
| 103 | [Parse war3map.w3i (Map Info)](./completed/103-parse-war3map-w3i.md) | completed | 102 |
| 104 | [Parse war3map.wts (Trigger Strings)](./completed/104-parse-war3map-wts.md) | completed | 102 |
| 105 | [Parse war3map.w3e (Terrain Data)](./completed/105-parse-war3map-w3e.md) | completed | 102, 103 |
| 106 | [Design Internal Data Structures](./completed/106-design-internal-data-structures.md) | completed | 103, 104, 105 |
| 107 | [Build CLI Metadata Dump Tool](./completed/107-build-cli-metadata-dump-tool.md) | completed | 106 |
| 108 | [Phase 1 Integration Test and Demo](./completed/108-phase-1-integration-test.md) | completed | 101, 107 |
| 109 | [Implement PKWARE DCL Decompression](./completed/109-implement-pkware-dcl-decompression.md) | completed | 102d |
| 110 | [Object Data Parsers](./completed/110-object-data-parsers.md) | completed | 102 |
| 110a | [Core Object Data Parser](./completed/110a-core-object-parser.md) | completed | — |
| 111 | [Cross-Reference Validation](./completed/111-cross-reference-validation.md) | completed | 110, 202, 201 |
| 112 | [Stock Object Tables, Read Two Ways and Cross-Checked](./112-stock-object-tables-by-two-routes.md) | open | — |
| 112a | [StormLib, Built From Source by the Dependency Script](./completed/112a-stormlib-build-and-update-script.md) | completed | 113 |
| 112b | [Game-Version Layers, Chosen Per Map](./112b-game-version-layers-per-map.md) | open | 112a |
| 112c | [Route A, Stock Rows Merged With a Map's Objects](./completed/112c-route-a-stock-rows-merged-with-map-objects.md) | completed | 112b |
| 112d | [Older Patch Program Shapes (1.01 to 1.20e)](./112d-older-patch-program-shapes.md) | open | 112b |
| 112e | [Route B, Published Values as a Cross-Check](./112e-route-b-published-values-cross-check.md) | open | 112c, 112b, 29 |
| 113 | [The Remaining MPQ Compression Methods](./completed/113-remaining-mpq-compressions.md) | completed | — |
| 114 | [Read Maps Through StormLib](./completed/114-read-maps-through-stormlib.md) | completed | 112a, 113 |
| 115 | [Balance History Explorer](./completed/115-balance-history-explorer.md) | completed | 112b, 112d, 112c |
| 115a | [What Each Patch Changed](./completed/115a-what-each-patch-changed.md) | completed | 115 |
| 115b | [Patch Notes for the Versions We Don't Read](./completed/115b-notes-for-versions-we-dont-read.md) | completed | 115a |
| 116 | [Read WC3 Models (.mdx)](./116-read-wc3-models.md) | open | — |
| 117 | [Read WC3 Textures (BLP1)](./117-read-wc3-textures.md) | open | W01 |

Completed 23, open 6, retired 0, as of the last run of `scripts/phase-progress-files.lua`.

<!-- phase-progress-files: issues end -->
