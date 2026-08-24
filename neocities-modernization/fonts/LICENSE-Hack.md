# Hack Nerd Font — license note

`HackNerdFont-Regular.ttf` and `HackNerdFont-Bold.ttf` are shipped with the site
so that every visitor renders the box-drawing layout in the same cell grid,
whether or not their device owns a monospace font that covers those characters.

## Why the font ships at all

The poem pages draw their frames, progress bars and navigation boxes entirely
out of the Unicode Box Drawing block (U+2500–U+257F) — over 72,000 such
characters on a single word page. Phones do not have any of the fonts the CSS
stack names, so they fall back to a generic monospace face, and Android's
generic monospace (Droid Sans Mono) contains **none** of the twenty box-drawing
characters this layout uses. The browser then substitutes those glyphs one at a
time from a proportional fallback font whose advance width differs from the
monospace cell, and every frame shears out of alignment.

Both weights ship because the progress bars are bold for their filled portion
and regular for the unfilled portion. A browser-synthesized bold does not
reliably preserve advance width; a real bold face does. Verified: in both files
every character the layout depends on has advance width 1233, identical to the
letter `A` and to the space character.

## Licenses

Hack is licensed under the MIT License, and incorporates work from Bitstream
Vera Sans Mono, licensed under the Bitstream Vera License. The Nerd Fonts
patcher adds glyphs from several upstream icon sets, each under its own
permissive license. All permit redistribution, including as part of a website.

- Hack: https://github.com/source-foundry/Hack — MIT + Bitstream Vera
- Nerd Fonts: https://github.com/ryanoasis/nerd-fonts — MIT

Upstream copies of the full license texts should be fetched from those
repositories if a verbatim license file is required for redistribution; this
note records provenance, not the license text itself.

## Provenance

Copied from the build machine's system font directory
(`/usr/share/fonts/NerdFonts/ttf/`). If the fonts are ever replaced, re-check
the advance widths before deploying — a font that covers the glyphs but sizes
them differently breaks the layout exactly as badly as one that lacks them.
