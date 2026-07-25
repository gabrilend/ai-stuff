# 404 — html gallery viewer

## Current Behavior

Complete. One generator rebuilds all of docs/HTML/ from sources —
43 pages at first build: every doc, the vision, every issue open and
completed, all sharing one navigation pane so everything reaches
everything; issue numbers in prose link to their issues (code blocks
skipped); the gallery index shows every rendered gif looping on
black with measured captions from the reports, a palette-occupancy
meter per picture, and a glow slider for playing with brightness.
Gif pages reference the live artifacts by relative path rather than
copying — the gallery shows what IS. The aesthetic is the project's
own: black, ember headings with a faint glow, violet links.
docs/HTML/ ships with the repository because programs in this house
do not execute directory commands.

## Intended Behavior

The viewing side, kept strictly apart from generation:

- A gallery builder that scans `output/` and the demo directories and
  emits a static HTML gallery to `docs/HTML/`: every gif looping on
  black, captioned with its scene name and the numbers from its render
  report, newest first.
- The documentation pages (docs, notes, issues) rendered to HTML with
  a unified dark aesthetic matching the project's glow-on-black soul,
  a table-of-contents pane on the left, issue numbers linking to
  issues, datapath documents linking to each other where they hand
  off. Every page reachable from every page.
- The builder is a generator like everything else here: run it and the
  whole `docs/HTML/` tree is rebuilt from sources; never edit an HTML
  file by hand (regeneration would erase it — the tool is the truth).
- Reading `output/` is the gallery's only contact with the pipeline —
  it could run on a machine that has never rendered.

## Suggested Implementation Steps

1. The markdown-to-HTML rendering with the shared style and left
   table-of-contents pane.
2. The gallery page from `output/` scanning plus render reports.
3. Cross-link pass (issue numbers, datapath hand-offs).
4. Open in a browser; click everything.

## Blockers

- None hard; richest after 403 produces reports. Can begin any time
  documentation exists.

## Related Documents

- docs/architecture.md (generation and viewing never touch)
