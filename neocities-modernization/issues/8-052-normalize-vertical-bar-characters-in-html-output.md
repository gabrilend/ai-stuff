# Issue 8-052: Normalize Vertical Bar Characters in HTML Output

## Priority
Low

## Current Behavior

The generated HTML pages (similar, different, chronological, word pages, centroid pages, word cloud index) contain a mix of two different vertical bar characters used as text separators:

1. **ASCII pipe `|`** (U+007C) — used in navigation link separators and some progress/status text
2. **Unicode box-drawing vertical `│`** (U+2502) — used in box borders, pagination info text, and structured layouts

Both characters appear **within the same HTML pages**, creating a visual inconsistency. The ASCII `|` does not align perfectly with Unicode box-drawing junction characters (`┌`, `┐`, `└`, `┘`, `├`, `┤`, `┬`, `┴`, `┼`, `╘`, `╤`, etc.) because it occupies a different glyph position in most monospace fonts.

### Affected Locations in Source Code

**ASCII `|` used as text separator (should be `│`):**

| File | Line | Context |
|------|------|---------|
| `src/flat-html-generator.lua` | ~2287 | `table.concat(nav_parts, " \| ")` — navigation part separator |
| `src/generate-word-pages.lua` | ~536 | `Back to Word Cloud \| Chronological` — link separator |
| `src/wordcloud-generator.lua` | ~346 | `Explore \| Chronological Index` — menu separator |
| `src/centroid-html-generator.lua` | ~207 | `chronological \| explore \| all moods` — navigation |
| `src/centroid-html-generator.lua` | ~208 | `similar \| different` — page navigation |
| `src/centroid-html-generator.lua` | ~330 | `chronological \| explore` — navigation |

**Unicode `│` already correctly used:**

| File | Line | Context |
|------|------|---------|
| `src/flat-html-generator.lua` | ~539 | `Page %d of %d │ Poems %d-%d` — pagination info |
| `src/flat-html-generator.lua` | ~545-549 | Multi-part pagination display |
| `src/flat-html-generator.lua` | ~1369+ | All box border walls |
| `src/generate-word-pages.lua` | ~328-443 | All box border walls |

### Visual Example

Current output (mixed characters):
```
┌─────────┐                                                           ┌───────────┐
│ similar │      chronological | explore | word cloud      │ different │
└─────────┘                                                           └───────────┘
```

The `|` between "chronological", "explore", and "word cloud" is ASCII — it sits slightly lower/thinner than the `│` box-drawing characters on either side, creating a visible seam in monospace rendering.

## Intended Behavior

**All vertical bar characters in generated HTML output should use the Unicode box-drawing vertical `│` (U+2502)**, so they align perfectly with junction and corner characters from the same Unicode box-drawing block.

Corrected output:
```
┌─────────┐                                                           ┌───────────┐
│ similar │      chronological │ explore │ word cloud      │ different │
└─────────┘                                                           └───────────┘
```

### Scope

This change applies **only to characters that appear in the HTML output** (inside `<pre>` blocks rendered to the user). The following uses of ASCII `|` are **not affected** and should remain unchanged:

- **Shell pipeline operators**: `find ... | wc -l` — these are shell syntax, not display
- **Markdown table formatting**: `| Column | Column |` in report-generator.lua — these are markdown syntax
- **Progress bar status text**: `... | 50 files/sec | ETA: 30s` — these appear in terminal stdout during generation, not in HTML output
- **Lua string operations**: Any `|` used in pattern matching or string logic

### Rule of Thumb

> If the character appears inside a `<pre>` block in generated HTML, it must be `│` (U+2502).
> If it appears in terminal output, shell commands, or markdown, it remains `|` (ASCII).

## Suggested Implementation Steps

1. **Audit all HTML-output separators**: Search for `" | "` and `"| "` patterns in files that write to HTML output. The affected files are:
   - `src/flat-html-generator.lua`
   - `src/generate-word-pages.lua`
   - `src/wordcloud-generator.lua`
   - `src/centroid-html-generator.lua`

2. **Replace ASCII `|` with Unicode `│`** in each location identified above. Each replacement is a simple string change — no logic modification needed.

3. **Verify UTF-8 character counting**: The codebase already has `utf8_char_count()` helpers (added in commit b0a76af8) that correctly handle multi-byte box-drawing characters. Confirm that the replacement doesn't break any width calculations by checking:
   - Navigation text alignment within box structures
   - Pagination text centering
   - Any `string.rep(" ", width - #text)` padding that uses byte length instead of character length

4. **Regenerate a sample page** from each affected generator and visually inspect:
   - A similar page (flat-html-generator nav section)
   - A chronological page (flat-html-generator pagination)
   - A word cloud index page (wordcloud-generator menu)
   - A word page (generate-word-pages nav links)
   - A centroid page (centroid-html-generator navigation)

5. **Check for any remaining ASCII `|` in output**: Run a grep on the output directory to confirm no stray ASCII pipes remain in `<pre>` blocks:
   ```bash
   grep -rn '| ' output/*.html output/**/*.html | grep -v '<a ' | head -20
   ```

## Edge Cases

1. **Character width in padding calculations**: `│` is 3 bytes in UTF-8 but 1 display column wide. Any padding that uses `#str` (byte length) instead of `utf8_char_count()` will over-count by 2 bytes per `│`. The existing box-drawing code already handles this — but the newly-converted separator locations may not. Each replacement site must be checked for width-dependent padding.

2. **Font rendering**: Some terminal fonts render `│` slightly differently than `|`. In HTML `<pre>` blocks viewed in a browser, this is a non-issue — the browser's monospace font renders all box-drawing characters consistently. This change improves browser rendering at no cost.

3. **Copy-paste behavior**: Users copying text from the HTML output will get `│` instead of `|`. This is acceptable — the characters are decorative, not functional.

## Related Documents

- `src/flat-html-generator.lua` — Primary HTML generator (167KB, 44+ existing `│` usages)
- `src/generate-word-pages.lua` — Word page generator
- `src/wordcloud-generator.lua` — Word cloud index generator
- `src/centroid-html-generator.lua` — Centroid mood page generator
- `issues/completed/8-044-golden-poem-detection-and-formatting-parity.md` — Added UTF-8 character counting (commit b0a76af8)
- `issues/completed/8-047-implement-dark-mode-always-on.md` — HTML theme system

## Metadata

- **Status**: Open
- **Created**: 2026-01-26
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Very Low
- **Dependencies**: None
- **Affects**: All generated HTML pages with text separators
