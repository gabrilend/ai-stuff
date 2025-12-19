# 8-014: Generate Numeric Similarity Index

## Current Behavior

The `index.html` contains a chronological poem listing but no quick-access numeric index for similarity pages. Users cannot easily jump to a specific poem number without scrolling through the entire chronological view.

## Intended Behavior

A script generates a simple HTML excerpt containing 7791 sequential links (001 to 7791) pointing to `similar/XXX.html` pages. The output is a dense, CTRL+F-searchable block that can be inserted into `index.html`. No different/diversity pages in this phase - similarity only.

The format should be minimal and text-book style:
```
001 002 003 004 005 006 007 008 009 010
011 012 013 014 015 016 017 018 019 020
...
```

Each number is a link. Dense horizontal layout to maximize screen real estate. User finds their poem via CTRL+F.

## Suggested Implementation Steps

1. Create `scripts/generate-numeric-index` (Lua script)
2. Read poem count from `assets/poems.json` metadata
3. Generate HTML links in format: `<a href="similar/XXX.html">XXX</a>`
4. Output 10-20 links per line for density
5. Wrap in `<pre>` block for monospace alignment
6. Write to stdout or `output/numeric-index.html` fragment
7. Script should be runnable standalone: `lua scripts/generate-numeric-index`

## Output Format

```html
<pre>
<a href="similar/001.html">001</a> <a href="similar/002.html">002</a> <a href="similar/003.html">003</a> ...
</pre>
```

## Stats

- Total poems: 7791
- Links per row: 15 (configurable via LINKS_PER_ROW)
- Output size: 282KB actual
- Rows generated: 520

## Completion Notes

**Implemented**: 2025-12-18

Script created at `scripts/generate-numeric-index`. Uses 4-digit zero-padding (0001-7791) for visual alignment. Output goes to stdout by default for piping/redirection flexibility.

Usage:
```bash
lua scripts/generate-numeric-index > output/numeric-index-fragment.html
# Or pipe directly where needed
lua scripts/generate-numeric-index | xclip -selection clipboard
```

## Related Files

- `/assets/poems.json` - source of poem count
- `/output/index.html` - target for insertion
- `/src/flat-html-generator.lua` - reference for similar link generation
