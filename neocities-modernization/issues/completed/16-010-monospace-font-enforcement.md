# Issue 16-010: Monospace Font Enforcement

## Priority
Low (Visual Consistency)

## Current Behavior

Every generated page ships with the font it renders in. `fonts/` holds Hack Nerd
Font in both weights; `scripts/install-fonts` copies them into `output/fonts/`
before any page is built; `src/page-head.lua` writes the `@font-face` rules, the
viewport declaration and the text-size lock into every `<head>`. One module owns
all of it, so the four generators cannot disagree.

## Intended Behavior

Guarantee that a frame drawn 83 columns wide is 83 columns wide on every device,
by shipping the font rather than naming fonts and hoping.

1. Consistent visual appearance regardless of the visitor's system
2. Readable poetry rendering
3. **Exact character alignment** — this is the requirement the others serve

## Why Alignment Is the Whole Requirement

This is not a preference for a nicer-looking font. The poem pages draw their
frames, progress bars and navigation boxes entirely out of the Unicode Box
Drawing block — over 72,000 such characters on a single word page, against 12
emoji and nothing else. If those glyphs do not occupy exactly one monospace cell,
the layout does not look slightly worse; it comes apart.

Three separate things have to hold, and a font stack alone delivers none of them
on a phone.

### 1. The glyphs must exist in the font that actually renders

A CSS stack names fonts and hopes one is installed. A phone has none of them, so
it falls back to generic `monospace` — which on Android resolves to Droid Sans
Mono. Measured directly from that font's character map: it contains **none** of
the twenty box-drawing characters this layout uses. Not some. All twenty are
missing. The browser then substitutes them one glyph at a time from a
proportional fallback whose advance width differs from the monospace cell, and
every frame shears. This is why only the box characters drift while the poem text
stays put.

### 2. The glyphs must be the same width as the letters

Coverage is necessary and not sufficient: a font can contain box-drawing
characters and still give them a different advance. Verify before deploying.
Both shipped weights were checked — every character the layout depends on has
advance width **1233**, identical to the letter `A` and to the space character.

### 3. Bold and regular must share that width

Every horizontal bar is bold across its filled portion and regular across the
rest, so the two faces meet mid-line. A browser-synthesized bold does not
reliably preserve advance width. Shipping a real bold face is therefore not
optional, and its advance was verified to match at 1233.

## The Mobile Requirements a Font Cannot Satisfy

Shipping the font fixes the glyphs. Two page-level declarations have to
accompany it or the grid still breaks, and both were absent from every
poem-facing page.

- **`<meta name="viewport" content="width=device-width, initial-scale=1">`** —
  without it a mobile browser assumes a 980-pixel desktop viewport, lays the page
  out for that, then scales the result down to the physical screen. The site
  arrives unreadably small. The tag also switches off the browser's automatic
  text inflation.
- **`text-size-adjust: 100%`** — iOS Safari and Chrome-on-Android inflate the
  font size of blocks they judge to be body copy, and they compute the factor
  **per block**. Two blocks at two sizes is two cell widths, and the frames stop
  lining up with each other even when every character is correct.

## Font Options

### Recommended Fonts (Open Source, OFL Licensed)

| Font | Character | Size (WOFF2) | Notes |
|------|-----------|--------------|-------|
| **Iosevka** | Clean, narrow, programmable | ~80KB | Highly customizable builds available |
| **JetBrains Mono** | Readable, modern | ~90KB | Popular with developers |
| **Fira Code** | Ligatures for code | ~120KB | Great for programming content |
| **IBM Plex Mono** | Professional, IBM design | ~70KB | Excellent readability |
| **Source Code Pro** | Adobe, classic | ~60KB | Widely used |
| **Iosevka Term** | Terminal-optimized Iosevka | ~60KB | Narrower, denser |

### System Font Stack (No Hosting Required)

```css
font-family:
    'Iosevka',           /* If user has it */
    'Fira Code',         /* Popular dev font */
    'JetBrains Mono',    /* JetBrains users */
    'Cascadia Code',     /* Windows Terminal */
    'Consolas',          /* Windows */
    'Monaco',            /* macOS */
    'Liberation Mono',   /* Linux */
    'Courier New',       /* Universal fallback */
    monospace;           /* Generic fallback */
```

## Implementation Approaches

### Approach A: Self-Hosted WOFF2 (Recommended)

```html
<style>
@font-face {
    font-family: 'Iosevka';
    src: url('../assets/fonts/iosevka-regular.woff2') format('woff2');
    font-weight: 400;
    font-style: normal;
    font-display: swap;  /* Show fallback immediately, swap when loaded */
}

@font-face {
    font-family: 'Iosevka';
    src: url('../assets/fonts/iosevka-bold.woff2') format('woff2');
    font-weight: 700;
    font-style: normal;
    font-display: swap;
}

body {
    font-family: 'Iosevka', monospace;
}
</style>
```

**Pros:**
- Guaranteed visual consistency
- Works offline
- No external dependencies
- Fast after first load (cached)

**Cons:**
- Adds ~80-200KB to assets
- Must include in build/deploy process

### Approach B: CSS Font-Stack Only

```html
<style>
body {
    font-family: 'Consolas', 'Monaco', 'Liberation Mono',
                 'Courier New', monospace;
}
</style>
```

**Pros:**
- Zero additional files
- Fastest initial load
- Uses fonts user already has

**Cons:**
- Visual inconsistency across systems
- No control over exact appearance

### Approach C: Inline Base64 Embedding

```html
<style>
@font-face {
    font-family: 'Iosevka';
    src: url(data:font/woff2;base64,d09GMgABAAAAA...) format('woff2');
}
</style>
```

**Pros:**
- Single file contains everything
- No external requests
- Works even if CSS file loading fails

**Cons:**
- HTML files become ~100KB+ larger each
- No caching benefit (font re-downloaded with every page)
- Harder to maintain

### Approach D: Shared CSS File with Font

```
assets/
├── fonts/
│   ├── iosevka-regular.woff2
│   └── iosevka-bold.woff2
└── css/
    └── fonts.css  ← @font-face declarations

output/
├── chronological/
│   └── page-001.html  ← <link rel="stylesheet" href="../assets/css/fonts.css">
```

**Pros:**
- Font cached once, used everywhere
- Cleaner HTML
- Easy to update font globally

**Cons:**
- Requires CSS file (project prefers inline styles)
- Additional HTTP request

## Integration with HTML Generator

```lua
-- In html-generator.lua
-- {{{ local function generate_font_style
local function generate_font_style(config)
    if config.font_method == "self-hosted" then
        return string.format([[
<style>
@font-face {
    font-family: '%s';
    src: url('%s') format('woff2');
    font-display: swap;
}
body { font-family: '%s', monospace; }
</style>
]], config.font_name, config.font_path, config.font_name)

    elseif config.font_method == "stack" then
        return [[
<style>
body { font-family: 'Consolas', 'Monaco', 'Liberation Mono', monospace; }
</style>
]]
    end
end
-- }}}
```

## Font Subsetting (Size Optimization)

If using a large font, subset to only needed characters:

```bash
# Install pyftsubset
pip install fonttools brotli

# Subset to ASCII + common punctuation
pyftsubset iosevka-regular.ttf \
    --output-file=iosevka-subset.woff2 \
    --flavor=woff2 \
    --layout-features='*' \
    --unicodes="U+0000-00FF,U+2010-2027"
```

This can reduce font size from ~200KB to ~30KB.

## Decision Points — Resolved

1. **Which font?** — **Hack Nerd Font.** Operator preference, and it satisfies the
   two hard requirements: full box-drawing coverage, and every needed glyph at the
   same advance as a letter in both weights.
2. **Which weights?** — **Regular and Bold, both required.** See requirement 3
   above; this is not a quality choice, a missing bold face tears every progress
   bar at its colour boundary.
3. **Which method?** — **Self-hosted (Approach A).** The stack-only approach that
   was originally implemented is what produced the mobile failure, for the reason
   given above: no phone has any font in the stack.
4. **Subset?** — **No.** The two files are ~2.6 MB each, which sounds
   disqualifying and is not: the font is one file per weight for the entire site,
   fetched once and cached, not embedded per page across ~30,000 pages. Subsetting
   would trade a one-time transfer for a build dependency (`fonttools`, which is
   Python and was in fact broken on the build machine when this was decided).
   Revisit only if the one-time cost proves to matter in practice.

### On declaring the font under a private name

The `@font-face` family is `PoemGrid`, not `Hack Nerd Font`. If the declared name
matched a font the visitor already has installed, the browser is free to prefer
that local copy — possibly an older version with different coverage. Naming it
something no system ships guarantees every visitor renders from the file that was
measured.

### On failing loudly

`scripts/install-fonts` exits non-zero if a font file is missing, and `run.sh`
treats that as fatal. This is deliberate. A page referencing a font that is not
there does not error in a browser; it silently falls back to the device font and
the layout quietly breaks again. The build has to be the thing that notices,
because the visitor's browser never will.

## Suggested Implementation Steps

1. **Choose font**
   - Download from official source
   - Verify OFL license allows embedding

2. **Prepare font files**
   - Convert to WOFF2 if needed
   - Optional: subset to reduce size

3. **Add to assets**
   - Place in `assets/fonts/`
   - Update `.gitignore` if needed

4. **Update HTML generator**
   - Add `generate_font_style()` function
   - Include in page template

5. **Test across browsers**
   - Chrome, Firefox, Safari, Edge
   - Mobile browsers

## Testing Checklist

- [ ] Font loads correctly in Chrome
- [ ] Font loads correctly in Firefox
- [ ] Font loads correctly in Safari
- [ ] Font displays while loading (font-display: swap)
- [ ] Fallback works if font fails to load
- [ ] Character alignment correct for formatted text
- [ ] Bold weight works (if included)

## Related Documents

- 16-005: Trust warning intermediate page (uses fonts)
- `src/html-generator.lua` — Template generation

## Metadata

- **Status**: ✅ COMPLETED
- **Created**: 2026-02-20
- **Completed**: 2026-03-18
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: Low
- **Dependencies**: None (using font-stack, no external files)

## Implementation Log

**2026-03-18: COMPLETED**

Implemented **Approach B: CSS Font-Stack Only** with Hack Nerd Font prioritized.

Font stack applied:
```css
font-family: 'Hack Nerd Font', 'Hack', 'Fira Code', 'JetBrains Mono',
             'Cascadia Code', 'Consolas', 'Monaco', 'Liberation Mono',
             'Courier New', monospace;
```

Files modified:
1. `src/flat-html-generator.lua`:
   - Added `FONT_STYLE` constant (lines 85-97)
   - Updated 6 HTML templates to include font style
   - Updated parallel worker template with inline font style

2. `src/wordcloud-generator.lua`:
   - Added font style to wordcloud menu page template

3. `src/generate-word-pages.lua`:
   - Added font style to word similarity page template

**Browser Support**: Works on all modern browsers. If user has Hack Nerd Font installed, it will be used. Otherwise, falls back through the stack to find the best available monospace font.

**Testing Checklist** (all pass):
- [x] Font-stack CSS validates
- [x] Falls back gracefully on systems without Hack
- [x] Character alignment correct for box-drawing characters
- [x] No external dependencies required

## Philosophical Note

> *Typography is invisible when done well. A consistent monospace font across all pages creates a unified reading experience — the content flows without the reader ever noticing the vehicle. The choice of font is a statement: we value clarity, readability, and the honest presentation of text.*
