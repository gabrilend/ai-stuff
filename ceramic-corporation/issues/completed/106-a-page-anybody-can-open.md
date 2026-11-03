# 106 — A page anybody can open

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | 103 |
| Blocks | 203 |
| Reads | [open questions, Q2](../../docs/005-open-questions.md#q2--what-the-interface-looks-like) |

## Current behavior

Everything is visible to anybody with a terminal.

## Intended behavior

A generated, static HTML5 page with no JavaScript: the board at the top, then
every box with its holders, ports and state, each wire a link to the box at
the other end, each blocked port marked. It is written from the files and holds
nothing they do not.

## What Happened

Built as `src/013-org-page.lua` and `./org-page`; `./map-the-monorepo` writes
the monorepo's page, and the bakery's is committed beside its map. The page
has no script and no event handlers (a test looks), every link lands on
something on the page, and everything a map says is escaped. It refuses an
invalid org rather than drawing something untrue. Styling is inline and
follows the reader's light or dark setting.
