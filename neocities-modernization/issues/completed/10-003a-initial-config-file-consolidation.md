# Issue 10-003a: Initial Config File Consolidation

**Priority**: Low
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Completed
**Completed**: 2026-01-21
**Created**: 2025-12-23
**Parent Issue**: 10-003

---

## Summary

Consolidate six separate configuration files into a single authoritative `config.lua` file
with a config-loader utility for unified access.

---

## Current Behavior (Before)

Configuration was scattered across six separate files:

| File | Format | Purpose |
|------|--------|---------|
| `/config/asset-paths.lua` | Lua | Generated asset storage locations |
| `/config/golden-poem-settings.json` | JSON | Golden poem prioritization settings |
| `/config/input-sources.json` | JSON | Input paths, extraction, privacy, image settings |
| `/config/semantic-colors.json` | JSON | Color definitions for semantic clustering |
| `/config/similarity-calculator-settings.json` | JSON | Similarity algorithm configurations |
| `/assets/centroids.json` | JSON | Mood-based centroid definitions for exploration pages |

---

## Intended Behavior

A single `config.lua` file in the project root containing all settings, accessed through
a `libs/config-loader.lua` utility module.

---

## Implementation (Completed 2026-01-21)

### Files Created

1. **`config.lua`** - Consolidated configuration with all settings:
   - `asset_paths` - Generated asset storage locations
   - `layout` - Output width and box styling
   - `input_sources` - Input paths for fediverse, messages, notes, bluesky
   - `extraction` - Extraction behavior settings
   - `privacy` - Anonymization and privacy settings
   - `golden_poems` - Golden poem prioritization
   - `semantic_colors` - Color definitions
   - `similarity` - Algorithm settings
   - `image_integration` - Image processing settings
   - `image_sync` - Image sync sources
   - `pagination` - Poems per page settings
   - `storage` - Neocities quota information
   - `word_cloud` - Word cloud settings (including embedded stop words)
   - `centroids` - Mood-based centroids
   - `html_theme` - Dark mode colors
   - `excluded_poems` - Poems to exclude from collection

2. **`libs/config-loader.lua`** - Utility module:
   - Automatic project root detection
   - Config caching (loaded once per session)
   - Dot-notation path access: `config_loader.get("asset_paths.assets_root")`
   - Metatable for direct table access: `config.asset_paths.assets_root`

### Scripts Migrated

| Script | Old Config File | Status |
|--------|----------------|--------|
| `scripts/extract-fediverse.lua` | `config/input-sources.json` | Migrated |
| `scripts/extract-messages.lua` | `config/input-sources.json` | Migrated |
| `scripts/extract-notes.lua` | `config/input-sources.json` | Migrated |
| `src/flat-html-generator.lua` | `config/input-sources.json` | Migrated |
| `src/similarity-calculator.lua` | `config/similarity-calculator-settings.json` | Migrated |
| `src/centroid-generator.lua` | `assets/centroids.json` | Migrated |
| `src/semantic-color-calculator.lua` | `config/semantic-colors.json` | Migrated |
| `src/image-manager.lua` | `config/input-sources.json` | Migrated |
| `src/wordcloud-generator.lua` | `config/input-sources.json` | Migrated |
| `src/html-generator/golden-poem-bonus.lua` | `config/golden-poem-settings.json` | Migrated |

### Files Deleted

- `config/golden-poem-settings.json`
- `config/similarity-calculator-settings.json`
- `config/semantic-colors.json`
- `config/input-sources.json`
- `config/asset-paths.lua`
- `config/excluded-poems.txt` (embedded in config.lua)
- `config/stop-words.txt` (embedded in config.lua)
- Entire `config/` directory removed

---

## Usage

```lua
-- Simple usage
local config = require("config-loader")
local assets_root = config.asset_paths.assets_root
local colors = config.semantic_colors

-- Alternative: get specific values
local config_loader = require("config-loader")
local value = config_loader.get("pagination.poems_per_page")
```

---

## Success Criteria

- [x] Single config file contains all project settings
- [x] Config-loader utility created for script migration
- [x] All 11 scripts updated to use config-loader
- [x] Old config files deleted
- [x] `config/` directory removed
- [x] Text files (excluded-poems, stop-words) embedded in config.lua

---

## Related Sub-Issues

- 10-003b: External files syncing centralization
- 10-003c: Unified input sources structure

---

**ISSUE STATUS: COMPLETED**
