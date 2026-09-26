# Vendored libraries

Copied from double-diaper-dungeon's `libs/` on 2026-09-26 (its commit
`58f89bf`), where they were in turn copied from `neocities-modernization`:

| file | from | changed here? |
| --- | --- | --- |
| `markdown.lua` | `double-diaper-dungeon/libs/markdown.lua` | no |
| `page-head.lua` | `double-diaper-dungeon/libs/page-head.lua` | no |

`markdown.lua` carries double-diaper-dungeon's `reflow` option, which
`neocities-modernization`'s original does not have: it joins a paragraph's
wrapped lines before rendering, so prose a tool wrapped at eighty columns
re-wraps to the reader's window, and a bold or backtick span that crosses a
wrap still pairs. The owner chose on 2026-09-26 not to send it back upstream
for now; a note at the top of the upstream file names both copies.

`page-head.lua` asks for a font the pages expect to find in a `fonts/`
folder beside them (`HackNerdFont-Regular.ttf`, `HackNerdFont-Bold.ttf`).
`build-site.lua` writes them there from `../fonts/` whenever one is missing.
