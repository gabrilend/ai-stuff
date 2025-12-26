# Issue 11-002c: Generate Maze HTML Pages

## Current Behavior

HTML pages exist for similar/, different/, and chronological views. No maze-based navigation exists.

## Intended Behavior

Generate `maze/XXX.html` pages for each poem, displaying the poem content and 6 exit choices (links to other maze pages).

### Page Structure

```html
<!-- maze/42.html -->
<html>
<head>
    <meta charset="UTF-8">
    <title>Poetry Maze - Room 42</title>
</head>
<body>
<pre>
╔════════════════════════════════════════════════════════════════════════════════╗
║                               POETRY MAZE                                       ║
╠════════════════════════════════════════════════════════════════════════════════╣
║                                                                                 ║
║  [POEM CONTENT HERE]                                                            ║
║                                                                                 ║
║  the autumn leaves fall silently to earth                                       ║
║  covering the ground in golden memories                                         ║
║  while birds prepare their journey south                                        ║
║                                                                                 ║
╠════════════════════════════════════════════════════════════════════════════════╣
║  WHERE WOULD YOU LIKE TO GO?                                                    ║
║                                                                                 ║
║  ┌─────────────────────────────────────────────────────────────────────────┐   ║
║  │ → [1] "the autumn leaves drift quietly to ground..."                    │   ║
║  │ → [2] "the maple leaves fall silently to soil..."                       │   ║
║  │ → [3] "october leaves descend gently to earth..."                       │   ║
║  │ → [4] "autumn petals sink slowly to grass..."                           │   ║
║  │ → [5] "the falling leaves whisper to ground..."                         │   ║
║  │ → [6] "crimson leaves drift silently earthward..."                      │   ║
║  └─────────────────────────────────────────────────────────────────────────┘   ║
║                                                                                 ║
╚════════════════════════════════════════════════════════════════════════════════╝
</pre>
<p>
<a href="423.html">[1]</a> |
<a href="1847.html">[2]</a> |
<a href="3291.html">[3]</a> |
<a href="892.html">[4]</a> |
<a href="5521.html">[5]</a> |
<a href="2103.html">[6]</a>
</p>
</body>
</html>
```

### Design Principles

1. **Pure HTML**: No CSS, no JavaScript (consistent with project style)
2. **Box-drawing characters**: Visual structure using Unicode borders
3. **Preview text**: Show first ~50 chars of each exit poem as teaser
4. **Relative links**: All links are relative within maze/ directory
5. **No back links**: Forward-only navigation (browser back works naturally)

### Exit Preview Generation

For each exit poem, show a truncated preview:

```lua
function generate_exit_preview(poem_content, max_chars)
    max_chars = max_chars or 50
    local preview = poem_content:gsub("\n", " "):sub(1, max_chars)
    if #poem_content > max_chars then
        preview = preview .. "..."
    end
    return preview
end
```

## Suggested Implementation Steps

### Step 1: Create Maze HTML Template
- [ ] Design box-drawing header/footer
- [ ] Create poem content area with proper wrapping
- [ ] Design exit choices section

### Step 2: Implement Page Generator
- [ ] Load dimension_maze_cache.json
- [ ] Load poems.json for content
- [ ] For each poem, generate maze page

### Step 3: Handle Special Cases
- [ ] Golden poems get enhanced border treatment
- [ ] Very long poems get truncation with "read more" info
- [ ] Images (if any) handled appropriately

### Step 4: Multi-threaded Generation
- [ ] Parallel generation using effil (same pattern as similar/different)
- [ ] Progress reporting per batch

### Step 5: Integration
- [ ] Add maze/ to output directory structure
- [ ] Link to maze from similar/ and different/ pages (optional)

## Page Sizing

| Component | Size |
|-----------|------|
| HTML boilerplate | ~500 bytes |
| Poem content | ~2,000 bytes average |
| Exit previews (6 × 100 chars) | ~600 bytes |
| Box-drawing structure | ~1,000 bytes |
| **Total per page** | **~4 KB** |
| **All 7,793 pages** | **~31 MB** |

Much smaller than similar/different pages (which include all poems).

### Storage Budget (from Issue 8-020)

The 45 GB Neocities storage limit has ~31 MB reserved for maze pages in `config/input-sources.json`:

```json
"storage": {
    "limit_gb": 45,
    "reserved_for_maze_gb": 0.031,
    "reserved_headroom_gb": 5
}
```

This ensures maze pages are accounted for in the storage budget calculation.

## Output Structure

```
output/
├── index.html
├── chronological.html
├── similar/
├── different/
└── maze/
    ├── 1.html
    ├── 2.html
    ├── ...
    └── 7793.html
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `PREVIEW_LENGTH` | 50 | Characters to show in exit preview |
| `BOX_WIDTH` | 80 | Character width of box-drawing frame |
| `SHOW_POEM_ID` | false | Whether to display poem ID in header |

## Files to Create

- `src/maze-html-generator.lua` (page generation logic)
- `scripts/generate-maze-pages` (CLI wrapper)

## Dependencies

- `dimension_maze_cache.json` (from 11-002b)
- `assets/poems.json`
- Box-drawing utilities from `flat-html-generator.lua`

## Related Issues

- **11-002b**: Provides exits data
- **11-002d**: Adds special room features (called after basic generation)
- **8-002**: Pattern for multi-threaded HTML generation
- **8-020**: Storage budget allocation (reserves 31 MB for maze pages)

---

**Phase**: 11 (Advanced Exploration)

**Priority**: Medium

**Created**: 2025-12-25

**Status**: Open

**Depends On**: 11-002b
