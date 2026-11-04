# contents-page.lua

Part of the table of contents. Draws the page: every commit, oldest first,
grouped by the conversation it came out of, each with a **transcript**
button that opens the conversation at the moment of the commit. Handed plain
tables; returns one HTML string.

## Public functions

- `render(groups, conversations, opts) -> string` — the whole page.
  - `groups`: from `attribution.group`.
  - `conversations`: transcript key → `{ href, title, summary, elsewhere }`
    (`href`, `title` strings; `summary`, `elsewhere` strings or nil).
  - `opts.title` (string), `opts.base_path` (string, route to the site root
    where the font is), `opts.colours_css` (string), `opts.nav` and
    `opts.nav_css` (strings or nil, a strip of links and its rules).
- `stylesheet() -> string` — the page's own rules.

## The look

double-diaper-dungeon's story page, for every project — the owner's choice,
2026-10-04. A row shows the commit's **body**, first paragraph visible and
the rest unfolding (her words on the subject line: *"it doesn't really give
us any information that we need"*); a commit with no body shows its subject.
The group's heading is the conversation's title and the first thing she said
in it.

## The button, three ways

- a page and a line to land on: opens the page at that line;
- a page, no line (attributed by the transcript it saved): opens the top;
- no page: drawn dimmed, so every row keeps its shape.

## Only when they happen

A conversation filed under another project in the same repository adds
"(filed under …)" and one CSS rule; a conversation whose transcript is gone
says "written under a name the project no longer carries". A page with
neither is byte for byte the game's page.
