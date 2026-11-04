# Issue 604: Asset Deduplication System

**Status:** Completed 2026-11-02 (step 7, the link to the fetcher, is 603's
to make: 603 calls `store_file` on each download).

**Phase:** 6
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 601 (asset loader)
**Blocks:** 603 (the fetcher stores each download by its hash), 604a, 605, 608, 609, W05

---

## Current Behavior

No deduplication exists. If a user connects to 10 servers that all use the same grass texture, they would store 10 copies of that texture.

## Intended Behavior

A hash-based content-addressable storage system that:
1. Stores each unique asset exactly once
2. Uses symlinks or references from server directories to shared storage
3. Dramatically reduces disk usage for users with many servers/maps
4. Makes "already have this asset" checks instant

### Storage Architecture

```
~/.world-edit-engine/
├── blobs/                         # Content-addressable storage
│   ├── ab/                        # First 2 chars of hash
│   │   └── ab3def789...           # Full hash as filename
│   ├── cd/
│   │   └── cd1234567...
│   └── ...
├── servers/
│   └── my-server/
│       ├── manifest.lua
│       └── assets/                # Symlinks to blobs
│           ├── grass.png -> ../../blobs/ab/ab3def789...
│           └── sword.mdx -> ../../blobs/cd/cd1234567...
└── maps/
    └── custom-map-hash/
        └── assets/                # Symlinks to blobs
            └── grass.png -> ../../blobs/ab/ab3def789...
```

### Deduplication Flow

```
NEW ASSET ARRIVES
       │
       ▼
   Hash content
   (SHA-256)
       │
       ▼
   Check blobs/
   for hash
       │
   ┌───┴───┐
   │       │
EXISTS   NEW
   │       │
   │       ▼
   │   Write to
   │   blobs/{hash}
   │       │
   └───┬───┘
       │
       ▼
   Create symlink
   in server/map dir
```

### API Design

```lua
local dedup = require("assets.dedup")

-- Initialize the blob store
dedup.init("~/.world-edit-engine/blobs")

-- Store an asset, returns hash
local hash = dedup.store(asset_data)
-- Returns: "sha256:ab3def789..."

-- Check if asset exists by hash
if dedup.exists("sha256:ab3def789...") then
    -- Already have it
end

-- Get path to blob
local blob_path = dedup.path("sha256:ab3def789...")
-- Returns: "/home/user/.world-edit-engine/blobs/ab/ab3def789..."

-- Link asset into a server/map directory
dedup.link("sha256:ab3def789...", "/path/to/server/assets/grass.png")

-- Get all hashes we have
local all_hashes = dedup.list()
-- Returns: {"sha256:ab3def...", "sha256:cd1234...", ...}

-- Calculate storage savings
local stats = dedup.stats()
-- {
--     unique_blobs = 1000,
--     total_references = 5000,
--     storage_bytes = 524288000,    -- 500 MB actual
--     naive_bytes = 2621440000,     -- 2.5 GB without dedup
--     savings_percent = 80,
-- }

-- Garbage collect unreferenced blobs
local removed = dedup.gc()
-- Returns count of removed blobs
```

### Hash Format

Using SHA-256 for content hashing:
- Collision-resistant for practical purposes
- Standard, well-supported
- Prefix with `sha256:` for future algorithm flexibility

## Suggested Implementation Steps

1. Create `src/assets/dedup.lua` with core API
2. Implement blob storage with sharded directories (2-char prefix)
3. Implement hash calculation (using LuaJIT FFI or external lib)
4. Implement symlink creation (cross-platform consideration)
5. Implement reference tracking (which servers/maps use which blobs)
6. Implement garbage collection (remove unreferenced blobs)
7. Integrate with download protocol (Issue 603)
8. Create tests for storage, linking, and GC

## Acceptance Criteria

- [x] Assets stored once regardless of how many servers use them
- [x] SHA-256 hashing of asset content
- [x] Sharded blob directory (blobs/ab/ab3def...) for filesystem performance
- [x] Symlink creation works on Linux (Windows may need alternative)
- [x] `dedup.exists(hash)` is O(1) lookup
- [x] `dedup.list()` returns all stored hashes efficiently
- [x] Garbage collection removes orphaned blobs
- [x] Stats accurately report storage savings
- [x] Reference counting tracks which servers/maps use each blob

## Related Documents

- Issue 601 - Asset loader (reads from deduped storage)
- Issue 603 - Download protocol (uses dedup to check what client has)
- Issue 605 - Storage manager (uses dedup stats)

## Notes

- Windows doesn't support symlinks well for non-admin users; may need to use hardlinks or copy-on-write
- Consider using a small SQLite database for reference tracking instead of filesystem scanning
- Sharding (ab/ab3def...) prevents too many files in one directory
- GC should be explicit, not automatic (user controls when to reclaim space)
- May want "pin" feature to prevent GC from removing certain assets

---

## Implementation Notes

**Date:** 2026-11-02

- **`src/assets/dedup.lua`:** the store, with the API above as methods
  (`dedup.open(folder)` gives a store) and as module functions after
  `dedup.init(folder)`, as sketched. Besides the sketch: `store_file(path)`
  (reads a large map in pieces), `release(dest)`, `references(hash)`,
  `refcount(hash)`, `pin`/`unpin`/`pinned` (from the Notes) and `verify()`
  (hashes every blob again). `src/assets/dedup.info.md` describes it.
- **`src/assets/player_data.lua`:** where the player data folder is, which
  gives the store its default folder (see decision 1).
- **`src/tests/test_dedup.lua`** (61 tests): the standard SHA-256 of `abc`
  and of nothing; one blob for the same bytes stored twice; `store_file`
  and `sha256sum` agree on a 200 KB file and on a test map; ten maps
  linking one texture make one blob and ten references; a real file is
  never replaced; relinking moves a reference; deleting a map's folder
  drops its references; exact `stats()` numbers, including 80% for one
  copy where five would be; the store reads back after a restart; `gc()`
  removes only unlinked, unpinned blobs and empties their shard folders;
  `verify()` finds a changed blob; moving the whole folder keeps links and
  references; a map opens through its link; and the player data folder's
  default and config-file cases, including a broken config file.
- **Full suite:** as before, with `test_net_hosted` the one failure (it
  needs the `effil` library from the owner's machine).

### Decisions made while building

1. **The player data folder is `<project>/player-data/`, and the config
   file that moves it is `<project>/config/player-data.lua`**, returning
   `{ folder = "PATH" }`. This answers the part of issue 601's open
   question 1 left open on 2026-09-26 (the folder's name, and where the
   config file lives). Git ignores both: the folder holds the player's own
   files, and the config file holds a path on their own machine. Lua was
   chosen for the config file because the rest of the project's settings
   are Lua tables; `config/` follows delta-version's config folder. The
   store's default folder is `<player data>/blobs`.
2. **Built ahead of 601.** The dependency was on 601's folder, not its
   loader; with the folder settled here, the store needs nothing else.
3. **The monorepo's own SHA-256** (`burner-of-down-things/src/015-sha-256.lua`)
   is loaded by relative path on first use, the way `parsers/png.lua` loads
   the kanji project's inflate, rather than copied in. It agrees with
   `sha256sum` on every test file and hashes a 13 MB map in 0.2 s.
4. **References are the links themselves**, with a plain `references` file
   recording which links were made (no SQLite, which the Notes floated: the
   project has no SQLite binding, and it would be a new dependency). A
   reference counts while its link is in place and leads to the blob, so
   deleting a map's folder needs no call, and 605's "delete a map" is
   `rm -rf` plus `gc()`.
5. **Links are relative**, and so are the reference lines, so moving the
   whole player data folder (which the config file allows) breaks nothing.
6. **`list()` reads an index file** rather than walking 256 folders, and
   `exists()` opens one path. `gc()` rewrites the index; `verify()` is the
   check that the index and the blobs still agree.
7. **A real file is never replaced by a link**; a link already there is
   replaced (that is what linking a path means). Linking a path that
   already leads to the blob changes nothing.
8. **Blobs are written to `incoming/` and renamed into place**, so a crash
   never leaves a half-written blob under a good name, and `store_file`
   hashes its copy again before keeping it, so a file changed while it was
   read is refused.
9. **Linux only for now.** The project runs on Linux; links are made with
   `symlink(2)` through the FFI. Windows would need another way, and no
   Windows build exists to test one.
