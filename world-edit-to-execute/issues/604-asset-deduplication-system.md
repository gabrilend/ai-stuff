# Issue 604: Asset Deduplication System

**Phase:** 6
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 601 (asset loader)

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

- [ ] Assets stored once regardless of how many servers use them
- [ ] SHA-256 hashing of asset content
- [ ] Sharded blob directory (blobs/ab/ab3def...) for filesystem performance
- [ ] Symlink creation works on Linux (Windows may need alternative)
- [ ] `dedup.exists(hash)` is O(1) lookup
- [ ] `dedup.list()` returns all stored hashes efficiently
- [ ] Garbage collection removes orphaned blobs
- [ ] Stats accurately report storage savings
- [ ] Reference counting tracks which servers/maps use each blob

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
