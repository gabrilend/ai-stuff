# Phase 5: Rendering - Visual Abstraction — Progress

## Goals

From `docs/roadmap.md`, "Phase 5: Rendering - Visual Abstraction (In Progress)":

Decisions and open questions: `issues/CRITICAL-PATH.md`. Counts: the
dashboard command under Current Focus.

Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m`

## Issues

<!-- phase-progress-files: issues begin (generated; edits here are overwritten) -->

| ID | Title | Status | Depends on |
|----|-------|--------|------------|
| 500 | [Dual Interface Rendering Considerations](./archive/wow-mode-2026-01-08/500-dual-interface-rendering-considerations.md) | retired (archive/) | — |
| 501 | [Create Abstract Render Interface](./501-create-abstract-render-interface.md) | open | 508, 515 |
| 501a | [Define Renderer Interface](./superseded/501a-define-renderer-interface.md) | retired (superseded/) | — |
| 501b | [Create Renderer Registry](./superseded/501b-create-renderer-registry.md) | retired (superseded/) | 501a |
| 501c | [Implement Null Renderer](./501c-implement-null-renderer.md) | open | 501 |
| 501d | [Implement Camera System](./501d-implement-camera-system.md) | open | 508 |
| 501e | [Create Render Events](./superseded/501e-create-render-events.md) | retired (superseded/) | 501a, 501b |
| 501f | [Raylib Rotating Cube Demo](./completed/501f-raylib-rotating-cube-demo.md) | completed | — |
| 502 | [Implement Terrain Rendering](./502-implement-terrain-rendering.md) | open | 508, 105, 501 |
| 502a | [Core Terrain Renderer](./502a-core-terrain-renderer.md) | open | 105 |
| 502b | [Height Visualization](./502b-height-visualization.md) | open | 502, 502e |
| 502c | [Water Rendering](./502c-water-rendering.md) | open | 502, 502e |
| 502d | [Fog of War Integration](./502d-fog-of-war-integration.md) | open | 502 |
| 502e | [Terrain Optimization](./502e-terrain-optimization.md) | open | 502a, 501d |
| 503 | [Build Sprite/Model Placeholder System](./503-build-sprite-placeholder-system.md) | open | 508, 501 |
| 503a | [Core Sprite System](./503a-core-sprite-system.md) | open | 508, 508b |
| 503b | [Unit Visual Mappings](./503b-unit-visual-mappings.md) | open | 110, 112 |
| 503c | [Team Colors and Selection](./503c-team-colors-selection.md) | open | 503a |
| 503d | [Health Bars and Indicators](./503d-health-bars-indicators.md) | open | 501 |
| 503e | [Facing Direction](./503e-facing-direction.md) | open | 501 |
| 504 | [Create Asset Pack Specification](./504-create-asset-pack-specification.md) | open | 516 |
| 505 | [Implement Default Visual Mode](./superseded/505-implement-default-visual-mode.md) | retired (superseded/) | 501, 502, 503 |
| 505a | [Default Renderer Backend](./superseded/505a-default-renderer-backend.md) | retired (superseded/) | 501a, 501b, 501c |
| 505b | [Wire Render Systems](./superseded/505b-wire-render-systems.md) | retired (superseded/) | 505a, 502, 503 |
| 505c | [Game View Camera](./505c-game-view-camera.md) | open | 501d |
| 505d | [Minimal UI](./superseded/505d-minimal-ui.md) | retired (superseded/) | 505b, 506 |
| 505e | [Input Commands](./superseded/505e-input-commands.md) | retired (superseded/) | 505c |
| 505f | [Debug Overlays](./505f-debug-overlays.md) | open | 501 |
| 506 | [Build UI Framework](./506-build-ui-framework.md) | open | 501, 501d |
| 506a | [UI Component System](./506a-ui-component-system.md) | open | 501 |
| 506b | [Layout System](./506b-layout-system.md) | open | 506a |
| 506c | [Input Handling](./506c-input-handling.md) | open | 506b |
| 506d | [Core UI Elements](./506d-core-ui-elements.md) | open | 506a, 506b, 506c |
| 506e | [Command Button Grid](./506e-command-button-grid.md) | open | 506c, 506d, 110 |
| 506f | [Tooltip System](./506f-tooltip-system.md) | open | 506c, 506d, 104 |
| 507 | [Create Minimap Renderer](./507-create-minimap-renderer.md) | open | 501, 501d, 502 |
| 507a | [Minimap Module](./507a-minimap-module.md) | open | 506a, 501d |
| 507b | [Terrain Texture](./507b-terrain-texture.md) | open | 507a, 502 |
| 507c | [Unit Dots](./507c-unit-dots.md) | open | 507a |
| 507d | [Camera Viewport](./507d-camera-viewport.md) | open | 507a, 501d |
| 507e | [Minimap Interaction](./507e-minimap-interaction.md) | open | 507a, 505c, 506c |
| 507f | [Ping System](./507f-ping-system.md) | open | 507a, 803 |
| 508 | [Vertical Slice - Testing Room](./completed/508-vertical-slice-testing-room.md) | completed | 501f |
| 508a | [Threading Infrastructure](./completed/508a-threading-infrastructure.md) | completed | 501a |
| 508b | [Entity Render Slots](./completed/508b-entity-render-slots.md) | completed | 508a |
| 508c | [Lua-C Bridge](./completed/508c-lua-c-bridge.md) | completed | 508b |
| 508d | [Map Integration](./completed/508d-map-integration.md) | completed | 508c |
| 508e | [Input and Selection](./completed/508e-input-and-selection.md) | completed | 508d |
| 508f | [Movement Orders](./completed/508f-movement-orders.md) | completed | 508e |
| 508g | [Minimal UI](./completed/508g-minimal-ui.md) | completed | 508d |
| 508h | [Integration Test](./completed/508h-integration-test.md) | completed | 508a, 508g |
| 508i | [Fix Chunk Ray Picking](./completed/508i-fix-chunk-ray-picking.md) | completed | 508a, 508b |
| 509 | [Player-Customizable Visual Effects](./509-player-customizable-visual-effects.md) | open | 501, 503, 508 |
| 510 | [Dual Perspective UI System](./archive/wow-mode-2026-01-08/510-dual-perspective-ui-system.md) | retired (archive/) | 506 |
| 510a | [Warlord Mode UI (RTS Interface)](./archive/wow-mode-2026-01-08/510a-warlord-mode-ui.md) | retired (archive/) | 506, 510 |
| 510b | [Hero Mode UI (RPG Interface)](./archive/wow-mode-2026-01-08/510b-hero-mode-ui.md) | retired (archive/) | 506, 510 |
| 510c | [Perspective Switching](./archive/wow-mode-2026-01-08/510c-perspective-switching.md) | retired (archive/) | 510a, 510b |
| 510d | [Shared UI Components](./archive/wow-mode-2026-01-08/510d-shared-ui-components.md) | retired (archive/) | 506, 510 |
| 510e | [UI State Persistence](./archive/wow-mode-2026-01-08/510e-ui-state-persistence.md) | retired (archive/) | 510a, 510d |
| 511 | [Render System Profiler](./completed/511-render-profiler.md) | completed | 508a |
| 511a | [Core Timing Infrastructure](./completed/511a-core-timing-infrastructure.md) | completed | 512 |
| 511b | [Thread-Safe Recording](./completed/511b-thread-safe-recording.md) | completed | 511a |
| 511c | [Overlay Rendering](./completed/511c-overlay-rendering.md) | completed | 511a, 511b |
| 511d | [History Buffer and Graphs](./completed/511d-history-buffer-graphs.md) | completed | 511c |
| 511e | [File Export](./completed/511e-file-export.md) | completed | 511a |
| 512 | [Threading Architecture Rewrite](./completed/512-threading-architecture-rewrite.md) | completed | 508a |
| 512a | [Worker Ring Buffer](./completed/512a-worker-ring-buffer.md) | completed | — |
| 512b | [Updater Load Balancing](./completed/512b-updater-load-balancing.md) | completed | 512a |
| 512c | [Self-Evaluating Updaters](./completed/512c-self-evaluating-updaters.md) | completed | 512a, 512b |
| 512d | [Sync Parallel Scan](./completed/512d-sync-parallel-scan.md) | completed | 512a, 512b |
| 512e | [Integration Testing](./completed/512e-integration-testing.md) | completed | 512a, 512b, 512c, 512d |
| 512f | [Main.c Threading Integration](./completed/512f-main-integration.md) | completed | 512a, 512e |
| 513 | [Threading Architecture Demo](./completed/513-threading-architecture-demo.md) | completed | 512f |
| 514 | [3D Rotation Frames](./514-3d-rotation-frames.md) | open | 409, 508 |
| 515 | [The Render Graph on the Ceramic Engine](./515-render-graph-on-the-ceramic-engine.md) | open | 508, 512 |
| 515a | [Copy-Cost Benchmark](./completed/515a-copy-cost-benchmark.md) | completed | — |
| 515b | [Ceramic Host Loop](./completed/515b-ceramic-host-loop.md) | completed | 515a, 515g |
| 515c | [Mailbox Triple Buffer](./completed/515c-mailbox-triple-buffer.md) | completed | 515b |
| 515d | [Extrapolate Predict Snap](./515d-extrapolate-predict-snap.md) | open | 515c |
| 515e | [Growing Asset Table](./515e-growing-asset-table.md) | open | 515b |
| 515f | [Measured Against The Pool](./515f-measured-against-the-pool.md) | open | 515c, 515d, 515e |
| 515g | [A Lock-Free Task Queue in a Kept Copy of the Engine](./completed/515g-lock-free-task-queue.md) | completed | 515a |
| 515h | [A Frame as a Graph](./completed/515h-a-frame-as-a-graph.md) | completed | 515g |
| 515i | [Destinations a Station May Name](./completed/515i-destinations-a-station-may-name.md) | completed | 515g, 515h |
| 515j | [Stronger Hand-Written Opponents](./completed/515j-stronger-hand-written-opponents.md) | completed | 515h, 515i |
| 515k | [A Crowd on Every Design](./515k-a-crowd-on-every-design.md) | open | 405f, 515h, 515j |
| 516 | [Draw WC3 Models in the Engine](./516-draw-wc3-models-in-engine.md) | open | 116, 117, 503b |

Completed 32, open 40, retired 15, as of the last run of `scripts/phase-progress-files.lua`.

<!-- phase-progress-files: issues end -->
