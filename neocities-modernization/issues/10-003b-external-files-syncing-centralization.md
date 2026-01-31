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

| Script | Line | Operation | Source | Destination |
|--------|------|-----------|--------|-------------|
| `scripts/update-words` | 296 | Shell call | `/home/ritz/backups/words/sync-to-projects` | Runs external script |
| `scripts/update` | 117-129 | Bluesky CAR | `/home/ritz/backups/bluesky/input` | `input/bluesky/` |
| `scripts/update-words` | 170-284 | Image sync | Config-driven (image_sync.sources) | `input/media_attachments/` |

**Issues with current approach:**
1. External paths are scattered across multiple scripts
2. No single view of what external data the pipeline requires
3. Cannot easily disable or redirect a source
4. Hard to replicate setup on another machine

---

## Intended Behavior

All external file syncing declared in a single `external_files` config section:

```lua
-- {{{ external_files
-- Defines all external files/directories the pipeline pulls from.
-- NO external file operations should occur unless configured here.
-- All destinations are relative to input/.
--
-- The sync module just moves files from source to destination.
-- The pipeline scripts already know what to do with files based on where they land.
external_files = {
    {
        name = "words-sync",
        description = "Sync words/notes/fediverse from backup location",
        source = "/home/ritz/backups/words/sync-to-projects",
        destination = "",  -- Empty = runs as script, populates input/ directly
    },
    {
        name = "bluesky-car",
        description = "Latest Bluesky CAR repository file",
        source = "/home/ritz/backups/bluesky/input",
        destination = "bluesky",
        pattern = "repo-*.car",
        select = "newest",
    },
    {
        name = "my-art",
        description = "Artwork made in kolourpaint",
        source = "/home/ritz/pictures/my-art",
        destination = "media_attachments/my-art",
    },
    {
        name = "things-I-almost-posted",
        description = "Finally posting them",
        source = "/home/ritz/pictures/things-i-almost-posted",
        destination = "media_attachments/things-i-almost-posted",
    },
    {
        name = "poem-pictures",
        description = "Pictures I made of my poems",
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
| `source` | Yes | Absolute path to external file, directory, or script |
| `destination` | Yes | Relative path under `input/`. Empty string = source is a script that populates input/ directly |
| `description` | No | Human-readable description |
| `pattern` | No | Glob pattern to filter files (e.g., `"repo-*.car"`) |
| `select` | No | `"newest"`, `"oldest"`, or `"all"` (default: `"all"`) |
| `optional` | No | Default false. If true, missing source shows warning instead of error |

**Behavior:**
- If `destination` is empty string (`""`), the source is executed as a script
- If `destination` is non-empty, rsync copies from `source` to `input/{destination}`
- Scripts already know what to do with files based on their location - no `type` field needed

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

1. [ ] Add `external_files` section to `config.lua`
2. [ ] Create `libs/external-sync.lua` module to process external_files config
3. [ ] Update `scripts/update-words` to use external-sync module (replace hardcoded script call)
4. [ ] Update `scripts/update` to use external-sync module (replace hardcoded Bluesky sync)
5. [ ] Merge `image_sync.sources` entries into `external_files`
6. [ ] Remove deprecated `image_sync.sources` section (keep processing options)
7. [ ] Add `--list-external` CLI flag to show configured external sources
8. [ ] Add `--sync-only NAME` CLI flag to sync a single source
9. [ ] Update `scripts/update-words` to iterate external_files instead of custom logic

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
