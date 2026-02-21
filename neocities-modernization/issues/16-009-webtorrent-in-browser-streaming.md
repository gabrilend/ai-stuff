# Issue 16-009: WebTorrent In-Browser Streaming

## Priority
Low (Alternative Distribution — Convenience Option)

## Current Behavior

File distribution requires either:
- Direct HTTPS download (16-004, 16-005)
- Downloading a `.torrent` file and opening in external client (16-008)

Both require user action outside the browser to seed or participate in peer-to-peer distribution.

## Intended Behavior

Offer an **optional** in-browser torrenting experience using WebTorrent. This enables:
1. Streaming media directly in the browser via WebRTC
2. Automatic seeding while viewing
3. Peer-to-peer distribution without external software

### The Trade-off Warning

Since this requires JavaScript (departing from the project's pure-HTML philosophy), the option must be clearly labeled:

```
+------------------------------------------------+
|   Download Options                             |
|                                                |
|   [ trust-me ]        Pure HTTPS, no JS        |
|                                                |
|   [ .torrent file ]   For external clients     |
|                                                |
|   ─────────────────────────────────────────    |
|                                                |
|   ⚠️ JavaScript (insecure but easy):           |
|                                                |
|   [ stream in browser ]  WebTorrent            |
|                          Seeds while viewing   |
|                                                |
+------------------------------------------------+
```

### Why "Insecure but Easy"?

| Concern | Explanation |
|---------|-------------|
| **JavaScript execution** | Runs third-party code in browser |
| **WebRTC exposure** | May leak local IP addresses |
| **Dependency on external library** | WebTorrent CDN or bundled |
| **Browser fingerprinting** | Additional attack surface |

The warning isn't about WebTorrent specifically being malicious — it's about the philosophical shift from static HTML to executable code. Users who prioritize security or minimalism can stick with the pure options.

### WebTorrent Integration

```html
<!-- webtorrent-player.html -->
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>WebTorrent Stream</title>
    <style>
        body {
            background: #1a1a2e;
            color: #eee;
            font-family: Georgia, serif;
            margin: 0;
            padding: 2em;
        }
        .warning-banner {
            background: #e94560;
            color: white;
            padding: 1em;
            margin-bottom: 2em;
            text-align: center;
        }
        .warning-banner code {
            background: rgba(0,0,0,0.2);
            padding: 0.2em 0.5em;
        }
        #player {
            max-width: 100%;
            margin: 2em auto;
            display: block;
        }
        .status {
            font-family: monospace;
            background: #16213e;
            padding: 1em;
            margin-top: 2em;
        }
        .back-links {
            display: flex;
            justify-content: space-between;
            margin-bottom: 2em;
        }
        .back-links a {
            color: #4fc3f7;
            text-decoration: none;
            padding: 0.5em 1em;
            border: 1px solid #4fc3f7;
        }
    </style>
</head>
<body>
    <div class="warning-banner">
        ⚠️ JavaScript active — <code>webtorrent.min.js</code> loaded
    </div>

    <div class="back-links">
        <a href="{{BACK_URL}}">&larr; Back to timeline</a>
        <a href="{{BACK_URL}}">Back to timeline &rarr;</a>
    </div>

    <div id="output">
        <p>Loading WebTorrent...</p>
    </div>

    <div class="status" id="status">
        Peers: 0 | Downloaded: 0 KB | Uploaded: 0 KB
    </div>

    <script src="https://cdn.jsdelivr.net/npm/webtorrent@latest/webtorrent.min.js"></script>
    <script>
        // WebTorrent streaming implementation
        const magnetURI = '{{MAGNET_URI}}';
        const client = new WebTorrent();

        client.add(magnetURI, function (torrent) {
            const file = torrent.files[0];

            // Render based on file type
            if (file.name.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
                file.appendTo('#output', { autoplay: false });
            } else if (file.name.match(/\.(mp4|webm|mov)$/i)) {
                file.appendTo('#output', { autoplay: true, muted: true });
            }

            // Update status
            setInterval(function () {
                const status = document.getElementById('status');
                status.textContent =
                    'Peers: ' + torrent.numPeers +
                    ' | Downloaded: ' + (torrent.downloaded / 1024).toFixed(1) + ' KB' +
                    ' | Uploaded: ' + (torrent.uploaded / 1024).toFixed(1) + ' KB' +
                    ' | Speed: ' + (torrent.downloadSpeed / 1024).toFixed(1) + ' KB/s';
            }, 1000);
        });

        client.on('error', function (err) {
            document.getElementById('output').innerHTML =
                '<p style="color: #e94560;">Error: ' + err.message + '</p>' +
                '<p>Try the <a href="{{TORRENT_URL}}">torrent file</a> instead.</p>';
        });
    </script>

    <noscript>
        <p>JavaScript is disabled. Use the <a href="{{TORRENT_URL}}">.torrent file</a>
           or <a href="{{DIRECT_URL}}">direct HTTPS link</a> instead.</p>
    </noscript>
</body>
</html>
```

### Trust Page Integration

Update the trust warning page (16-005) to include all three options:

```html
<div class="download-options">
    <h3>Pure HTML (no JavaScript)</h3>
    <a href="{{DIRECT_URL}}" class="option primary">
        trust-me (direct HTTPS)
    </a>
    <a href="{{TORRENT_URL}}" class="option">
        download .torrent file
    </a>

    <hr>

    <h3>⚠️ JavaScript (insecure but easy)</h3>
    <a href="webtorrent/{{ID}}.html" class="option js-warning">
        stream in browser (WebTorrent)
    </a>
    <p class="note">Seeds automatically while you view. Requires JS.</p>
</div>
```

### Self-Hosted vs CDN

| Approach | Pros | Cons |
|----------|------|------|
| **CDN** (`cdn.jsdelivr.net`) | Always latest, no hosting | External dependency, privacy |
| **Self-hosted** | Full control, works offline | Must update manually, larger repo |
| **Hybrid** | CDN with local fallback | More complex |

Recommendation: **Self-hosted** for consistency with project philosophy. Bundle `webtorrent.min.js` in assets.

### WebTorrent Trackers

WebTorrent uses WebSocket trackers for browser-to-browser connections:

```javascript
const rtcConfig = {
    announce: [
        'wss://tracker.openwebtorrent.com',
        'wss://tracker.btorrent.xyz',
        'wss://tracker.fastcast.nz'
    ]
};
```

Note: WebTorrent peers can only connect to other WebTorrent peers (browser-based), not traditional BitTorrent clients. For full interop, users should use the `.torrent` file (16-008).

### Seeding While Viewing

The key benefit of WebTorrent: users automatically seed content while viewing. This creates a self-sustaining distribution network for popular content.

```
User A views photo → Seeds to User B
User B views photo → Seeds to User C
...
Original server load decreases as popularity increases
```

### Output Structure

```
output/
├── webtorrent/
│   ├── a1b2c3d4.html      # WebTorrent player pages
│   ├── a1b2c3d5.html
│   └── ...
├── assets/
│   └── webtorrent.min.js  # Self-hosted library
└── ...
```

### Generation Pipeline

```lua
-- {{{ local function generate_webtorrent_page
local function generate_webtorrent_page(entry, config)
    local template = read_file(DIR .. "/templates/webtorrent-player.html")

    local html = template
        :gsub("{{MAGNET_URI}}", entry.magnet_uri)
        :gsub("{{BACK_URL}}", entry.chronological_back_url)
        :gsub("{{TORRENT_URL}}", entry.torrent_url)
        :gsub("{{DIRECT_URL}}", entry.file_url)
        :gsub("{{ID}}", entry.id)

    local output_path = string.format("%s/webtorrent/%s.html",
        config.output_dir, entry.id)

    write_file(output_path, html)
    return output_path
end
-- }}}
```

## Suggested Implementation Steps

1. **Download and bundle WebTorrent**
   - Get `webtorrent.min.js` from npm/CDN
   - Place in `assets/` directory

2. **Create WebTorrent player template**
   - HTML with placeholders
   - Warning banner
   - Fallback links for no-JS

3. **Generate magnet URIs**
   - Extend 16-008 to output magnet links
   - Include WebSocket tracker announces

4. **Generate WebTorrent pages**
   - One page per media file
   - Include all fallback options

5. **Update trust warning page**
   - Add third option with JS warning
   - Clear visual hierarchy (pure first, JS last)

6. **Test browser compatibility**
   - Chrome, Firefox, Safari, Edge
   - Mobile browsers

## Testing Checklist

- [ ] WebTorrent library loads correctly
- [ ] Media streams in browser
- [ ] Peer count updates
- [ ] Upload stats show seeding activity
- [ ] Fallback links work when JS disabled
- [ ] Warning banner clearly visible
- [ ] Back navigation works

## Related Documents

- 16-005: Trust warning intermediate page (integration point)
- 16-008: Torrent file generation (provides magnet URIs)
- WebTorrent documentation: https://webtorrent.io/docs

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: Medium
- **Dependencies**: 16-008 (magnet URI generation), WebTorrent library

## Philosophical Note

> *The "insecure but easy" label isn't a condemnation — it's informed consent. Some users value convenience over purity, and that's a valid choice. By offering both paths and clearly labeling the trade-offs, we respect user autonomy while maintaining our principles. The warning isn't "don't do this" — it's "know what you're choosing."*
