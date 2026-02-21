# Issue 16-001a: Termux + Lua Server Implementation

## Priority
High (Implementation)

## Parent Issue
16-001: Android File Server — Vision

## Current Behavior

No file server exists on Android. Lua scripts run on the desktop only. Photos and videos on Android devices are inaccessible over the network without manual transfer or third-party apps.

## Intended Behavior

Implement a Lua-based HTTPS file server that runs in Termux on Android. The server scans configured directories, indexes media files, and serves them via API endpoints.

### CLI Interface

```bash
# Basic usage
lua android-server.lua

# With options
lua android-server.lua --port 8443 --dir /sdcard/DCIM/Camera --cert ./server.crt --key ./server.key

# Background mode
nohup lua android-server.lua &
```

### Command Line Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `--port` | 8443 | HTTPS listening port |
| `--dir` | /sdcard/DCIM/Camera | Directory to scan for media |
| `--dirs` | - | Comma-separated list of directories |
| `--cert` | ./server.crt | Path to SSL certificate |
| `--key` | ./server.key | Path to SSL private key |
| `--thumbnail-size` | 256 | Max dimension for thumbnails |
| `--rescan-interval` | 300 | Seconds between directory rescans |
| `--bind` | 0.0.0.0 | Interface to bind to |

### Core Script Structure

```lua
#!/usr/bin/env lua
-- android-server.lua
-- A Lua-based HTTPS file server for Android/Termux
-- Scans media directories and serves files via REST API

local DIR = "/data/data/com.termux/files/home/android-server"

-- {{{ local function parse_arguments
local function parse_arguments(args)
    local config = {
        port = 8443,
        dirs = {"/sdcard/DCIM/Camera"},
        cert = DIR .. "/server.crt",
        key = DIR .. "/server.key",
        thumbnail_size = 256,
        rescan_interval = 300,
        bind = "0.0.0.0"
    }

    local i = 1
    while i <= #args do
        if args[i] == "--port" then
            config.port = tonumber(args[i+1])
            i = i + 2
        elseif args[i] == "--dir" then
            config.dirs = {args[i+1]}
            i = i + 2
        elseif args[i] == "--dirs" then
            config.dirs = split(args[i+1], ",")
            i = i + 2
        -- ... additional argument parsing
        else
            i = i + 1
        end
    end

    return config
end
-- }}}

-- {{{ local function scan_directory
local function scan_directory(path, file_list)
    -- Recursively scan for .jpg, .jpeg, .png, .mp4, .mov, etc.
    local handle = io.popen('find "' .. path .. '" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.mp4" -o -iname "*.mov" -o -iname "*.webm" \\) 2>/dev/null')

    for file_path in handle:lines() do
        local id = generate_file_id(file_path)
        file_list[id] = {
            path = file_path,
            id = id,
            filename = extract_filename(file_path),
            timestamp = get_file_timestamp(file_path),
            size = get_file_size(file_path),
            type = get_media_type(file_path)
        }
    end

    handle:close()
    return file_list
end
-- }}}

-- {{{ local function start_https_server
local function start_https_server(config, file_index)
    local socket = require("socket")
    local ssl = require("ssl")

    local ssl_params = {
        mode = "server",
        protocol = "tlsv1_2",
        key = config.key,
        certificate = config.cert,
        verify = "none",
        options = "all"
    }

    local server = assert(socket.bind(config.bind, config.port))
    print(string.format("[SERVER] Listening on https://%s:%d", config.bind, config.port))

    while true do
        local client = server:accept()
        if client then
            local ssl_client = ssl.wrap(client, ssl_params)
            ssl_client:dohandshake()
            handle_request(ssl_client, file_index, config)
            ssl_client:close()
        end
    end
end
-- }}}

-- {{{ local function handle_request
local function handle_request(client, file_index, config)
    local request = client:receive("*l")
    if not request then return end

    local method, path = request:match("^(%w+)%s+(/[^%s]*)%s+HTTP")
    if not method or not path then return end

    -- Route handling
    if path == "/api/list" then
        serve_file_list(client, file_index)
    elseif path == "/api/count" then
        serve_file_count(client, file_index)
    elseif path:match("^/api/file/") then
        local id = path:match("^/api/file/(.+)$")
        serve_file(client, file_index, id)
    elseif path:match("^/api/thumbnail/") then
        local id = path:match("^/api/thumbnail/(.+)$")
        serve_thumbnail(client, file_index, id, config.thumbnail_size)
    elseif path:match("^/api/metadata/") then
        local id = path:match("^/api/metadata/(.+)$")
        serve_metadata(client, file_index, id)
    else
        serve_404(client, path)
    end
end
-- }}}

-- Main execution
local config = parse_arguments(arg)
local file_index = {}

for _, dir in ipairs(config.dirs) do
    print(string.format("[SCAN] Scanning %s...", dir))
    scan_directory(dir, file_index)
end

print(string.format("[SCAN] Found %d media files", count_table(file_index)))
start_https_server(config, file_index)
```

### Termux Setup Requirements

```bash
# Install Termux from F-Droid (not Play Store for full functionality)

# Update packages
pkg update && pkg upgrade

# Install Lua and dependencies
pkg install lua54 luarocks openssl

# Install Lua libraries
luarocks install luasocket
luarocks install luasec
luarocks install lua-cjson

# Grant storage permission (required for /sdcard access)
termux-setup-storage

# Generate self-signed certificate (see 16-001d)
openssl req -x509 -newkey rsa:2048 -keyout server.key -out server.crt -days 365 -nodes
```

### File ID Generation

Use SHA256 hash of file path for stable, unique IDs:

```lua
-- {{{ local function generate_file_id
local function generate_file_id(file_path)
    -- Simple hash: use file path + size + mtime
    local stat = get_file_stat(file_path)
    local input = file_path .. ":" .. stat.size .. ":" .. stat.mtime

    -- Use openssl for hashing if available
    local handle = io.popen('printf "%s" "' .. input .. '" | sha256sum | cut -c1-16')
    local hash = handle:read("*l")
    handle:close()

    return hash
end
-- }}}
```

### JSON Response Examples

```json
// GET /api/list
{
    "files": [
        {
            "id": "a1b2c3d4e5f6g7h8",
            "filename": "IMG_20260215_143022.jpg",
            "timestamp": "2026-02-15T14:30:22",
            "size": 4523678,
            "type": "image/jpeg",
            "thumbnail_url": "/api/thumbnail/a1b2c3d4e5f6g7h8",
            "file_url": "/api/file/a1b2c3d4e5f6g7h8"
        },
        // ...
    ],
    "count": 1247,
    "scanned_at": "2026-02-20T10:00:00"
}

// GET /api/count
{
    "total": 1247,
    "images": 1102,
    "videos": 145
}
```

## Suggested Implementation Steps

1. **Setup Termux environment**
   - Install required packages
   - Verify storage access
   - Test basic Lua execution

2. **Implement argument parser**
   - Parse CLI flags
   - Validate paths and ports
   - Set defaults

3. **Implement directory scanner**
   - Find media files recursively
   - Extract basic metadata
   - Generate file IDs

4. **Implement HTTPS server**
   - Basic socket listener
   - SSL/TLS wrapping
   - Request parsing

5. **Implement API routes**
   - `/api/list` — Full file listing
   - `/api/count` — File counts
   - `/api/file/:id` — File serving
   - `/api/thumbnail/:id` — Thumbnail generation
   - `/api/metadata/:id` — Single file metadata

6. **Add background rescan**
   - Periodic directory check
   - Update index without restart
   - Handle new/deleted files

## Testing Checklist

- [ ] Server starts and binds to port
- [ ] `/api/list` returns JSON with all files
- [ ] `/api/file/:id` returns correct binary content
- [ ] `/api/thumbnail/:id` returns scaled image
- [ ] HTTPS works (browser shows cert warning but connects)
- [ ] Storage permission allows /sdcard access
- [ ] Background mode persists after terminal close

## Related Documents

- 16-001: Android File Server — Vision
- 16-001d: HTTPS with self-signed certificates
- Termux documentation: https://wiki.termux.com

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Parent**: 16-001
- **Estimated Complexity**: Medium-High
- **Dependencies**: Termux, luasocket, luasec
