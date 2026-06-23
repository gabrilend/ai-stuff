# markdown.info.md

A small, dependency-free Markdown → HTML renderer (Issue 10-055). Pure: text in,
HTML string out, no globals, no files, no JavaScript on the page it produces.
Built so the source browser can show `.md` files (and extensionless prose like
the vision doc) as formatted documents instead of flat numbered text.

## Public functions

- `render(markdown_text) -> html_string`
  - Renders a Markdown document to an HTML fragment (no `<html>`/`<body>` wrapper;
    the caller drops it into its own page).
  - All text is HTML-escaped before any tags are emitted, so document content can
    never inject markup.

## What it understands

Block level: ATX headings (`#`–`######`), fenced code blocks (```` ``` ````, with
an optional language → `class="lang-…"`), GitHub pipe tables (with `:--`/`--:`
alignment separators), blockquotes (`>`), unordered lists (`-`/`*`/`+`), ordered
lists (`1.`), horizontal rules (`---`/`***`/`___`), and paragraphs.

Inline: bold (`**`/`__`), italic (`*`/`_`, with word-boundary rules so
`snake_case` is left alone), inline code (`` `…` ``), links `[text](url)`, and
images `![alt](src)`.

## Deliberate limits

A pragmatic subset, not a CommonMark engine. Markup inside code spans and fenced
blocks is NOT re-interpreted (so `*` in code stays literal). Anything it does not
recognize falls through as an escaped paragraph — unknown input degrades to plain
text rather than breaking.

## Tests

`libs/markdown-test.lua` — `luajit libs/markdown-test.lua`. Pure, runs standalone,
touches no project state. Covers each block/inline form plus the "no emphasis
inside code" and HTML-escaping guarantees.

## Used by

- `src/generate-source-browser.lua` — renders `.md` / `.info.md` / extensionless
  prose pages.
