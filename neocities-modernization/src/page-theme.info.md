# page-theme.info.md

The site's colours, from one place: config.lua `html_theme`. Every page's
opening `<body>` tag comes from here, so a new kind of page cannot drift off
the pure-black background (Issue 11-009; owner, 2026-10-25). Read once per
Lua state, so each page worker reads config.lua once.

## External functions

### `M.colours() -> { background, text, link, vlink }`
The four colours as hex strings (`"#000000"`, `"#E0E0E0"`, `"#6699FF"`,
`"#9966FF"` today). A missing one is an error naming it.

### `M.body_tag() -> string`
`<body bgcolor="…" text="…" link="…" vlink="…">` with those colours.

## Used by

`src/chronological-page.lua`, `src/ranked-page.lua` (similar and different
pages), `src/word-page.lua`, `src/wordcloud-generator.lua` (the menu),
`src/flat-html-generator.lua` (the explore pages), `src/generate-gallery-pages.lua`,
and `src/generate-source-browser.lua` (its page background and its three
panel shades).
