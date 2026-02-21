# Issue 16-001e: Trust Warning Intermediate Page

## Priority
High (User Experience)

## Parent Issue
16-001: Android File Server — Vision

## Current Behavior

Links to content go directly to the target file. For local files this works seamlessly. For network files with self-signed certificates, browsers would show jarring security warnings without context.

## Intended Behavior

Generate intermediate "trust warning" pages that:
1. Explain the HTTPS situation clearly
2. Provide "Back" buttons to return to the timeline
3. Offer a "trust-me" link to proceed to the actual content
4. Appear on both top-left and top-right for easy access

### Trust Page Layout

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Secure Connection Notice</title>
    <style>
        body {
            font-family: Georgia, serif;
            background: #1a1a2e;
            color: #eee;
            margin: 0;
            padding: 0;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        .navigation {
            display: flex;
            justify-content: space-between;
            padding: 1em;
            background: #16213e;
        }
        .back {
            color: #4fc3f7;
            text-decoration: none;
            padding: 0.5em 1em;
            border: 1px solid #4fc3f7;
        }
        .back:hover {
            background: #4fc3f7;
            color: #16213e;
        }
        .content {
            flex: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            text-align: center;
            padding: 2em;
        }
        .warning-box {
            background: #0f3460;
            padding: 2em;
            max-width: 500px;
            border-left: 4px solid #e94560;
        }
        h2 {
            margin-top: 0;
            color: #e94560;
        }
        .trust-link {
            display: inline-block;
            margin-top: 1.5em;
            padding: 1em 2em;
            background: #4fc3f7;
            color: #1a1a2e;
            text-decoration: none;
            font-weight: bold;
        }
        .trust-link:hover {
            background: #81d4fa;
        }
        .filename {
            font-family: monospace;
            background: #16213e;
            padding: 0.5em 1em;
            margin: 1em 0;
            word-break: break-all;
        }
    </style>
</head>
<body>
    <nav class="navigation">
        <a href="{{BACK_URL}}" class="back">&larr; Back</a>
        <a href="{{BACK_URL}}" class="back">Back &rarr;</a>
    </nav>

    <main class="content">
        <div class="warning-box">
            <h2>HTTPS Notice</h2>

            <p>This content is secured with <strong>HTTPS</strong> encryption,
               but I don't have a certificate authority so...</p>

            <div class="filename">{{FILENAME}}</div>

            <p>Your browser may show a security warning. This is expected
               for self-signed certificates on local networks.</p>

            <a href="{{ACTUAL_URL}}" class="trust-link">trust-me</a>
        </div>
    </main>
</body>
</html>
```

### Visual Layout

```
+------------------------------------------------+
| [<- Back]                           [Back ->]  |
+------------------------------------------------+
|                                                |
|                                                |
|         +----------------------------+         |
|         |                            |         |
|         |  HTTPS Notice              |         |
|         |                            |         |
|         |  This content is secured   |         |
|         |  with HTTPS encryption,    |         |
|         |  but I don't have a        |         |
|         |  certificate authority     |         |
|         |  so...                     |         |
|         |                            |         |
|         |  +----------------------+  |         |
|         |  | IMG_20260215.jpg     |  |         |
|         |  +----------------------+  |         |
|         |                            |         |
|         |      [ trust-me ]          |         |
|         |                            |         |
|         +----------------------------+         |
|                                                |
|                                                |
+------------------------------------------------+
```

### Generation Strategy

Two approaches for generating trust pages:

#### Option A: Static Generation (One page per file)

```lua
-- {{{ local function generate_trust_page
local function generate_trust_page(entry, output_dir)
    local template = read_file(DIR .. "/templates/trust-warning.html")

    local back_url = string.format(
        "../chronological/page-%03d.html#%s",
        entry.chronological_page,
        entry.chronological_anchor
    )

    local html = template
        :gsub("{{BACK_URL}}", back_url)
        :gsub("{{FILENAME}}", entry.filename)
        :gsub("{{ACTUAL_URL}}", entry.file_url)

    local output_path = string.format("%s/trust/%s.html", output_dir, entry.id)
    write_file(output_path, html)

    return output_path
end
-- }}}

-- {{{ local function generate_all_trust_pages
local function generate_all_trust_pages(network_entries, output_dir)
    os.execute("mkdir -p " .. output_dir .. "/trust")

    for _, entry in ipairs(network_entries) do
        generate_trust_page(entry, output_dir)
    end

    print(string.format("[TRUST] Generated %d trust pages", #network_entries))
end
-- }}}
```

#### Option B: Single Template with Query Parameters

```html
<!-- trust/index.html -->
<script>
    // Parse query parameters
    const params = new URLSearchParams(window.location.search);
    const actualUrl = decodeURIComponent(params.get('url') || '');
    const backAnchor = decodeURIComponent(params.get('back') || '');
    const filename = decodeURIComponent(params.get('name') || 'file');

    // Populate page
    document.getElementById('back-left').href = 'chronological.html#' + backAnchor;
    document.getElementById('back-right').href = 'chronological.html#' + backAnchor;
    document.getElementById('filename').textContent = filename;
    document.getElementById('trust-link').href = actualUrl;
</script>
```

**Note**: Option A is preferred since the project prefers pure HTML without JavaScript.

### Entry Link Generation

When generating chronological.html entries for network files:

```lua
-- {{{ local function generate_network_entry_link
local function generate_network_entry_link(entry)
    -- Link goes to trust page, not directly to HTTPS content
    return string.format(
        '<a href="trust/%s.html">%s</a>',
        entry.id,
        generate_thumbnail_img(entry)
    )
end
-- }}}
```

### Back URL Construction

The back URL must point to the exact position in the timeline:

```lua
-- {{{ local function build_back_url
local function build_back_url(entry, pagination_info)
    -- Find which page this entry is on
    local page_number = pagination_info.entry_to_page[entry.id]

    -- Build URL with anchor
    return string.format(
        "../chronological/page-%03d.html#%s",
        page_number,
        entry.chronological_anchor
    )
end
-- }}}
```

### Anchor Format

Anchors use timestamp-based IDs:

```lua
-- {{{ local function timestamp_to_anchor
local function timestamp_to_anchor(timestamp)
    -- Input: "2026-02-15T14:30:22" or unix timestamp
    -- Output: "2026-02-15-143022"

    if type(timestamp) == "number" then
        return os.date("%Y-%m-%d-%H%M%S", timestamp)
    else
        -- Parse ISO format
        local year, month, day, hour, min, sec = timestamp:match(
            "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
        )
        return string.format("%s-%s-%s-%s%s%s",
            year, month, day, hour, min, sec)
    end
end
-- }}}
```

### Multiple Back Buttons Rationale

> "on the top left and top right near where the 'back' button is supposed to go we can also have a 'back' button"

This design ensures:
1. Users can easily find "back" regardless of which corner they look at
2. Mobile users can reach back with either thumb
3. Visual symmetry creates a "navigation frame" around the content

## Suggested Implementation Steps

1. **Create trust page template**
   - HTML with placeholders
   - Minimal, dark-themed styling
   - Mobile-responsive

2. **Implement static page generator**
   - Read template
   - Substitute placeholders
   - Write to output/trust/

3. **Update entry link generation**
   - Network entries link to trust pages
   - Include correct file IDs

4. **Generate back URLs**
   - Calculate chronological page number
   - Build anchor from timestamp

5. **Integrate into pipeline**
   - Generate trust pages during HTML generation
   - Clean old trust pages before regeneration

## Testing Checklist

- [ ] Trust page renders correctly
- [ ] Both back buttons link to correct chronological position
- [ ] "trust-me" link opens actual HTTPS content
- [ ] Mobile layout works
- [ ] Page generated for each network entry
- [ ] Template updates reflected in output

## Related Documents

- 16-001: Android File Server — Vision
- 16-001c: Network file type integration
- 16-001f: Chronological position-aware back navigation

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Parent**: 16-001
- **Estimated Complexity**: Low-Medium
- **Dependencies**: 16-001c (entry structure defined)
