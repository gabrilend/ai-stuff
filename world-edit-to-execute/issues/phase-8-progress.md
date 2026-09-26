# Phase 8: Multiplayer - Matchmaking & Networking — Progress

## Goals

From `docs/roadmap.md`, "Phase 8: Multiplayer - Matchmaking & Networking (Issues Created)":

9 issues created. Matchmaking server with lobby system, NAT traversal, and asset distribution.

Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m`

## Issues

<!-- phase-progress-files: issues begin (generated; edits here are overwritten) -->

| ID | Title | Status | Depends on |
|----|-------|--------|------------|
| 801 | [Matchmaking Server](./801-matchmaking-server.md) | open | — |
| 801a | [Matchmaking Protocol Specification](./801a-protocol-specification.md) | open | 801 |
| 801b | [Matchmaking Server Core](./801b-server-core.md) | open | 801a |
| 801c | [Matchmaking Client Library](./801c-client-library.md) | open | 801a, 801b |
| 801d | [NAT Traversal System](./801d-nat-traversal.md) | open | 801a, 801b |
| 801e | [Lobby UI](./801e-lobby-ui.md) | open | 801c |
| 801f | [Asset Mirror Integration](./801f-asset-mirror.md) | open | 801b, 2026, 09, 26, 609 |
| 801g | [CLI Server Application](./801g-cli-server-application.md) | open | 801b, 801f |
| 801h | [Matchmaking Integration Tests](./801h-integration-tests.md) | open | 801a, 801b, 801c, 801d, 801e, 801f, 801g, 2026, 09, 26 |
| 802 | [Render System Migration to Threadpool Library](./802-render-threadpool-migration.md) | open | 800a, 800b, 800c, 800d |
| 803 | [Gameplay Messages, with the Server Inside the Client](./803-gameplay-messages-server-inside-the-client.md) | open | 401, 515c |
| 804 | [Crossing Armies, Drawn From Across the Network](./804-crossing-armies-over-the-network.md) | open | 405f, 803, 515c |

Completed 0, open 12, retired 0, as of the last run of `scripts/phase-progress-files.lua`.

<!-- phase-progress-files: issues end -->
