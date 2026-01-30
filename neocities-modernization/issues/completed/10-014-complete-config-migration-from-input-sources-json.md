# Issue 10-014: Complete Config Migration from input-sources.json

## Priority
High

## Related Issue
This is a follow-up to **Issue 10-003: Consolidate Config Files Into Single Source**, which was marked complete but left several scripts still referencing the old `config/input-sources.json` file.

## Current Behavior

Running `run.sh` produces:
```
⚠  Config file not found: /mnt/mtwo/programming/ai-stuff/neocities-modernization/config/input-sources.json
```

The following scripts still reference `config/input-sources.json`:

| Script | Line | Reference |
|--------|------|-----------|
| `scripts/update-words` | 15 | `CONFIG_FILE="${DIR}/config/input-sources.json"` |
| `scripts/generate-html-parallel` | 162 | `local config_file = DIR .. "/config/input-sources.json"` |
| `scripts/validate-poem-representation` | 33 | `local CONFIG_FILE = DIR .. "/config/input-sources.json"` |

Issue 10-003 marked these scripts as "Migrated" in its completion notes, but the actual code was not updated.

## Intended Behavior

All scripts should use the unified `config.lua` file:
- Load configuration via `dofile(DIR .. "/config.lua")` or equivalent
- Access settings through the Lua config structure
- No references to `input-sources.json` should remain in active code

## Root Cause

Issue 10-003 documented the migration plan and updated the progress tracking, but the actual code changes to these three scripts were not implemented before marking the issue complete.

## Suggested Implementation Steps

### 1. Update `scripts/update-words`
```bash
# Before (line 15):
CONFIG_FILE="${DIR}/config/input-sources.json"

# After: Load config via Lua helper or inline parsing
# Option A: Call a Lua script that returns JSON from config.lua
# Option B: Create a bash-compatible config export
```

### 2. Update `scripts/generate-html-parallel`
```lua
-- Before (line 162):
local config_file = DIR .. "/config/input-sources.json"

-- After:
dofile(DIR .. "/config.lua")
-- Access config.pagination, config.output, etc.
```

### 3. Update `scripts/validate-poem-representation`
```lua
-- Before (line 33):
local CONFIG_FILE = DIR .. "/config/input-sources.json"

-- After:
dofile(DIR .. "/config.lua")
-- Access config.pagination, etc.
```

### 4. Verify Migration Completeness
```bash
# Should return no results after migration:
grep -rn "input-sources.json" scripts/ src/ --include="*.lua" --include="*.sh"
```

### 5. Delete Deprecated File
Once all migrations are complete and verified:
```bash
rm config/input-sources.json  # If it still exists
```

## Affected Files

- `scripts/update-words` — Bash script, needs Lua bridge or config export
- `scripts/generate-html-parallel` — Lua script, straightforward migration
- `scripts/validate-poem-representation` — Lua script, straightforward migration
- `config.lua` — May need additional accessor functions for bash compatibility

## Edge Cases

1. **Bash scripts**: Cannot directly `dofile()` Lua config. Options:
   - Create `scripts/export-config-to-json` that outputs JSON from config.lua
   - Use inline Lua: `lua -e "dofile('config.lua'); print(config.image_sync.enabled)"`
   - Create bash-readable config section in config.lua comments

2. **Testing**: Run full pipeline after migration to ensure all config values are correctly accessed

## Implementation Notes

### Solution for Bash Scripts

For `scripts/update-words`, created three helper functions that use inline Lua to read config values:

```bash
# get_config_value "image_sync.enabled" -> "true"
# get_config_array_length "image_sync.sources" -> "2"
# get_config_array_item "image_sync.sources" 1 "name" -> "fediverse_media"
```

This approach:
- Avoids dependency on jq for JSON parsing
- Uses the same config.lua file as all other scripts
- Supports nested keys via dot notation (e.g., "image_sync.enabled")
- Handles arrays with 1-indexed Lua semantics

### Solution for Lua Scripts

For `scripts/generate-html-parallel` and `scripts/validate-poem-representation`:

```lua
local ok, config = pcall(dofile, DIR .. "/config.lua")
if ok and config and config.pagination then
    -- Access config values directly
end
```

### Files Modified

| File | Change |
|------|--------|
| `scripts/update-words` | Added Lua helper functions, replaced jq calls |
| `scripts/generate-html-parallel` | Replaced JSON loading with dofile() |
| `scripts/validate-poem-representation` | Replaced JSON loading with dofile() |

### Verification

```bash
# All remaining references are migration comments only:
grep -rn "input-sources.json" scripts/ src/
# scripts/validate-poem-representation:33:-- Issue 10-014: Migrated from ...
# scripts/update-words:6:# Issue 10-014: Migrated from ...
# scripts/generate-html-parallel:161:-- Issue 10-014: Migrated from ...
# src/image-manager.lua:45:-- Issue 10-003: Use unified config ...
```

### Testing

Both bash and Lua config loading verified working:
- `image_sync.enabled: true`
- `pagination.poems_per_page: 100`
- `pagination.chronological_poems_per_page: 500`

## Metadata

- **Status**: Completed
- **Created**: 2026-01-30
- **Completed**: 2026-01-30
- **Phase**: 10 (Developer Experience & Tooling)
- **Blocks**: Pipeline execution (warnings on every run) - **RESOLVED**
- **Related**: 10-003 (original consolidation issue)
