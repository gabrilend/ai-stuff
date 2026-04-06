# Config Reference

Issue 10-019: Documentation for `config.lua` structure and field usage.

## Overview

All configuration lives in `config.lua` at the project root. It uses Lua table syntax and is loaded via `libs/config-loader.lua`:

```lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local config = config_loader.load()
```

Sections use vimfolds (`-- {{{ section_name` / `-- }}}`) for easy navigation in editors.

---

## Section Reference

### asset_paths
**Read by:** Most scripts
**Priority:** Required

Root directory for all generated assets: embeddings, caches, indexes.

| Field | Type | Description |
|-------|------|-------------|
| `assets_root` | string | Absolute path to assets directory |

---

### layout
**Read by:** `src/flat-html-generator.lua:load_layout_from_config()`
**Priority:** Low (sensible defaults exist)

Controls the visual appearance of poem boxes in generated HTML. All values are in characters.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `regular_poem_width` | number | 83 | Width of standard poem boxes |
| `golden_poem_width` | number | 85 | Width of golden poem boxes (1024 chars) |
| `text_content_width` | number | 80 | Inner content area width |
| `left_box_width` | number | 11 | Left navigation box width |
| `right_box_width` | number | 13 | Right navigation box width |
| `gap_width` | number | 59 | Gap between left and right boxes |
| `left_junction_pos` | number | 5 | Position of left box junction point |
| `right_junction_pos` | number | 6 | Position of right box junction point |

---

### sources
**Read by:** `libs/sources-loader.lua`, all extractors
**Priority:** Critical

Unified input source configuration. Each source type supports multiple named directories.

#### Source Types

| Source | Format | Parser | Description |
|--------|--------|--------|-------------|
| `fediverse` | `activitypub` | Mastodon outbox.json | ActivityPub archives |
| `messages` | `messages_export` | export.json | Matrix message exports |
| `notes` | `plaintext` | .txt/.md files | Local notes directory |
| `bluesky` | `atproto` | CAR files | Bluesky exports |
| `images` | (special) | File scanner | Image directories |

#### Common Source Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `enabled` | boolean | No (default: true) | Skip this source entirely if false |
| `format` | string | Yes | Parser to use (see table above) |
| `directories` | array | Yes | One or more input directories |

#### Directory Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Human-readable identifier for logs |
| `path` | string | Yes | Relative to project root, or absolute |
| `optional` | boolean | No (default: false) | Missing = warning, not error |
| `description` | string | No | Your notes, unused by code |
| `external.source` | string | No | Path to rsync from |
| `randomize_order` | boolean | No | Scatter images randomly in timeline |

#### Archive Entry Fields (ZIP files)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Identifier for logs |
| `source` | string | Yes | Absolute path to ZIP file |
| `extract_to` | string | Yes | Destination (relative to project) |

#### Image Source Special Fields

| Field | Type | Description |
|-------|------|-------------|
| `supported_formats` | array | File extensions to include |
| `max_file_size_mb` | number | Skip files larger than this |
| `preserve_structure` | boolean | Keep directory hierarchy in output |

---

### extraction
**Read by:** Extraction scripts
**Priority:** Low (all enabled by default)

Controls which input sources are processed during extraction.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enable_fediverse` | boolean | true | Process ActivityPub data |
| `enable_messages` | boolean | true | Process message exports |
| `enable_notes` | boolean | true | Process plaintext notes |
| `enable_bluesky` | boolean | true | Process Bluesky data |
| `ignored_archives` | array | [] | ZIP filename stems to skip |

---

### excluded_poems
**Read by:** `libs/exclusion-filter.lua`
**Priority:** Optional

Poems to exclude from the collection during extraction. Excluded poems leave gaps in the ID sequence (tombstoning) - they don't shift other poem IDs down, preserving stable anchor links.

#### ID Formats by Category

| Category | ID Format | Example |
|----------|-----------|---------|
| `fediverse` | Numeric post ID from ActivityPub | `"113847291038475"` |
| `fediverse_boost` | Sequential boost number | `"0003"` |
| `notes` | Filename without extension | `"what-a-lame-movie"` |
| `messages` | Numeric message index | `"42"` |
| `bluesky` | AT Protocol record key | `"3k...abc"` |

---

### privacy
**Read by:** Extraction scripts
**Priority:** Critical for public deployment

Anonymization settings. In "clean" mode, usernames are replaced with sequential identifiers.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `mode` | string | "clean" | "clean" (anonymize) or "raw" (preserve) |
| `anonymization_prefix` | string | "user-" | Prefix for anonymized usernames |
| `include_boosts` | boolean | false | Include boosted/reblogged posts |
| `preserve_original_length` | boolean | true | Keep length hints for anonymized names |
| `store_anonymization_map` | boolean | false | Store username→anonymous mapping |
| `local_server_domain` | string | - | Your home instance domain |

**CLI overrides:** `--include-boosts`, `--no-boosts`

---

### golden_poems
**Read by:** `src/html-generator/golden-poem-bonus.lua`
**Priority:** Low

"Golden poems" are exactly 1024 characters - Mastodon's limit. These get a similarity bonus.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enable_golden_prioritization` | boolean | true | Apply golden poem bonuses |
| `golden_poem_pair_bonus` | number | 0.05 | Bonus when both poems are golden |
| `golden_poem_single_bonus` | number | 0.02 | Bonus when one poem is golden |
| `golden_bonus_threshold` | number | 0.1 | Maximum bonus cap |
| `min_golden_recommendations` | number | 2 | Minimum golden poems per page |
| `max_golden_recommendations` | number | 5 | Maximum golden poems per page |

---

### semantic_colors
**Read by:** `src/semantic-color-calculator.lua`
**Priority:** Low (change for visual customization)

Colors for semantic clustering visualization. Each poem is assigned a color based on its embedding cluster.

| Color | RGB | Hex |
|-------|-----|-----|
| red | (220, 60, 60) | #dc3c3c |
| blue | (60, 120, 220) | #3c78dc |
| green | (60, 180, 90) | #3cb45a |
| purple | (140, 60, 200) | #8c3cc8 |
| orange | (230, 140, 60) | #e68c3c |
| yellow | (200, 180, 40) | #c8b428 |
| gray | (120, 120, 120) | #787878 |

`color_names` array defines iteration order for deterministic page generation.

---

### similarity
**Read by:** `src/similarity-calculator.lua`
**Priority:** Low

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `default_algorithm` | string | "cosine" | Similarity algorithm |

**Available algorithms:** `cosine`, `euclidean`, `manhattan`, `angular`, `pearson_correlation`

---

### ollama_servers
**Read by:** `libs/ollama-config.lua`
**Priority:** Required for embedding generation

Multi-server Ollama configuration for embedding generation.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Label for TUI and `--ollama` flag |
| `description` | string | No | Human-readable description |
| `host` | string | Yes | Server hostname or IP |
| `port` | number | Yes | Ollama API port (default: 11434) |
| `model` | string | Yes | Default embedding model |
| `available_models` | array | No | List of models on this server |

`default_ollama_server` specifies which server to use by default.

**CLI overrides:** `--ollama NAME`, `--model NAME`, `--list-ollama`

---

### pagination
**Read by:** `src/flat-html-generator.lua:load_pagination_config()`
**Priority:** Medium

Controls how poems are split across HTML pages.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `poems_per_page` | number | 200 | Poems per similar/different page |
| `minimum_pages` | number | 1 | Minimum pages to generate |
| `max_pages_per_poem` | number | 15 | Maximum pages per poem |
| `page_number_padding` | number | 2 | Zero-padding (01, 02...) |
| `generate_txt_exports` | boolean | true | Generate .txt versions |
| `chronological_paginated` | boolean | false | Split chronological.html |
| `chronological_poems_per_page` | number | 1000 | Poems per chrono page |

**CLI overrides:** `--poems-per-page`, `--chrono-per-page`, `--pages`

---

### storage
**Read by:** `src/flat-html-generator.lua:load_pagination_config()`
**Priority:** Low

Budget planning for Neocities deployment.

| Field | Type | Description |
|-------|------|-------------|
| `limit_gb` | number | Total available storage |
| `reserved_for_maze_gb` | number | Reserved for HTML Maze feature |
| `reserved_headroom_gb` | number | Safety buffer |

---

### centroids
**Read by:** `src/centroid-generator.lua`
**Priority:** Medium (for mood-based exploration)

Mood-based exploration anchors. Each centroid defines a "semantic target" using keywords.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Internal identifier |
| `description` | string | No | Human-readable description |
| `source_files` | array | No | Files to include in centroid |
| `keywords` | array | Yes | Evocative phrases for embedding |
| `output_slug` | string | Yes | URL-friendly identifier |

**Example:** Adding a new mood centroid:
```lua
{
    name = "nostalgia",
    description = "Bittersweet memories of the past",
    source_files = {},
    keywords = {
        "childhood memories",
        "old photographs",
        "places that no longer exist",
        "the way things used to be"
    },
    output_slug = "nostalgia"
}
```

---

### word_cloud
**Read by:** `src/wordcloud-generator.lua`
**Priority:** Low

Word cloud page settings.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | true | Generate word cloud page |
| `output_file` | string | "wordcloud.html" | Output filename |
| `min_occurrences` | number | 5 | Minimum word frequency |
| `max_words` | number | 200 | Maximum words (0 = unlimited) |
| `min_word_length` | number | 3 | Ignore shorter words |
| `font_size_min` | number | 1 | Minimum font tag size |
| `font_size_max` | number | 7 | Maximum font tag size |
| `stop_words` | array | [...] | Common words to exclude |

---

### html_theme
**Read by:** HTML generators
**Priority:** Low (cosmetic)

Dark mode theme colors applied via HTML body attributes.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `background` | string | "#000000" | Background color (OLED-friendly) |
| `text` | string | "#FFFFFF" | Text color |
| `link` | string | "#6699FF" | Unvisited link color |
| `vlink` | string | "#9966FF" | Visited link color |

---

## Common Customization Tasks

### Adding a New Poem Source

1. Add entry to `sources`:
```lua
my_source = {
    enabled = true,
    format = "plaintext",  -- or appropriate format
    directories = {
        { name = "primary", path = "input/my-source" }
    }
}
```

2. Add to `extraction` if needed:
```lua
enable_my_source = true
```

3. Create extractor script if format requires custom parsing.

### Adding an External Sync

Add `external` field to directory entry:
```lua
{
    name = "my-dir",
    path = "input/my-source",
    external = {
        source = "/home/user/original-location"
    }
}
```

### Excluding a Poem

Add ID to appropriate category in `excluded_poems`:
```lua
excluded_poems = {
    fediverse = { "113847291038475" },
    notes = { "embarrassing-draft" }
}
```

### Changing Embedding Server

Either:
1. Set `default_ollama_server` in config
2. Use `--ollama server-name` CLI flag

---

## Deprecated Sections

| Section | Status | Replacement |
|---------|--------|-------------|
| `external_files` | Deprecated | Use `sources[].directories[].external` |
| `image_sync` | Removed | Use `sources.images` |
| `input_sources` | Removed | Use `sources` |

---

**Last updated:** 2026-04-06 (Issue 10-019)
