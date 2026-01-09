# Issue 603: LAN Asset Download Protocol

**Phase:** 6
**Type:** Implementation
**Priority:** Critical
**Dependencies:** Issue 601 (asset loader), Issue 604 (deduplication)

---

## Current Behavior

No asset download system exists. Players cannot receive community asset packs from:
- LAN hosts sharing custom WC3 maps with custom asset packs
- Matchmaking servers distributing common asset collections

## Intended Behavior

A peer-to-peer asset download protocol that:
1. Transfers community asset packs from LAN host to clients on connect
2. Supports resumable downloads (connection drops shouldn't restart)
3. Integrates with deduplication (don't re-download assets already present)
4. Shows download progress to the user
5. Works for both direct LAN connections and matchmaking server-facilitated transfers

### Protocol Overview

```
CLIENT                              SERVER/HOST
   │                                    │
   ├──── CONNECT ──────────────────────▶│
   │                                    │
   │◀─── MANIFEST ─────────────────────┤  (list of assets + hashes)
   │                                    │
   ├──── HAVE [hash1, hash2, ...] ─────▶│  (assets client already has)
   │                                    │
   │◀─── NEED [hash3, hash4, ...] ─────┤  (assets to download)
   │                                    │
   ├──── REQUEST hash3 ────────────────▶│
   │◀─── CHUNK hash3 offset data ──────┤  (chunked transfer)
   │◀─── CHUNK hash3 offset data ──────┤
   │◀─── DONE hash3 ───────────────────┤
   │                                    │
   ├──── REQUEST hash4 ────────────────▶│
   │     ...                            │
   │                                    │
   ├──── READY ────────────────────────▶│  (all assets received)
   │                                    │
   │◀─── GAME_START ───────────────────┤
```

### Manifest Format

```lua
-- manifest.lua (host-side)
return {
    version = 1,
    host_id = "custom-td-map-v3",
    map_name = "Epic Tower Defense",
    asset_pack = "community-medieval-assets-v1",
    assets = {
        {
            path = "textures/terrain/grass.png",
            hash = "sha256:abc123...",
            size = 102400,
            priority = "required",    -- required, optional, streaming
        },
        {
            path = "models/units/knight.mdx",
            hash = "sha256:def456...",
            size = 524288,
            priority = "required",
        },
        -- ...
    },
    total_size = 52428800,  -- 50 MB total
}
```

### Priority Levels

| Priority | Behavior |
|----------|----------|
| `required` | Must download before game starts |
| `optional` | Download in background, use fallback until ready |
| `streaming` | Download on-demand when asset is first needed |

### Client API

```lua
local downloader = require("assets.downloader")

-- Connect to host and start download
downloader.connect({
    host = "192.168.1.100",
    port = 7878,
    on_progress = function(current, total, current_file)
        print(string.format("Downloading: %d/%d MB - %s",
            current / 1024 / 1024,
            total / 1024 / 1024,
            current_file))
    end,
    on_complete = function()
        print("All assets downloaded!")
    end,
    on_error = function(err)
        print("Download failed: " .. err)
    end,
})

-- Check download status
local status = downloader.status()
-- { state = "downloading", progress = 0.75, speed_kbps = 1024 }

-- Cancel download
downloader.cancel()

-- Resume interrupted download
downloader.resume()
```

## Suggested Implementation Steps

1. Design wire protocol (binary format for efficiency)
2. Implement `src/assets/protocol.lua` - message encoding/decoding
3. Implement `src/assets/downloader.lua` - client-side download manager
4. Implement chunk storage for resumable downloads
5. Integrate with deduplication system (Issue 604)
6. Implement progress reporting and UI hooks
7. Create mock server for testing
8. Test resumable downloads (simulate disconnection)

## Acceptance Criteria

- [ ] Client receives manifest on connect
- [ ] Client reports already-owned assets (by hash)
- [ ] Server only sends assets client needs
- [ ] Downloads are chunked (configurable chunk size, default 64KB)
- [ ] Interrupted downloads resume from last chunk
- [ ] Progress callback fires with accurate stats
- [ ] Required assets block game start until complete
- [ ] Optional/streaming assets use fallback while downloading
- [ ] Download speed is reasonable (not artificially throttled)

## Related Documents

- Issue 601 - Asset loader (destination for downloaded assets)
- Issue 604 - Deduplication (determines what client already has)
- Issue 607 - File server application (server-side implementation)

## Notes

- Consider compression for transfer (gzip/lz4) - tradeoff between CPU and bandwidth
- Chunk size should be tunable for different network conditions
- May want parallel downloads for multiple small files
- Error handling: corrupt chunk detection via hash verification
- Security: validate asset hashes, reject mismatched data
