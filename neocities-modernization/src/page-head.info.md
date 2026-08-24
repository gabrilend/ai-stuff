# page-head

Builds the contents of every generated page's `<head>`: the mobile viewport
declaration, and the stylesheet that pins the poem grid to a monospace font the
site ships rather than one it merely hopes for.

Think of it as a black box: tell it how deep the page sits in the site, get back
markup you paste between `<head>` and `</head>`.

## Why it exists

The poem pages draw their frames, progress bars and navigation boxes entirely out
of the Unicode Box Drawing block — over 72,000 such characters on one word page.
The old approach named a list of monospace fonts in CSS and hoped one was
installed. On a phone none of them are, so the browser falls back to its generic
monospace, and Android's generic monospace contains **none** of the twenty
box-drawing characters this layout uses. The browser then substitutes those
glyphs one at a time from a proportional font whose characters are a different
width, and every frame shears out of alignment.

Four generators each kept their own copy of that font stack and none of them
declared a viewport, so a fix applied to one page type left the other three
alone. This module is the single owner.

## External functions

### `M.viewport_meta()`
- **returns**: the `<meta name="viewport">` tag as a string.
- Without it a phone lays the page out for a 980-pixel screen and then shrinks
  the result. It also switches off the browser's automatic per-block text
  inflation, which would otherwise give two blocks two different cell widths.

### `M.style_block(base_path, extra_css)`
- **base_path**: string, required. The relative route from this page back to the
  site root — `"."` for a page written to the root, `".."` for one inside
  `output/similar/`, `output/different/`, `output/chronological/` or
  `output/wordcloud/`. Passing the wrong value 404s the font and drops the page
  silently back to the broken rendering, so the argument is asserted rather than
  defaulted.
- **extra_css**: optional string. Page-specific rules appended to the sheet.
- **returns**: a complete `<style>` element containing the `@font-face` rules,
  the font stack, the text-size lock and the no-reflow rule for `<pre>`.

### `M.head(opts)`
- **opts.title**: optional string, already HTML-safe.
- **opts.base_path**: string, required — same meaning as above.
- **opts.extra_css**: optional string.
- **opts.extra_meta**: optional string of additional `<meta>`/`<link>` markup.
- **returns**: the whole `<head>` element, charset and viewport included.

### `M.FONT_DIR_NAME`
Read-only string, `"fonts"`. The directory under the site root where the font
files land.

### `M.FONT_FILES`
Read-only array of the filenames that must be present. Both weights are listed
because every progress bar is bold across its filled portion and regular across
the rest; a browser-synthesized bold does not reliably keep the same advance
width, so a missing bold face tears each bar at the colour boundary.

## The font is declared under a private name

The `@font-face` family is `PoemGrid`, not `Hack Nerd Font`. If the declared name
matched a font the visitor already has installed, the browser would be free to
prefer that local copy — possibly a different version with different coverage.
A name no system ships guarantees every visitor renders from the file that was
tested.

## Related

- `scripts/install-fonts` — copies `fonts/` into `output/fonts/`; run by `run.sh`
  before any page is generated. Fatal on a missing font, because the browser-side
  failure is silent.
- `fonts/LICENSE-Hack.md` — provenance and licence trail, and the measurement
  that matters: every character the layout depends on has advance width 1233 in
  both weights, identical to the letter `A` and to the space character.
