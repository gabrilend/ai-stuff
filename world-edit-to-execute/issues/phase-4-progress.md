# Phase 4: Runtime - Basic Engine Loop ✓ COMPLETED — Progress

## Goals

From `docs/roadmap.md`, "Phase 4: Runtime - Basic Engine Loop ✓ COMPLETED":

All 34 issues complete. Core game execution environment operational.

Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m`

## Issues

<!-- phase-progress-files: issues begin (generated; edits here are overwritten) -->

| ID | Title | Status | Depends on |
|----|-------|--------|------------|
| 401 | [Implement Game Tick/Update Loop](./completed/401-implement-game-tick-update-loop.md) | completed | — |
| 401a | [Core Fixed Timestep Loop](./completed/401a-core-fixed-timestep-loop.md) | completed | — |
| 401b | [Timer Subsystem](./completed/401b-timer-subsystem.md) | completed | 401a |
| 402 | [Build Entity Component System](./completed/402-build-entity-component-system.md) | completed | 401 |
| 402a | [Implement Entity Manager](./completed/402a-implement-entity-manager.md) | completed | 401 |
| 402b | [Implement Component Registry](./completed/402b-implement-component-registry.md) | completed | 402a |
| 402c | [Implement Component Queries](./completed/402c-implement-component-queries.md) | completed | 402b |
| 402d | [Implement System Registration](./completed/402d-implement-system-registration.md) | completed | 402c |
| 402e | [Define Core WC3 Components](./completed/402e-define-core-wc3-components.md) | completed | 402b |
| 402f | [Implement Entity Handles (Optional)](./completed/402f-implement-entity-handles-(Optional).md) | completed | 402a |
| 403 | [Implement Basic Pathfinding](./completed/403-implement-basic-pathfinding.md) | completed | 401, 402, 105 |
| 403a | [Build Pathing Grid](./completed/403a-build-pathing-grid.md) | completed | 105 |
| 403b | [Implement A* Algorithm](./completed/403b-implement-astar-algorithm.md) | completed | — |
| 403c | [Coordinate Conversion](./completed/403c-coordinate-conversion.md) | completed | 403a |
| 403d | [Movement Type Support](./completed/403d-movement-type-support.md) | completed | 403a, 403b |
| 403e | [Path Smoothing](./completed/403e-path-smoothing.md) | completed | 403b |
| 404 | [Create Unit Movement System](./completed/404-create-unit-movement-system.md) | completed | 401, 402, 403 |
| 404a | [Core Movement System](./completed/404a-core-movement-system.md) | completed | 401, 402 |
| 404b | [Path Following Logic](./completed/404b-path-following-logic.md) | completed | 404a, 403 |
| 404c | [Movement Orders](./completed/404c-movement-orders.md) | completed | 404b, 403 |
| 404d | [Advanced Movement Behaviors](./completed/404d-advanced-movement-behaviors.md) | completed | 404b, 404c |
| 405 | [Implement Basic Collision Detection](./completed/405-implement-basic-collision-detection.md) | completed | 401, 402, 404 |
| 405a | [Collision Primitives and Shapes](./completed/405a-collision-primitives-and-shapes.md) | completed | 402 |
| 405b | [Spatial Hash Grid](./completed/405b-spatial-hash-grid.md) | completed | 405a |
| 405c | [Collision Queries](./completed/405c-collision-queries.md) | completed | 405a, 405b |
| 405d | [Movement Collision Integration](./completed/405d-movement-collision-integration.md) | completed | 405c, 404 |
| 405e | [Projectile Hit Detection and Picking](./completed/405e-projectile-and-picking.md) | completed | 405c |
| 405f | [Units Path Around Units](./405f-units-path-around-units.md) | open | 403, 405d |
| 406 | [Build Resource Management System](./completed/406-build-resource-management-system.md) | completed | 401, 402, 407 |
| 406a | [Core Resource Storage](./completed/406a-core-resource-storage.md) | completed | — |
| 406b | [Spending and Validation](./completed/406b-spending-validation.md) | completed | 406a |
| 406c | [Food Supply and Harvesting Integration](./completed/406c-food-and-harvesting.md) | completed | 406a, 402 |
| 407 | [Create Player State Management](./completed/407-create-player-state-management.md) | completed | 401, 402 |
| 407a | [Player Data Structure](./completed/407a-player-data-structure.md) | completed | 103 |
| 407b | [Player Queries](./completed/407b-player-queries.md) | completed | 407a |
| 407c | [Alliance Management](./completed/407c-alliance-management.md) | completed | 407a |
| 407d | [Player State Transitions](./completed/407d-player-state-transitions.md) | completed | 407a, 407b, 402 |
| 407e | [Victory Conditions](./completed/407e-victory-conditions.md) | completed | 407a, 407b, 407d |
| 407f | [Local Player Support](./completed/407f-local-player-support.md) | completed | 407a |
| 408 | [Phase 4 Integration Test](./completed/408-phase-4-integration-test.md) | completed | 401, 407 |
| 408a | [Unit Tests - Core Systems](./completed/408a-unit-tests-core-systems.md) | completed | 401, 402, 403 |
| 408b | [Unit Tests - Entity Systems](./completed/408b-unit-tests-entity-systems.md) | completed | 408a, 404, 405 |
| 408c | [Unit Tests - Player Systems](./completed/408c-unit-tests-player-systems.md) | completed | 408a, 406, 407 |
| 408d | [Integration Scenario](./completed/408d-integration-scenario.md) | completed | 408a, 408b, 408c |
| 408e | [Visual Demo](./completed/408e-visual-demo.md) | completed | 408d |
| 409 | [Frame-Based Pathfinding Storage](./completed/409-frame-based-pathfinding.md) | completed | 403 |

Completed 45, open 1, retired 0, as of the last run of `scripts/phase-progress-files.lua`.

<!-- phase-progress-files: issues end -->
