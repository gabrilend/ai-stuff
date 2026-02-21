# Issue 16-008: Torrent File Generation for File Distribution

## Priority
Medium (Alternative Distribution)

## Current Behavior

Files are served only via direct HTTPS download from the Android server. Users must be on the same WiFi network to access content. There's no peer-to-peer distribution mechanism, and no way to "collect" files for later seeding or sharing.

## Intended Behavior

Generate `.torrent` files for each media file, enabling:
1. Peer-to-peer distribution after initial download
2. Offline access to torrent metadata
3. A personal archive of "resonant" content
4. Community seeding of shared content

### The Philosophy

> *"Encourage people to try and save the things on the internet that resonate with them."*

The torrent approach shifts from ephemeral streaming to intentional collection. When someone downloads a torrent file, they're not just viewing — they're choosing to preserve. The suggested common directory (`~/resonance/` or similar) becomes a personal library of meaning.

### Distribution Options

#### Option A: Auto-Generated Torrent Files (Recommended)

Each media file gets a corresponding `.torrent` file:

```
GET /api/torrent/a1b2c3d4
→ Returns: IMG_20260215_143022.jpg.torrent
```

The trust warning page includes a torrent download link alongside the direct link:

```
+----------------------------------------+
|   HTTPS Notice                         |
|                                        |
|   [ trust-me ]     [ download torrent ]|
|                                        |
|   Save to: ~/resonance/                |
+----------------------------------------+
```

#### Option B: In-Browser Torrenting (WebTorrent)

Uses WebTorrent to enable browser-based torrenting. Requires JavaScript.

```html
<script src="webtorrent.min.js"></script>
<script>
    const client = new WebTorrent()
    client.add(magnetURI, torrent => {
        // Stream directly in browser
        torrent.files[0].appendTo('body')
    })
</script>
```

**Consideration**: Project prefers pure HTML. WebTorrent requires JS and would be a significant departure from the static-file philosophy.

#### Option C: Magnet Link Generation

Generate magnet links instead of torrent files:

```
magnet:?xt=urn:btih:HASH&dn=filename&tr=tracker
```

Users copy the magnet link and open in their torrent client.

### Recommendation: Option A

Auto-generated torrent files are:
- Pure data (no JS required)
- Compatible with any torrent client
- Can be pre-generated during file scanning
- Work offline after download

### Torrent File Generation (Lua)

```lua
-- {{{ local function generate_torrent_file
local function generate_torrent_file(file_path, file_info, config)
    local torrent = {
        announce = config.tracker_url or "udp://tracker.opentrackr.org:1337",
        ["announce-list"] = {
            {"udp://tracker.opentrackr.org:1337"},
            {"udp://open.stealth.si:80/announce"},
            {"udp://tracker.torrent.eu.org:451"}
        },
        comment = "Shared via Android File Server",
        ["created by"] = "neocities-modernization/16-008",
        ["creation date"] = os.time(),
        info = {
            name = file_info.filename,
            ["piece length"] = 262144,  -- 256KB pieces
            pieces = calculate_pieces(file_path, 262144),
            length = file_info.size
        }
    }

    local encoded = bencode(torrent)
    local torrent_path = string.format("%s/%s.torrent",
        config.torrent_dir, file_info.id)

    write_file(torrent_path, encoded)
    return torrent_path
end
-- }}}

-- {{{ local function calculate_pieces
local function calculate_pieces(file_path, piece_length)
    local sha1 = require("sha1")
    local pieces = {}

    local file = io.open(file_path, "rb")
    while true do
        local chunk = file:read(piece_length)
        if not chunk then break end
        table.insert(pieces, sha1.binary(chunk))
    end
    file:close()

    return table.concat(pieces)
end
-- }}}

-- {{{ local function bencode
local function bencode(data)
    local t = type(data)

    if t == "string" then
        return string.format("%d:%s", #data, data)
    elseif t == "number" then
        return string.format("i%de", data)
    elseif t == "table" then
        if data[1] then  -- List
            local parts = {"l"}
            for _, v in ipairs(data) do
                table.insert(parts, bencode(v))
            end
            table.insert(parts, "e")
            return table.concat(parts)
        else  -- Dict
            local keys = {}
            for k in pairs(data) do table.insert(keys, k) end
            table.sort(keys)

            local parts = {"d"}
            for _, k in ipairs(keys) do
                table.insert(parts, bencode(k))
                table.insert(parts, bencode(data[k]))
            end
            table.insert(parts, "e")
            return table.concat(parts)
        end
    end
end
-- }}}
```

### API Endpoints

| Endpoint | Method | Response | Description |
|----------|--------|----------|-------------|
| `/api/torrent/:id` | GET | .torrent file | Download torrent for specific file |
| `/api/torrent/all` | GET | .torrent file | Multi-file torrent of entire collection |
| `/api/magnet/:id` | GET | text/plain | Magnet link for specific file |

### Trust Page Integration

Add torrent option to the trust warning page:

```html
<div class="download-options">
    <a href="{{ACTUAL_URL}}" class="proceed">trust-me (direct)</a>
    <a href="/api/torrent/{{ID}}" class="torrent">download .torrent</a>
</div>

<div class="suggestion">
    <p>Save your resonant files to a common directory:</p>
    <code>~/resonance/</code> or <code>~/collected/</code>
    <p class="note">Building a personal library of meaning, one file at a time.</p>
</div>
```

### Collection Suggestion

The page gently encourages users to:
1. Create a dedicated directory for meaningful content
2. Save torrent files there for later seeding
3. Build a personal archive of "resonance"

This isn't mandatory — it's a suggestion for those who want to preserve what moves them.

### Tracker Considerations

For local-only sharing (same WiFi network):
- DHT (Distributed Hash Table) works without external trackers
- Can optionally run a local tracker

For internet distribution:
- Use public trackers (opentrackr.org, etc.)
- Files become seedable by anyone with the torrent

### Pre-Generation vs On-Demand

| Approach | Pros | Cons |
|----------|------|------|
| **Pre-generate all** | Fast API response, works offline | Storage overhead, stale if files change |
| **On-demand** | Always fresh, no extra storage | Slow for large files (hashing) |
| **Hybrid** | Pre-gen on scan, regen on change | Balanced, but more complex |

Recommendation: **Hybrid** — generate during file scan, invalidate when mtime changes.

### Output Structure

```
output/
├── torrent/
│   ├── a1b2c3d4.torrent     # Individual file torrents
│   ├── a1b2c3d5.torrent
│   ├── collection.torrent    # All files in one torrent
│   └── manifest.json         # Torrent metadata index
└── ...
```

### Manifest Format

```json
{
    "generated_at": "2026-02-20T10:30:00Z",
    "files": [
        {
            "id": "a1b2c3d4",
            "filename": "IMG_20260215_143022.jpg",
            "torrent_url": "/api/torrent/a1b2c3d4",
            "magnet": "magnet:?xt=urn:btih:...",
            "info_hash": "abc123..."
        }
    ],
    "collection_torrent": "/api/torrent/all",
    "suggested_directory": "~/resonance/"
}
```

## Suggested Implementation Steps

1. **Implement bencode encoder**
   - String, integer, list, dict encoding
   - Match BitTorrent spec exactly

2. **Implement SHA1 piece hashing**
   - Read file in chunks
   - Calculate piece hashes
   - Concatenate into pieces string

3. **Build torrent file generator**
   - Create info dict
   - Add announce URLs
   - Write to file

4. **Add API endpoints**
   - `/api/torrent/:id` — individual file
   - `/api/magnet/:id` — magnet link
   - `/api/torrent/all` — collection torrent

5. **Update trust warning page**
   - Add torrent download link
   - Add resonance directory suggestion

6. **Integrate with file scanner**
   - Generate torrents during scan
   - Invalidate on file change

## Testing Checklist

- [ ] Bencode output matches spec
- [ ] Torrent files open in standard clients (qBittorrent, Transmission)
- [ ] Info hash matches between generated and client-calculated
- [ ] Files download correctly via torrent
- [ ] Magnet links work
- [ ] Collection torrent includes all files

## Related Documents

- 16-005: Trust warning intermediate page (integration point)
- 16-007: File scanning and metadata extraction (generation trigger)
- BitTorrent Protocol Specification: http://bittorrent.org/beps/bep_0003.html

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: Medium
- **Dependencies**: SHA1 library, bencode implementation

## Philosophical Note

> *Torrents are an act of preservation. When you seed a file, you're saying "this matters enough to keep alive." The resonance directory becomes a personal museum of meaning — not everything you've seen, but everything you've chosen to hold.*
