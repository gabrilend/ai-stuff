# 109 — The Documentation Is A Website

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | none (reads whatever documents exist) |
| Blocks | none |
| Files | `scripts/build-documentation`, `docs/HTML/` |

## Current behavior

The documentation is Markdown files: docs/, notes/, issues/ (open and
completed), the phase progress files, and the `.info.md` page beside every
source file. They can be read only one at a time in a text editor.

## Intended behavior

`scripts/build-documentation` turns every one of those into an HTML page in
docs/HTML/, all sharing one stylesheet in the project's look (clay and brick:
warm paper, brick-red and brick-blue accents), with the table of contents down
the left of every page so every page reaches every other.

- Every issue number in any text links to that issue's page.
- Every source file name links to its `.info.md` page.
- Code in the pages is highlighted.
- Each page that has charts or interactive parts has a feedback box that
  writes a message to the project's feedback inbox.
- The game-rules page carries toys: a slider for fatigue that shows the parry
  chance and trip rule live, computed from the configuration defaults.
- Every page says at the top what generated it.

## Suggested implementation steps

1. Follow the documentation-site skill's patterns; the generator is a Lua
   script with a small Markdown converter (headings, lists, tables, code,
   links, emphasis).
2. Regenerate whenever documentation changes.

## Open questions

- Where is the "project specific feedback inbox" to be delivered: a file in
  the project, a local mail spool, or something else?
