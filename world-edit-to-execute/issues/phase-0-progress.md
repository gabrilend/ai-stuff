# Phase 0: Tooling/Infrastructure — Progress

## Goals

From `docs/roadmap.md`, "Phase 0: Tooling/Infrastructure (In Progress)":

Development infrastructure and shared systems.

Live counts: `lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m`

## Issues

<!-- phase-progress-files: issues begin (generated; edits here are overwritten) -->

| ID | Title | Status | Depends on |
|----|-------|--------|------------|
| 000 | [Warlord Mode Design Compendium](./archive/wow-mode-2026-01-08/000-warlord-mode-design-compendium.md) | retired (archive/) | — |
| 001 | [Combat System Design](./archive/wow-mode-2026-01-08/001-combat-system-design.md) | retired (archive/) | — |
| 001 | [Fix Issue Splitter Output Handling](./completed/001-fix-issue-splitter-output-handling.md) | completed | — |
| 002 | [Add Streaming Queue to Issue Splitter](./completed/002-add-streaming-queue-to-issue-splitter.md) | completed | 001 |
| 002 | [Caravan Economy Design](./archive/wow-mode-2026-01-08/002-caravan-economy-design.md) | retired (archive/) | — |
| 002a | [Add Queue Infrastructure](./completed/002a-add-queue-infrastructure.md) | completed | 002 |
| 002b | [Add Producer Function](./completed/002b-add-producer-function.md) | completed | 002a |
| 002c | [Add Streamer Process](./completed/002c-add-streamer-process.md) | completed | 002a |
| 002d | [Add Parallel Processing Loop](./completed/002d-add-parallel-processing-loop.md) | completed | 002a, 002b, 002c |
| 002e | [Add Streaming Config Flags](./completed/002e-add-streaming-config-flags.md) | completed | 002d |
| 003 | [Execute Analysis Recommendations](./completed/003-execute-analysis-recommendations.md) | completed | 001 |
| 003 | [Patrol and Raid System Design](./archive/wow-mode-2026-01-08/003-patrol-raid-system-design.md) | retired (archive/) | — |
| 004 | [Redesign Interactive Mode Interface](./completed/004-redesign-interactive-mode-interface.md) | completed | — |
| 004 | [Warlord Interface Design](./archive/wow-mode-2026-01-08/004-warlord-interface-design.md) | retired (archive/) | — |
| 004a | [Create TUI Core Library](./completed/004a-create-tui-core-library.md) | completed | — |
| 004b | [Implement Checkbox Component](./completed/004b-implement-checkbox-component.md) | completed | 004a |
| 004c | [Implement Multi-State Toggle Component](./completed/004c-implement-multistate-toggle.md) | completed | 004a, 004b |
| 004d | [Implement Number Input and Text Input Components](./completed/004d-implement-input-components.md) | completed | 004a |
| 004e | [Build Menu Structure and Navigation System](./completed/004e-build-menu-navigation-system.md) | completed | 004b, 004c, 004d |
| 004f | [Integrate TUI into Issue-Splitter](./completed/004f-integrate-tui-into-issue-splitter.md) | completed | 004a, 004b, 004c, 004d, 004e |
| 005 | [Class and Gem System Design](./archive/wow-mode-2026-01-08/005-class-gem-system-design.md) | retired (archive/) | — |
| 005 | [Migrate TUI Library to Shared Libs Directory](./completed/005-migrate-tui-library-to-shared-libs.md) | completed | 004 |
| 006 | [Rename Analysis Sections for Promoted Roots](./completed/006-rename-analysis-sections-for-promoted-roots.md) | completed | 003 |
| 007 | [Add Auto-Implement via Claude CLI](./completed/007-add-auto-implement-via-claude-cli.md) | completed | — |
| 010 | [Debug TUI Integration Analysis](./completed/010-debug-tui-integration-analysis.md) | completed | — |
| 011 | [Combine Duplicate Run-Demo Scripts](./completed/011-combine-duplicate-run-demo-scripts.md) | completed | — |
| 011 | [TUI History Insert on Run](./completed/011-tui-history-insert-on-run.md) | completed | 004 |
| 012 | [Interactive Verdict Review Mode](./completed/012-interactive-verdict-review-mode.md) | completed | — |
| 013 | [Quest & Bounty Template System](./completed/013-quest-bounty-template-system.md) | completed | — |
| 014 | [Guild Hero & Shop System](./completed/014-guild-hero-shop-system.md) | completed | — |
| 015 | [WoW-Style Combat & Stat System](./archive/wow-mode-2026-01-08/015-wow-style-combat-system.md) | retired (archive/) | 014 |
| 016 | [Attribute Getter/Setter System](./archive/wow-mode-2026-01-08/016-attribute-getter-setter-system.md) | retired (archive/) | 014, 015 |
| 016a | [Core Attribute Registry](./completed/016a-core-attribute-registry.md) | completed | — |
| 016b | [Dispatch Table Getters](./completed/016b-dispatch-table-getters.md) | completed | 016a |
| 016c | [Dispatch Table Setters](./completed/016c-dispatch-table-setters.md) | completed | 016a |
| 016d | [Modifier Stack System](./completed/016d-modifier-stack-system.md) | completed | 016a, 016b, 016c |
| 016e | [Derived Attribute Engine](./completed/016e-derived-attribute-engine.md) | completed | 016a |
| 016f | [WC3 Attribute Config](./completed/016f-wc3-attribute-config.md) | completed | 016a, 016e |
| 016g | [WoW Attribute Config](./completed/016g-wow-attribute-config.md) | completed | 016a, 016e |
| 016h | [Cross-System Mapping](./completed/016h-cross-system-mapping.md) | completed | 016f, 016g |
| 016i | [Integration Tests](./completed/016i-integration-tests.md) | completed | 016a, 016h |
| 017 | [Unified Currency/Resource System](./completed/017-unified-currency-system.md) | completed | 406, 016 |
| 017a | [Currency Registry and Dispatch Tables](./completed/017a-currency-registry-dispatch.md) | completed | 017b, 017i |
| 017b | [Money Bag Component](./completed/017b-money-bag-component.md) | completed | 017a |
| 017c | [Currency Container Component](./completed/017c-currency-container-component.md) | completed | — |
| 017d | [Reputation System](./completed/017d-reputation-system.md) | completed | — |
| 017f | [Vendor Transaction Flow](./completed/017f-vendor-transaction-flow.md) | completed | — |
| 017g | [WC3-WoW Conversion](./completed/017g-wc3-wow-conversion.md) | completed | — |
| 017i | [Tests and Integration](./completed/017i-tests-and-integration.md) | completed | — |

Completed 41, open 0, retired 8, as of the last run of `scripts/phase-progress-files.lua`.

<!-- phase-progress-files: issues end -->
