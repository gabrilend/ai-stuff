# Issue 605: Local Storage Manager

**Status:** Completed 2026-11-02. "Servers" are asset packs here (see
decision 1); the TUI (step 7, optional) is not built.

**Phase:** 6
**Type:** Implementation
**Priority:** Medium
**Dependencies:** Issue 604 (deduplication), Issue 601 (its folder only)
**Blocks:** 603 (the fetcher's downloads land in the storage this manages), 604a, 608, 609

---

## Current Behavior

No storage management exists. Users have no way to:
- See how much space each asset pack/map is using
- Delete assets for packs they no longer use
- Understand their total engine storage footprint

## Intended Behavior

A storage management system that:
1. Tracks storage usage per asset pack and per map
2. Allows users to delete asset pack/map data at will
3. Shows deduplication savings (actual vs naive storage)
4. Provides both CLI and programmatic access

### Storage View

```
World Edit Engine Storage
═════════════════════════════════════════════════════════
Total: 2.3 GB (would be 8.1 GB without deduplication)
Savings: 5.8 GB (72%)

ASSET PACKS                                  SIZE    UNIQUE
─────────────────────────────────────────────────────────
  community-medieval-assets-v1              450 MB   120 MB
  custom-td-assets                          380 MB    45 MB
  fantasy-hero-pack                         120 MB   120 MB

MAPS                                         SIZE    UNIQUE
─────────────────────────────────────────────────────────
  Castle Fight v3.2.w3x                      85 MB    30 MB
  DotA Allstars 6.88.w3x                    120 MB    40 MB
  Footmen Frenzy 5.5.w3x                     65 MB    15 MB

SHARED BLOBS                                980 MB
(assets used by multiple packs/maps)

[D] Delete selected  [R] Refresh  [G] Garbage collect  [Q] Quit
```

### API Design

```lua
local storage = require("assets.storage")

-- Get overview of all storage
local overview = storage.overview()
-- {
--     total_bytes = 2469606195,
--     naive_bytes = 8702255513,
--     savings_bytes = 6232649318,
--     savings_percent = 72,
--     servers = {...},
--     maps = {...},
-- }

-- Get storage for a specific server
local server_info = storage.server_info("my-wow-server.com")
-- {
--     name = "my-wow-server.com",
--     total_bytes = 471859200,
--     unique_bytes = 125829120,    -- Assets not shared with others
--     shared_bytes = 346030080,    -- Assets shared with others
--     asset_count = 1523,
--     last_connected = 1704067200,
-- }

-- List all servers
local servers = storage.list_servers()

-- List all maps
local maps = storage.list_maps()

-- Delete a server's assets
local freed = storage.delete_server("old-server.com")
-- Returns bytes freed (only unique assets, shared ones remain)

-- Delete a map's assets
local freed = storage.delete_map("outdated-map.w3x")

-- Run garbage collection after deletions
local gc_freed = storage.gc()

-- Get orphaned blobs (no references)
local orphans = storage.find_orphans()
-- Returns list of hashes that can be safely deleted
```

### CLI Tool

```bash
# Show storage overview
./world-edit-engine storage

# Show detailed view
./world-edit-engine storage --detail

# Delete a server
./world-edit-engine storage delete server my-wow-server.com
# Are you sure? This will free ~120 MB. [y/N]

# Delete a map
./world-edit-engine storage delete map "Castle Fight v3.2.w3x"

# Garbage collect
./world-edit-engine storage gc
# Removed 15 orphaned blobs, freed 45 MB

# Export storage report
./world-edit-engine storage report > storage-report.txt
```

## Suggested Implementation Steps

1. Create `src/assets/storage.lua` with tracking API
2. Implement server/map metadata storage (SQLite or Lua files)
3. Implement storage calculation (aggregate from dedup system)
4. Implement unique vs shared calculation
5. Implement deletion with proper cleanup
6. Create CLI interface in `src/cli/storage.lua`
7. Create TUI for interactive management (optional)
8. Create tests for calculations and deletion

## Acceptance Criteria

- [x] `storage.overview()` returns accurate total and per-source stats
- [x] Unique vs shared byte calculation is correct
- [x] Server deletion removes server directory and decrements blob references (asset packs: decision 1)
- [x] Map deletion removes map directory and decrements blob references
- [x] GC after deletion reclaims unreferenced blobs
- [x] CLI provides all management operations
- [x] Deletion requires confirmation (unless --force)
- [x] Last-connected timestamp tracked for servers (last used, for maps and packs: decision 1)

## Related Documents

- Issue 604 - Deduplication (source of blob data)
- Issue 601 - Asset loader (reads from managed storage)

## Notes

- "Unique bytes" = assets only used by this server/map
- "Shared bytes" = assets also used elsewhere (won't be freed on delete)
- Consider tracking "last accessed" per blob for smart cleanup suggestions
- May want "archive" vs "delete" - archive just removes from active, keeps blobs
- TUI could show which servers share assets with each other
- Could add "clean up servers not accessed in 30 days" command

---

## Implementation Notes

**Date:** 2026-11-02

- **`src/assets/storage.lua`:** the manager over the player data folder:
  `put`/`put_file` (store once and link in, as 603 will), `touch`, `names`,
  `info`, `list`, `overview`, `delete`, `gc`, `orphans`, and `storage.size`
  for readable sizes. `storage.info.md` describes it.
- **`src/cli/storage.lua`:** the overview (`--detail`, `report`), `delete
  map|pack NAME [--force]`, `gc` and `orphans`; `storage.info.md` beside it.
- **`src/assets/dedup.lua`:** two methods for it, `refcounts()` (every
  blob's live links in one pass) and `orphans()`.
- **`src/tests/test_storage.lua`** (47 tests): two maps and a pack sharing
  files give exact total, unique and shared bytes (a file linked twice in
  one map counts once; a pinned file isn't freeable; a plain file is the
  map's own); the overview's totals, savings and shared bytes; names that
  can't be folders are refused; last-used times survive a restart; deleting
  a map frees exactly its own bytes once collected while the others still
  read; and the tool shows the same numbers with its rows lined up, deletes
  nothing on "n" or no answer, deletes on "y" or `--force`, and says so for
  a map that isn't there. `test_dedup.lua` gained a test of `orphans` and
  `refcounts` (62).

### Decisions made while building

1. **Asset packs instead of servers, "last used" instead of "last
   connected".** Since 2026-09-26 nothing is server-provided (601's note):
   files come from the map, the player's install, community asset packs
   (fetched by 603) and other players over rmail (609). The manager keeps
   maps and asset packs, each a folder under the player data folder
   (`maps/<name>/`, `asset-packs/<name>/`), and records when each was last
   used (`touch`, and every `put`).
2. **No metadata database.** A source is its folder; its sizes come from
   its links and the store's index, so nothing can disagree with the
   files. The only file of its own is `last-used`.
3. **"Unique" means what deleting frees:** stored files no other map, pack
   or link uses, and not pinned (604's pins keep a file through `gc`), plus
   the plain files in the folder. A file linked twice in one source counts
   once in its size.
4. **`delete` removes the folder; blobs go at `gc()`**, as 604 decided (gc
   only when called). `delete` returns the bytes that frees in all. The
   command line's `delete` does both, after asking, so the space is freed
   at once.
5. **No answer is a no.** With no terminal to ask (a script, a pipe that
   ends) and no `--force`, nothing is deleted.
6. **The command is `luajit src/cli/storage.lua`**, like the project's other
   tools; there is no `world-edit-engine` program to hang a subcommand on.
7. **The TUI (step 7) isn't built:** it was optional, and the overview,
   `report` and `delete` cover what it would show and do.
