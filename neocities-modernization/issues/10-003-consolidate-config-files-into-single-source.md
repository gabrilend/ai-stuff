# Issue 10-003: Consolidate Config Files Into Single Authoritative Source

**Priority**: Low
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Open
**Created**: 2025-12-23

---

## Current Behavior

Configuration is scattered across five separate files in `/config/`:

| File | Format | Purpose |
|------|--------|---------|
| `asset-paths.lua` | Lua | Generated asset storage locations |
| `golden-poem-settings.json` | JSON | Golden poem prioritization settings |
| `input-sources.json` | JSON | Input paths, extraction, privacy, image settings |
| `semantic-colors.json` | JSON | Color definitions for semantic clustering |
| `similarity-calculator-settings.json` | JSON | Similarity algorithm configurations |

Each script that needs configuration imports one or more of these files independently.
There is no single place to see "all the knobs" at once, and no guarantee that
related settings across files remain consistent.

---

## Intended Behavior

A single authoritative configuration file (`config/main.lua` or `config/main.json`)
that contains all project settings in one place. Two possible approaches:

### Approach A: Sync Script (run at startup)

A script runs early in `run.sh` that:
1. Reads the main config file
2. Extracts relevant sections
3. Writes them to the existing config file locations

**Pros**: Existing scripts don't need modification
**Cons**: Config files can drift if someone edits them directly; extra sync step

### Approach B: Direct Import (preferred)

Replace the concept of separate config files entirely:
1. Main config file contains all settings in named sections
2. Each script imports the main config and accesses its relevant section
3. Old config files are removed or become symlinks/stubs

**Pros**: Single source of truth; no sync needed; impossible to drift
**Cons**: Requires updating import statements in existing scripts

---

## Suggested Implementation Steps

### If Approach A (Sync Script):
1. Create `/config/main.lua` with all settings consolidated
2. Write `/scripts/sync-config.lua` that parses main config and writes to individual files
3. Add `lua scripts/sync-config.lua` to the beginning of `run.sh`
4. Document that `/config/main.lua` is authoritative; others are generated

### If Approach B (Direct Import):
1. Create `/config/main.lua` with all settings in a nested table structure
2. Create `/libs/config-loader.lua` utility that loads and caches the main config
3. Update each script to use: `local config = require("libs.config-loader")`
4. Access settings via: `config.asset_paths`, `config.golden_poems`, etc.
5. Remove or deprecate the individual config files
6. Update documentation

---

## Proposed Main Config Structure (Lua)

```lua
-- /config/main.lua
-- Single authoritative configuration for neocities-modernization
-- All other config files are deprecated in favor of this one.

return {
    -- Asset storage paths (from asset-paths.lua)
    asset_paths = {
        assets_root = "/mnt/mtwo/programming/ai-stuff/neocities-modernization/assets"
    },

    -- Input sources and extraction (from input-sources.json)
    input_sources = {
        fediverse_backup_path = "input/fediverse",
        messages_backup_path = "input/messages",
        words_source_path = "input/words",
        notes_source_path = "input/notes"
    },

    extraction = {
        enable_fediverse = true,
        enable_messages = true,
        enable_notes = true,
        output_format = "json"
    },

    privacy = {
        mode = "clean",
        anonymization_prefix = "user-",
        include_boosts = true,
        preserve_original_length = true,
        store_anonymization_map = false,
        local_server_domain = "tech.lgbt"
    },

    -- Golden poem settings (from golden-poem-settings.json)
    golden_poems = {
        enable_golden_prioritization = true,
        golden_poem_pair_bonus = 0.05,
        golden_poem_single_bonus = 0.02,
        golden_bonus_threshold = 0.1,
        min_golden_recommendations = 2,
        max_golden_recommendations = 5
    },

    -- Semantic colors (from semantic-colors.json)
    semantic_colors = {
        red    = { rgb = {220, 60, 60},   hex = "#dc3c3c" },
        blue   = { rgb = {60, 120, 220},  hex = "#3c78dc" },
        green  = { rgb = {60, 180, 90},   hex = "#3cb45a" },
        purple = { rgb = {140, 60, 200},  hex = "#8c3cc8" },
        orange = { rgb = {230, 140, 60},  hex = "#e68c3c" },
        yellow = { rgb = {200, 180, 40},  hex = "#c8b428" },
        gray   = { rgb = {120, 120, 120}, hex = "#787878" }
    },
    color_names = {"red", "blue", "green", "purple", "orange", "yellow", "gray"},

    -- Similarity calculation (from similarity-calculator-settings.json)
    similarity = {
        default_algorithm = "cosine",
        algorithms = {
            cosine = {
                description = "Cosine similarity - measures angle between vectors",
                recommended_for = {"text_embeddings", "high_dimensional_vectors"},
                performance = "fast",
                range = "[-1, 1]"
            },
            euclidean = {
                description = "Euclidean distance converted to similarity",
                recommended_for = {"low_dimensional", "spatial_data"},
                performance = "fast",
                range = "[0, 1]"
            }
            -- ... other algorithms
        }
    },

    -- Image integration (from input-sources.json)
    image_integration = {
        enabled = true,
        image_directories = {"input/media_attachments"},
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
        max_file_size_mb = 10,
        output_path = "assets/images",
        catalog_file = "assets/image-catalog.json"
    }
}
```

---

## Success Criteria

- [ ] Single config file contains all project settings
- [ ] All scripts use the consolidated config (directly or via sync)
- [ ] No configuration drift possible between files
- [ ] Changing a setting in one place affects all consumers
- [ ] Documentation updated to reflect new config location
- [ ] Old config files either removed or clearly marked as generated/deprecated

---

## Related Documents

- `/config/asset-paths.lua` - Current asset path config
- `/config/golden-poem-settings.json` - Current golden poem config
- `/config/input-sources.json` - Current input/extraction config
- `/config/semantic-colors.json` - Current color definitions
- `/config/similarity-calculator-settings.json` - Current similarity settings
- `/docs/data-flow-architecture.md` - References config files in Configuration section

---

## Notes

- Approach B (Direct Import) is recommended for long-term maintainability
- Lua format preferred over JSON since the codebase is Lua-native
- The config-loader utility could cache the parsed config to avoid re-reading
- Consider adding a `--config` CLI flag to override the default config path
