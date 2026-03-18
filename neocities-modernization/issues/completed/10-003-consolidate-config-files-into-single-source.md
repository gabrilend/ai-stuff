# Issue 10-003: Consolidate Config Files Into Single Authoritative Source

**Priority**: Medium
**Phase**: 10 (Developer Experience & Tooling)
**Status**: In Progress
**Initial Completion**: 2026-01-21
**Re-Opened**: 2026-01-30
**Created**: 2025-12-23

---

## Summary

This is an umbrella issue for consolidating all configuration into a single `config.lua` file.
The work is split into three sub-issues covering different aspects of configuration unification.

---

## Sub-Issues

| Issue | Description | Status |
|-------|-------------|--------|
| [10-003a](completed/10-003a-initial-config-file-consolidation.md) | Initial config file consolidation | **Completed** (2026-01-21) |
| [10-003b](10-003b-external-files-syncing-centralization.md) | External files syncing centralization | **Open** |
| [10-015](10-015-unified-input-sources-config.md) | Unified input sources configuration | **Open** |

---

## Progress Overview

### Completed: Initial Consolidation (10-003a)

- Consolidated 6 config files into single `config.lua`
- Created `libs/config-loader.lua` utility
- Migrated 11 scripts to unified config
- Embedded text files (stop-words, excluded-poems)
- Deleted `config/` directory

### Open: External Files Centralization (10-003b)

Current state: External file syncing is hardcoded in scripts:
- `scripts/update-words:296` - hardcoded `/home/ritz/backups/words/sync-to-projects`
- `scripts/update:117-129` - hardcoded `/home/ritz/backups/bluesky/input`

Intended: All external syncing declared in `external_files` config section with:
- `name` - identifier for logging/CLI
- `source` - absolute path to external location
- `destination` - relative to `input/`
- `type` - `"script"` or `"directory"`
- `optional` - whether missing source is fatal

### Open: Unified Input Sources (10-015)

Current state: Input settings scattered across 4 sections:
- `input_sources` (paths)
- `extraction` (enable/disable toggles)
- `image_sync` (external image sources)
- `image_integration` (processing settings)

Intended: Single `sources` section where:
- Each source type supports multiple named directories
- Deduplication by content ID across directories
- Per-source format and media settings

---

## Success Criteria

- [x] Single config file contains all project settings (10-003a)
- [x] All scripts use config-loader (10-003a)
- [ ] All external file syncing declared in config (10-003b)
- [ ] No hardcoded external paths in scripts (10-003b)
- [ ] Unified sources structure (10-015)
- [ ] Deprecated sections removed (10-015)

---

## Implementation Order

1. **10-003b** (External Files) - Can be implemented independently
2. **10-015** (Unified Sources) - Larger refactor, depends on stable extraction

---

**ISSUE STATUS: IN PROGRESS** (2 of 3 sub-issues remaining)
