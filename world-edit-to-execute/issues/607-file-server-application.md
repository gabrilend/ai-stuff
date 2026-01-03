# Issue 607: File Server Application

**Phase:** 6
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 603 (download protocol), Issue 604 (deduplication)

---

## Current Behavior

No file server exists. Hosts cannot distribute assets to connecting clients.

## Intended Behavior

A standalone file server application that:
1. Serves assets to clients using the custom download protocol (Issue 603)
2. Can run alongside game server or separately
3. Generates and serves manifests
4. Handles multiple concurrent clients
5. Supports both WC3 map hosting and WoW-style server hosting

### Deployment Options

```
OPTION A: Integrated (simple)
┌─────────────────────────────────────┐
│         Game Server Host            │
│  ┌─────────────┐  ┌──────────────┐  │
│  │ Game Server │  │ File Server  │  │
│  │  (port 6112)│  │  (port 7878) │  │
│  └─────────────┘  └──────────────┘  │
│         ▲                ▲          │
└─────────┼────────────────┼──────────┘
          │                │
     Game traffic    Asset downloads

OPTION B: External (scalable)
┌──────────────┐        ┌──────────────┐
│ Game Server  │        │ File Server  │
│ (any host)   │        │ (CDN/cloud)  │
└──────────────┘        └──────────────┘
       │                       ▲
       │  "assets at           │
       │   files.example.com"  │
       └───────────────────────┘
          Client redirected
```

### CLI Interface

```bash
# Serve assets from a directory
./world-edit-fileserver serve ./my-server-assets/
# Listening on 0.0.0.0:7878
# Serving 1,523 assets (450 MB)

# Specify port
./world-edit-fileserver serve ./assets/ --port 8080

# Generate manifest only (for external CDN hosting)
./world-edit-fileserver manifest ./assets/ > manifest.lua

# Validate asset directory
./world-edit-fileserver validate ./assets/
# ✓ 1,523 assets found
# ✓ All files readable
# ✓ Manifest generated

# Show server status
./world-edit-fileserver status
# Connected clients: 3
# Bytes served: 1.2 GB
# Active transfers: 2

# Serve a WC3 map's assets
./world-edit-fileserver serve-map ./my-custom-map.w3x
# Extracting assets from MPQ...
# Listening on 0.0.0.0:7878
# Serving 85 assets (45 MB)
```

### Server Architecture

```lua
-- Server main loop pseudocode
while running do
    -- Accept new connections
    local client = server:accept()
    if client then
        spawn_handler(client)
    end

    -- Process active transfers
    for _, handler in ipairs(active_handlers) do
        handler:tick()
    end

    -- Collect finished handlers
    cleanup_finished()
end
```

### Configuration

```lua
-- fileserver.conf.lua
return {
    port = 7878,
    bind = "0.0.0.0",

    -- Asset source
    assets_dir = "./assets/",
    -- OR
    map_file = "./custom-map.w3x",

    -- Limits
    max_clients = 50,
    max_concurrent_transfers = 10,
    bandwidth_limit_kbps = 0,  -- 0 = unlimited

    -- Chunk settings
    chunk_size = 65536,  -- 64 KB

    -- Compression
    compress = true,
    compression_level = 6,

    -- Logging
    log_file = "./fileserver.log",
    log_level = "info",
}
```

### API (for programmatic use)

```lua
local fileserver = require("assets.fileserver")

-- Create server instance
local server = fileserver.new({
    assets_dir = "./assets/",
    port = 7878,
})

-- Start serving (blocks)
server:run()

-- Or integrate with existing event loop
server:start()  -- Non-blocking
while game_running do
    server:tick()
    -- ... other game logic
end
server:stop()

-- Get statistics
local stats = server:stats()
-- {
--     clients_connected = 3,
--     bytes_served = 1288490188,
--     active_transfers = 2,
--     uptime_seconds = 3600,
-- }
```

## Suggested Implementation Steps

1. Create `src/assets/fileserver.lua` with core server logic
2. Implement connection handling (non-blocking sockets)
3. Implement manifest generation from asset directory
4. Implement manifest generation from MPQ file
5. Implement chunked transfer logic
6. Implement compression (optional, configurable)
7. Create CLI wrapper `src/cli/fileserver.lua`
8. Implement bandwidth throttling (optional)
9. Implement logging
10. Create tests (mock client connections)

## Acceptance Criteria

- [ ] Server starts and listens on configured port
- [ ] Manifest sent to connecting clients
- [ ] Assets served in chunks as requested
- [ ] Multiple concurrent clients supported
- [ ] Resumable transfers work (client reconnects mid-download)
- [ ] Can serve from directory or from WC3 map MPQ
- [ ] CLI provides serve, manifest, validate, status commands
- [ ] Graceful shutdown (finish active transfers, then exit)
- [ ] Logging of connections and transfers

## Related Documents

- Issue 603 - Download protocol (client-side)
- Issue 604 - Deduplication (client uses this to report what it has)

## Notes

- Consider using LuaSocket or LuaJIT FFI for networking
- May want "dry run" mode that shows what would be served without actually running
- Could add simple web dashboard for monitoring (separate enhancement)
- For WC3 maps, assets are extracted to temp dir then served
- Bandwidth limiting useful for hosts with limited upload
- Could integrate with existing game server as a module (not just standalone)
