# Issue 16-001: Android File Server — Vision

## Priority
Vision (Phase Foundation)

## Phase 16: Network Media Integration

> *The phone holds the memories. The server shares them. The timeline weaves them into the tapestry.*

## Current Behavior

The neocities modernization project generates chronological and similar/different HTML pages from local files. These files are of type "text" (poems) or type "image" (local images). All file sources are assumed to be local filesystem paths that can be read directly during HTML generation.

Photos and videos captured on Android devices exist in separate silos, requiring manual transfer (USB, cloud sync) before they can be integrated into the timeline. There is no live access to mobile device media.

## Intended Behavior

Implement an Android-based file server that serves photos and videos over WiFi via HTTPS. This server integrates with the existing HTML generation pipeline as a new file source type: "network".

### Core Features

1. **Dual-mode server operation**
   - CLI mode via Termux + Lua (consistent with project's Lua preference)
   - GUI mode via native Android app with background service
   - Both modes expose identical HTTPS API endpoints

2. **Network file type integration**
   - New `type: network` alongside existing `type: text` and `type: image`
   - Photos/videos appear in chronological.html and similar/different pages
   - Links point to HTTPS endpoints rather than local file paths

3. **HTTPS with self-signed certificates**
   - Secure transfer over WiFi (encrypted even without CA validation)
   - Trust warning intermediate page before displaying media
   - "trust-me" link proceeds to actual content

4. **Chronological back-navigation**
   - Back button returns user to exact position in timeline
   - Position determined by photo's EXIF timestamp
   - Anchor-based navigation: `chronological.html#2026-02-15-143022`

### Server Architecture

```
+------------------------------------------+
|           Android Device                 |
|                                          |
|  +----------------+  +----------------+  |
|  | Termux + Lua   |  | Native App     |  |
|  | (CLI mode)     |  | (GUI mode)     |  |
|  +-------+--------+  +--------+-------+  |
|          |                    |          |
|          +--------+----------+           |
|                   |                      |
|           +-------v--------+             |
|           | HTTPS Server   |             |
|           | Port 8443      |             |
|           +-------+--------+             |
|                   |                      |
|           +-------v--------+             |
|           | File Scanner   |             |
|           | DCIM/Camera    |             |
|           +----------------+             |
+------------------------------------------+
            |
            | WiFi (HTTPS)
            v
+------------------------------------------+
|           Desktop/Browser                |
|                                          |
|   GET /api/list                          |
|   -> JSON: [{id, timestamp, thumbnail}]  |
|                                          |
|   GET /api/file/:id                      |
|   -> Binary: photo/video content         |
|                                          |
|   GET /api/thumbnail/:id                 |
|   -> Binary: scaled preview              |
+------------------------------------------+
```

### API Endpoints

| Endpoint | Method | Response | Description |
|----------|--------|----------|-------------|
| `/api/list` | GET | JSON | List all available photos/videos with metadata |
| `/api/count` | GET | JSON | Count of files by type |
| `/api/file/:id` | GET | Binary | Full-resolution media file |
| `/api/thumbnail/:id` | GET | Binary | Scaled thumbnail for previews |
| `/api/metadata/:id` | GET | JSON | EXIF/metadata for single file |

### HTML Generation Integration

```lua
-- Example integration in html-generator.lua
-- {{{ local function generate_chronological_entry
local function generate_chronological_entry(entry)
    if entry.type == "text" then
        return generate_text_entry(entry)
    elseif entry.type == "image" then
        return generate_image_entry(entry)
    elseif entry.type == "network" then
        -- New network type!
        return generate_network_entry(entry)
    end
end
-- }}}

-- {{{ local function generate_network_entry
local function generate_network_entry(entry)
    -- Link goes to trust warning page, not directly to image
    local trust_page = string.format(
        "trust-warning.html?url=%s&back=%s",
        url_encode(entry.https_url),
        url_encode(entry.chronological_anchor)
    )

    return string.format([[
        <div class="entry network">
            <a href="%s">
                <img src="%s" alt="%s" />
            </a>
            <span class="timestamp">%s</span>
        </div>
    ]], trust_page, entry.thumbnail_url, entry.filename, entry.timestamp)
end
-- }}}
```

### Trust Warning Page

The intermediate page protects users from unexpected HTTPS warnings:

```html
<!-- trust-warning.html -->
<html>
<head><title>Secure Connection Notice</title></head>
<body>
    <div class="navigation">
        <a href="chronological.html#{{ANCHOR}}" class="back">Back</a>
        <span class="spacer"></span>
        <a href="chronological.html#{{ANCHOR}}" class="back">Back</a>
    </div>

    <div class="warning">
        <h2>HTTPS Notice</h2>
        <p>This content is secured with HTTPS, but I don't have
           a certificate authority so...</p>
        <a href="{{ACTUAL_URL}}" class="proceed">trust-me</a>
    </div>
</body>
</html>
```

### Directory Structure

```
output/
├── chronological/
│   ├── page-001.html       # Now includes type:network entries
│   ├── page-002.html
│   └── ...
├── similar/
│   └── ...                 # Network entries integrated here too
├── trust/
│   ├── warning.html        # Template
│   └── generated/          # Per-file trust pages (or dynamic via JS)
└── network-manifest.json   # Cached list from Android server
```

## Suggested Sub-Issues

1. **16-001a: Termux + Lua server implementation**
   - Install Lua in Termux
   - Implement HTTP/HTTPS server using luasocket or similar
   - CLI argument parsing for port, directory, etc.

2. **16-001b: Native Android background service**
   - Android app with start/stop toggle
   - Notification showing server status
   - Settings for port, directories, password

3. **16-001c: Network file type integration**
   - Add `type: network` to HTML generator
   - Modify chronological pipeline to accept network sources
   - Generate entries pointing to HTTPS endpoints

4. **16-001d: HTTPS with self-signed certificates**
   - Generate self-signed cert on first run
   - Configure server to use TLS
   - Handle browser warnings gracefully

5. **16-001e: Trust warning intermediate page**
   - Design warning page HTML
   - Include both back buttons (top-left, top-right)
   - "trust-me" link to actual content

6. **16-001f: Chronological position-aware back navigation**
   - Extract EXIF timestamp from photos
   - Generate anchor IDs matching timestamp format
   - Back button targets correct anchor in chronological.html

## Technical Considerations

### Slow WiFi Transfer
The user noted transfers will be "(slowly)" — the server should:
- Support resumable downloads (Range headers)
- Generate thumbnails for quick previews
- Stream large videos rather than buffer entirely

### File Discovery
Scan common Android media directories:
- `/sdcard/DCIM/Camera/`
- `/sdcard/DCIM/Screenshots/`
- `/sdcard/Pictures/`
- `/sdcard/Movies/`
- Configurable additional paths

### Background Execution
Android background services have restrictions. Options:
- Foreground service with persistent notification
- WorkManager for periodic file indexing
- Termux:Boot for auto-start

### Lua Libraries Required
- `luasocket` — TCP/HTTP server basics
- `lua-sec` — TLS/SSL support
- `lua-cjson` — JSON encoding
- Custom or `luaposix` — File system operations

## Original Request Context

> Hi can we create issue files for a new phase which is adding an android-based fileserver that will (slowly) transmit data over wifi to anyone who asks? it should give specifically the photos and videos taken by the camera. presumably, someone will download them and view them somehow or share them if they'd like. we will do this by scanning the director[y/ies] of files that we want to share and counting them. Then, we will make one API endpoint for the HTTPS server that will send them to the person who requested it by clicking an HTML link on a website.

## Related Documents

- `src/html-generator.lua` — Existing HTML generation infrastructure
- `output/chronological/` — Chronological page output
- Phase 8: HTML generation and pagination
- Phase 9: Performance optimizations (relevant for large file transfers)

## Metadata

- **Status**: Open (Vision)
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: High (dual-mode server + pipeline integration)
- **Dependencies**: HTML generation infrastructure (Phase 8)
- **Blocks**: 16-001a through 16-001f (sub-issues), 16-002

## Philosophical Note

> *A photograph captured is a moment frozen. A photograph served is a moment shared. When the phone becomes a server and the timeline becomes a gallery, private memories become selectively public stories. The "trust-me" page is not just a security measure — it's a conscious moment of consent, a pause before viewing, a recognition that someone chose to share this with you.*
