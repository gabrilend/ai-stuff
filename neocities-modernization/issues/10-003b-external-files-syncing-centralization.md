# Issue 10-003b: External Files Syncing Centralization

**Priority**: Medium
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Open
**Created**: 2026-01-30
**Parent Issue**: 10-003

---

## Summary

Centralize all external file syncing operations into a single `external_files` config
section. No external files should be pulled unless they're specified in this section.

---

## Current Behavior

External file syncing operations are hardcoded in scripts:

| Script | Line | Source | Destination |
|--------|------|--------|-------------|
| `scripts/update` | 117-129 | `/home/ritz/backups/bluesky/input` | `input/bluesky/` |
| `scripts/update-words` | 170-284 | Config-driven (image_sync.sources) | `input/media_attachments/` |

Additionally, scripts depend on specific filenames:
- `scripts/update` lines 199-206: Checks for `repo.car` or `repo-2.car` specifically
- `scripts/extract-bluesky-data` line 20: Defaults to `repo-2.car`

**Issues with current approach:**
1. External paths are scattered across multiple scripts
2. Scripts depend on specific filenames (breaks if filename changes)
3. No single view of what external data the pipeline requires
4. Cannot easily disable or redirect a source
5. Hard to replicate setup on another machine

---

## Intended Behavior

All external file syncing declared in a single `external_files` config section:

```lua
-- {{{ external_files
-- Defines all external files/directories the pipeline pulls from.
-- NO external file operations should occur unless configured here.
-- All destinations are relative to input/.
-- Archive selection (newest by mtime) is handled by downstream scripts.
external_files = {
    {
        name = "bluesky-car",
        source = "/home/ritz/backups/bluesky/input",
        destination = "bluesky",
    },
    {
        name = "my-art",
        source = "/home/ritz/pictures/my-art",
        destination = "media_attachments/my-art",
    },
    {
        name = "things-I-almost-posted",
        source = "/home/ritz/pictures/things-i-almost-posted",
        destination = "media_attachments/things-i-almost-posted",
    },
    {
        name = "poem-pictures",
        source = "/home/ritz/pictures/poem-pictures",
        destination = "media_attachments/poem-pictures",
    },
},
-- }}}
```

---

## Config Field Definitions

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier for logging and CLI targeting |
| `source` | Yes | Absolute path to external directory |
| `destination` | Yes | Relative path under `input/` |
| `optional` | No | Default false. If true, missing source shows warning instead of error |

**Note:** No `pattern` or `select` fields needed - archive selection logic (newest by mtime)
is already implemented in downstream scripts (see issue 7-005).

---

## Hardcoded References to Fix

Scripts must accept generic arguments and not depend on specific filenames.

### `scripts/update` (lines 117-129, 199-206)

**Current (hardcoded):**
```bash
BLUESKY_BACKUP_DIR="/home/ritz/backups/bluesky/input"
...
if [ -f "${DIR}/input/bluesky/repo.car" ] || [ -f "${DIR}/input/bluesky/repo-2.car" ]; then
    if [ -f "${DIR}/input/bluesky/repo-2.car" ]; then
        CAR_FILE="${DIR}/input/bluesky/repo-2.car"
    elif [ -f "${DIR}/input/bluesky/repo.car" ]; then
        CAR_FILE="${DIR}/input/bluesky/repo.car"
```

**Fix:** Find ANY `.car` file in `input/bluesky/`, prefer newest by mtime:
```bash
CAR_FILE=$(find "${DIR}/input/bluesky" -name "*.car" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [ -n "$CAR_FILE" ]; then
    "${DIR}/scripts/extract-bluesky-data" "$CAR_FILE" ...
fi
```

### `scripts/extract-bluesky-data` (line 20)

**Current (hardcoded default):**
```lua
local INPUT_CAR = arg[1] or DIR .. "/input/bluesky/repo-2.car"
```

**Fix:** Find any `.car` file if not provided:
```lua
local function find_car_file()
    local handle = io.popen("find '" .. DIR .. "/input/bluesky' -name '*.car' -type f 2>/dev/null | head -1")
    local result = handle:read("*l")
    handle:close()
    return result
end
local INPUT_CAR = arg[1] or find_car_file() or error("No CAR file found in input/bluesky/")
```

### `config.lua` (lines 190, 196, 202)

**Current:** Already config-driven via `image_sync.sources` - these will be migrated to `external_files`

---

## Sections to Deprecate

After implementing `external_files`, these sections become redundant:

| Section | Replacement |
|---------|-------------|
| `image_sync.sources` | Merged into `external_files` with `destination = "media_attachments/..."` |

**Note**: The `image_sync` section has additional options (preserve_structure, overwrite_existing,
supported_formats) that should be moved to either global sync settings or per-entry options
in `external_files`.

---

## Implementation Steps

### Phase 1: Fix Hardcoded Filenames
1. [x] Update `scripts/update` to find any `.car` file by pattern (not specific names)
2. [x] Update `scripts/extract-bluesky-data` to find CAR file dynamically if not provided

### Phase 2: Centralize External Sources
3. [x] Add `external_files` section to `config.lua`
4. [x] Create `libs/external-sync.lua` module to process external_files config
5. [x] Update `scripts/update` to use external-sync module (replace hardcoded Bluesky sync)
6. [ ] Merge `image_sync.sources` entries into `external_files`
7. [ ] Update `scripts/update-words` to iterate external_files instead of custom logic

### Phase 3: CLI Integration
8. [ ] Add `--list-external` CLI flag to show configured external sources
9. [ ] Add `--sync-only NAME` CLI flag to sync a single source

### Phase 4: Cleanup
10. [ ] Remove deprecated `image_sync.sources` section
11. [ ] Verify no hardcoded external paths remain

---

## Files to Update

| File | Changes |
|------|---------|
| `config.lua` | Add `external_files` section |
| `libs/external-sync.lua` | New module for syncing logic |
| `scripts/update-words` | Replace hardcoded sync-to-projects call |
| `scripts/update` | Replace hardcoded Bluesky CAR sync |
| `run.sh` | Add CLI flags for external source management |

---

## Success Criteria

- [ ] All external file syncing declared in `external_files` config
- [ ] No hardcoded external paths in scripts
- [ ] Scripts accept generic arguments (not specific filenames like `repo-2.car`)
- [ ] Scripts discover files by pattern/extension, not hardcoded names
- [ ] CLI flags for listing and selectively syncing sources
- [ ] Missing required sources produce fatal errors
- [ ] Missing optional sources produce attention messages
- [ ] Easy to add/remove/disable external sources via config only

---

## Related Sub-Issues

- 10-003a: Initial config file consolidation (COMPLETED)
- 10-003c: Unified input sources structure

---

**ISSUE STATUS: OPEN**
