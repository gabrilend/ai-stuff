# 114b - Lodge generator

## Status: completed

## Parent Issue: 114 - The Lodge

## Depends on

None.

## Current Behavior

Built as described below:

- `lodge/build` — the run script (`--test` runs the tests first).
- `lodge/generator/062-build-the-lodge.lua` — the generator; its interface,
  the Markdown subset and the link rules are in
  `062-build-the-lodge.info.md` beside it.
- `lodge/generator/063-test-the-lodge.lua` — 17 checks, all passing,
  including the four that must stop the build (dead link, missing section,
  unknown line shape, room without a stylesheet).

How it works, in order: collect the rooms → parse each into blocks, refusing
unknown line shapes → give every heading an anchor and every other block an
id → resolve every link once, recording which paragraph points at which
room or section → stop with the full list if anything was refused or dead →
render each room again, now knowing every section's visitors, closing each
section with its "pointed at from" list before the next heading of the same
or a higher level → write the pages, each room's stylesheet, and an
`index.html` that opens the first room.

Issue mentions are found by walking the line after the word "issue" or
"issues", taking numbers joined by commas, "and", "or", "through" or "to",
so a run like "issues 221a to 221e" links both ends. Inline marks are done
by lifting code spans and links out first and putting them back last, so
nothing inside them is touched by later rules.

## Intended Behavior

`lodge/build [DIR]` builds every room in `lodge/pages/` into
`docs/HTML/lodge/`. The rules are those of the `documentation-site` skill;
the ones that matter here:

- **Rooms are data, pages are a view.** Only `lodge/pages/` is written by
  hand; `docs/HTML/` is ignored by git and rebuilt every time.
- **Every room has its own stylesheet**, `NNN-name.css` beside
  `NNN-name.md`, copied next to the built page. A room without one stops the
  build.
- **Links:** to another room (`057-the-machine-room.md`, optionally
  `#section`), to any project file (relative to the room's folder), and
  "issue NNN" / "issues NNN, NNN and NNN" in prose, resolved to the issue file
  open or completed. A link whose target does not exist, or whose section
  does not exist, stops the build; every dead link is listed first.
- **Backlinks:** each section of a room that another room links to (with a
  fragment) ends with a "pointed at from" list; each entry returns to the
  paragraph the link sits in. Links to a room as a whole are listed at the
  room's foot.
- **Markdown subset:** headings (1–3), paragraphs, bulleted and numbered
  lists, tables, fenced code, block quotes, horizontal rules, a picture on a
  line of its own (`![caption](path)`, drawn as a figure with its caption),
  inline code, bold, emphasis, links. A line shape outside this list stops
  the build with the room and line number.
- **One contents rail** on every room, listing every room in index order,
  the current one marked.
- Every page says which file it was built from.
- The build prints what it counted (rooms, links, backlinks, pictures),
  logs to `tmp/shared-memory/lodge-build.log`, and writes
  `lodge/output/goodbye` (when it ended, rooms written, links resolved) as
  its last act. Identical rooms build identical pages.

## Suggested Implementation Steps

1. `lodge/build`: the run script; ensure the RAM folders, call the generator,
   exit with its status.
2. `lodge/generator/`: collect rooms → parse each into blocks (fail on unknown
   shapes) → collect every link and its source paragraph → resolve all links
   (fail on any dead one) → render each room with its backlinks → write pages
   and stylesheets → report → goodbye.
3. `lodge/generator/` tests: fixture rooms in a scratch folder, one per rule
   above, including the two that must fail.
