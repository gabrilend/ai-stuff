# Issue 16-003: Network File Type Integration

## Priority
High (Integration)

## Current Behavior

The HTML generation pipeline recognizes two file source types:
- `type: text` — Poems and text content from local files
- `type: image` — Images from local filesystem paths

The chronological.html and similar/different pages link directly to local file paths or embed content inline. There is no concept of external/network sources.

## Intended Behavior

Introduce a new `type: network` file source that:
- Represents files served from an Android device via HTTPS
- Integrates into chronological.html and similar/different pages
- Links through a trust warning page rather than directly to content
- Supports thumbnails for preview rendering

### Type System Extension

```lua
-- Extended file type definitions
local FILE_TYPES = {
    text = {
        source = "local",
        extensions = {".txt", ".md"},
        render = "inline",
        link_type = "direct"
    },
    image = {
        source = "local",
        extensions = {".png", ".jpg", ".jpeg", ".gif", ".webp"},
        render = "thumbnail",
        link_type = "direct"
    },
    network = {
        source = "https",
        extensions = {".jpg", ".jpeg", ".png", ".mp4", ".mov", ".webm"},
        render = "thumbnail",
        link_type = "trust_page"  -- Goes through trust warning
    }
}
```

### Network Entry Structure

```lua
-- A network file entry in the timeline
local network_entry = {
    type = "network",
    id = "a1b2c3d4e5f6g7h8",
    filename = "IMG_20260215_143022.jpg",
    timestamp = "2026-02-15T14:30:22",
    timestamp_unix = 1739628622,

    -- Network-specific fields
    server_host = "192.168.0.42",
    server_port = 8443,
    https_base = "https://192.168.0.42:8443",

    -- Generated URLs
    file_url = "https://192.168.0.42:8443/api/file/a1b2c3d4e5f6g7h8",
    thumbnail_url = "https://192.168.0.42:8443/api/thumbnail/a1b2c3d4e5f6g7h8",
    metadata_url = "https://192.168.0.42:8443/api/metadata/a1b2c3d4e5f6g7h8",

    -- Navigation
    chronological_anchor = "2026-02-15-143022",
    trust_page_url = "trust/a1b2c3d4e5f6g7h8.html"
}
```

### HTML Generator Modifications

```lua
-- html-generator.lua modifications

-- {{{ local function generate_entry
local function generate_entry(entry)
    -- Dispatch to type-specific generator
    if entry.type == "text" then
        return generate_text_entry(entry)
    elseif entry.type == "image" then
        return generate_image_entry(entry)
    elseif entry.type == "network" then
        return generate_network_entry(entry)
    else
        error("Unknown entry type: " .. tostring(entry.type))
    end
end
-- }}}

-- {{{ local function generate_network_entry
local function generate_network_entry(entry)
    -- Network entries link to trust page, not directly to content
    -- The trust page then links to the actual HTTPS URL

    local html = string.format([[
<div class="entry entry-network" id="%s">
    <a href="%s" class="entry-link">
        <img src="%s"
             alt="%s"
             class="thumbnail network-thumbnail"
             loading="lazy" />
    </a>
    <div class="entry-meta">
        <span class="timestamp">%s</span>
        <span class="type-badge network">network</span>
        <span class="filename">%s</span>
    </div>
</div>
]],
        entry.chronological_anchor,
        entry.trust_page_url,
        entry.thumbnail_url,  -- Direct HTTPS thumbnail (browser will warn)
        entry.filename,
        format_timestamp(entry.timestamp),
        entry.filename
    )

    return html
end
-- }}}
```

### Network Manifest

A JSON manifest file captures the state of the network source:

```json
// output/network-manifest.json
{
    "source": {
        "name": "Android Camera",
        "host": "192.168.0.42",
        "port": 8443,
        "last_sync": "2026-02-20T10:30:00Z"
    },
    "files": [
        {
            "id": "a1b2c3d4e5f6g7h8",
            "filename": "IMG_20260215_143022.jpg",
            "timestamp": "2026-02-15T14:30:22",
            "size": 4523678,
            "type": "image/jpeg"
        },
        // ... more files
    ],
    "statistics": {
        "total_files": 1247,
        "total_size_bytes": 12847234567,
        "images": 1102,
        "videos": 145
    }
}
```

### Fetching Network Manifest

```lua
-- {{{ local function fetch_network_manifest
local function fetch_network_manifest(host, port)
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local json = require("cjson")

    local url = string.format("https://%s:%d/api/list", host, port)
    local response_body = {}

    -- Note: Will need to handle self-signed cert
    local result, status = http.request{
        url = url,
        sink = ltn12.sink.table(response_body),
        -- SSL verification disabled for self-signed
        verify = "none"
    }

    if status ~= 200 then
        error(string.format("Failed to fetch network manifest: %s", status))
    end

    local manifest = json.decode(table.concat(response_body))
    return manifest
end
-- }}}

-- {{{ local function convert_network_to_entries
local function convert_network_to_entries(manifest, host, port)
    local entries = {}
    local https_base = string.format("https://%s:%d", host, port)

    for _, file in ipairs(manifest.files) do
        table.insert(entries, {
            type = "network",
            id = file.id,
            filename = file.filename,
            timestamp = file.timestamp,
            timestamp_unix = parse_iso_timestamp(file.timestamp),

            server_host = host,
            server_port = port,
            https_base = https_base,

            file_url = https_base .. "/api/file/" .. file.id,
            thumbnail_url = https_base .. "/api/thumbnail/" .. file.id,
            metadata_url = https_base .. "/api/metadata/" .. file.id,

            chronological_anchor = timestamp_to_anchor(file.timestamp),
            trust_page_url = "trust/" .. file.id .. ".html"
        })
    end

    return entries
end
-- }}}
```

### Integration Points

1. **Chronological Pipeline**
   - Merge network entries with local entries by timestamp
   - Generate trust pages for each network entry
   - Include network thumbnails in page rendering

2. **Similar/Different Pipeline**
   - Network files could have embeddings generated from visual content
   - OR: Skip similarity for network files, include chronologically only
   - Decision point: Do we want to calculate visual similarity for photos?

3. **Index Generation**
   - Update master index to include network sources
   - Show source type badge on entries

### Configuration

```lua
-- config.lua additions
config.network_sources = {
    {
        name = "Phone Camera",
        host = "192.168.0.42",
        port = 8443,
        enabled = true,
        sync_on_generate = true
    }
}

config.network_settings = {
    thumbnail_size = 256,
    cache_manifest = true,
    manifest_cache_ttl = 300,  -- seconds
    generate_trust_pages = true
}
```

## Suggested Implementation Steps

1. **Define network entry schema**
   - Add to entry type system
   - Document required fields

2. **Implement manifest fetcher**
   - HTTP/HTTPS client with self-signed cert support
   - JSON parsing
   - Error handling for offline servers

3. **Implement entry converter**
   - Transform manifest files to entry objects
   - Generate URLs and anchors

4. **Modify HTML generator**
   - Add `generate_network_entry` function
   - Handle thumbnail rendering
   - Link to trust pages

5. **Update chronological merger**
   - Accept multiple entry sources
   - Sort by timestamp across sources
   - Handle timezone differences (EXIF vs local)

6. **Add configuration options**
   - Network sources list
   - Enable/disable per source
   - Sync timing

## Testing Checklist

- [ ] Network entries appear in chronological.html
- [ ] Thumbnails load (with HTTPS warning)
- [ ] Trust page links work
- [ ] Entries sorted correctly by timestamp
- [ ] Offline server handled gracefully
- [ ] Config changes reflected in generation

## Related Documents

- 16-001: Android File Server — Vision
- 16-005: Trust warning intermediate page
- `src/html-generator.lua` — Existing HTML generation
- `config.lua` — Project configuration

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: Medium
- **Dependencies**: 16-001 or 16-002 (server must exist)
