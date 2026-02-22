# Issue 16-010: Monospace Font Enforcement

## Priority
Low (Visual Consistency)

## Current Behavior

Generated HTML pages use browser default fonts or basic CSS font-family declarations. Font rendering varies across systems — Windows users see Consolas, macOS users see Monaco, Linux users see Liberation Mono or whatever they've configured.

There's no guarantee of visual consistency across devices viewing the same content.

## Intended Behavior

Enforce a specific monospaced font across all generated HTML pages, ensuring:
1. Consistent visual appearance regardless of user's system
2. Readable code/poetry rendering
3. Proper character alignment (important for ASCII art or formatted text)

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

## Decision Points

1. **Which font?** — Iosevka (narrow, readable) vs JetBrains Mono (popular) vs other
2. **Which weights?** — Regular only, or Regular + Bold?
3. **Which method?** — Self-hosted (recommended) vs stack-only vs inline
4. **Subset?** — Full character set vs ASCII subset

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

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: Low
- **Dependencies**: Font file (OFL licensed)

## Philosophical Note

> *Typography is invisible when done well. A consistent monospace font across all pages creates a unified reading experience — the content flows without the reader ever noticing the vehicle. The choice of font is a statement: we value clarity, readability, and the honest presentation of text.*
